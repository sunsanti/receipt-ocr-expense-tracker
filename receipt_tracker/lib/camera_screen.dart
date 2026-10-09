import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'receipt_image.dart';
import 'theme.dart';

/// In-app receipt camera: live viewfinder, flash toggle, tap-to-focus and a
/// receipt frame. Pops with the path of the photo cropped to that frame.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

const _flashModes = [FlashMode.off, FlashMode.auto, FlashMode.always, FlashMode.torch];
const _flashIcons = {
  FlashMode.off: Icons.flash_off,
  FlashMode.auto: Icons.flash_auto,
  FlashMode.always: Icons.flash_on,
  FlashMode.torch: Icons.highlight,
};
const _flashLabels = {
  FlashMode.off: 'Flash off',
  FlashMode.auto: 'Flash auto',
  FlashMode.always: 'Flash on',
  FlashMode.torch: 'Torch',
};

/// Receipt-shaped frame (portrait, ~0.62 width/height) centered between the
/// top and bottom control bars.
Rect receiptFrame(Size viewport, {double top = 96, double bottom = 160}) {
  final maxH = viewport.height - top - bottom;
  final w = (viewport.width * .84).clamp(0.0, maxH * .62);
  final h = (w / .62).clamp(0.0, maxH);
  return Rect.fromCenter(center: Offset(viewport.width / 2, top + maxH / 2), width: w, height: h);
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  FlashMode _flash = FlashMode.off;
  Offset? _focus; // last tap, for the focus ring
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Release the camera in the background, reopen it when the app returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return setState(() => _error = 'No camera found on this device.');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await c.setFlashMode(_flash);
      if (!mounted) return c.dispose();
      setState(() {
        _controller = c;
        _error = null;
      });
    } on CameraException catch (e) {
      setState(() => _error = switch (e.code) {
            'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'cameraPermission' =>
              'Camera access is off. Allow it in Settings, or choose a photo from the gallery.',
            'CameraAccessRestricted' => 'Camera access is restricted on this device.',
            _ => 'Could not open the camera: ${e.description ?? e.code}',
          });
    }
  }

  Future<void> _cycleFlash() async {
    final next = _flashModes[(_flashModes.indexOf(_flash) + 1) % _flashModes.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException {
      _snack('This camera has no flash');
    }
  }

  Future<void> _focusAt(Offset local, Size viewport, Size preview) async {
    final c = _controller;
    if (c == null) return;
    setState(() => _focus = local);
    // Same cover-crop mapping as the frame, so focus lands where the user tapped.
    final point = normalizedFrame(viewport: viewport, preview: preview, frame: Rect.fromLTWH(local.dx, local.dy, 0, 0)).topLeft;
    try {
      if (c.value.focusPointSupported) await c.setFocusPoint(point);
      if (c.value.exposurePointSupported) await c.setExposurePoint(point);
    } on CameraException {
      // Fixed-focus cameras: nothing to do.
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted && _focus == local) setState(() => _focus = null);
  }

  Future<void> _capture(Size viewport, Size preview) async {
    final c = _controller;
    if (c == null || _capturing || c.value.isTakingPicture) return;
    setState(() => _capturing = true);
    try {
      final shot = await c.takePicture();
      if (_flash == FlashMode.torch) await c.setFlashMode(FlashMode.off);
      final rect = normalizedFrame(viewport: viewport, preview: preview, frame: receiptFrame(viewport));
      final cropped = await cropReceipt(shot.path, rect);
      if (mounted) Navigator.pop(context, cropped);
    } on CameraException catch (e) {
      _snack('Could not take the photo: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, box) {
          final viewport = box.biggest;
          if (_error != null) return _ErrorView(message: _error!);
          if (c == null || !c.value.isInitialized) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          // previewSize is reported in landscape; the screen is portrait.
          final preview = Size(c.value.previewSize!.height, c.value.previewSize!.width);
          final frame = receiptFrame(viewport);
          return Stack(children: [
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (d) => _focusAt(d.localPosition, viewport, preview),
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(width: preview.width, height: preview.height, child: CameraPreview(c)),
                  ),
                ),
              ),
            ),
            IgnorePointer(child: CustomPaint(size: viewport, painter: FramePainter(frame))),
            Positioned(
              left: 0,
              right: 0,
              top: frame.bottom + Space.md,
              child: const IgnorePointer(
                child: Text(
                  'Fit the receipt inside the frame · tap to focus',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 4)]),
                ),
              ),
            ),
            if (_focus != null)
              Positioned(
                left: _focus!.dx - 32,
                top: _focus!.dy - 32,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_focus),
                    tween: Tween(begin: 1.4, end: 1),
                    duration: Motion.of(context, Motion.medium),
                    builder: (_, s, child) => Transform.scale(scale: s, child: child),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFACC15), width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            // Top bar: close + flash.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Close camera',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                    onPressed: _cycleFlash,
                    icon: Icon(_flashIcons[_flash]),
                    label: Text(_flashLabels[_flash]!),
                  ),
                ]),
              ),
            ),
            // Bottom bar: shutter.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.xl),
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Take photo',
                      child: GestureDetector(
                        onTap: () => _capture(viewport, preview),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: _capturing
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

/// Dims everything outside the receipt frame and draws corner brackets.
class FramePainter extends CustomPainter {
  final Rect frame;
  FramePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(16));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(r),
      Paint()..color = Colors.black.withValues(alpha: .55),
    );
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white54);
    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    const l = 28.0;
    for (final (p, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(p, p + Offset(l * dx, 0), corner);
      canvas.drawLine(p, p + Offset(0, l * dy), corner);
    }
  }

  @override
  bool shouldRepaint(FramePainter old) => old.frame != frame;
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
            const SizedBox(height: Space.lg),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: Space.xl),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          ]),
        ),
      );
}
