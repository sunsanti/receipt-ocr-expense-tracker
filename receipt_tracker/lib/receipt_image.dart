import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The on-screen receipt [frame] as a 0–1 rect of the camera picture.
///
/// The preview ([preview], portrait size) is drawn with BoxFit.cover inside
/// [viewport], so part of it is cut off; undo that before normalizing.
Rect normalizedFrame({required Size viewport, required Size preview, required Rect frame}) {
  final scale = viewport.width / preview.width > viewport.height / preview.height
      ? viewport.width / preview.width
      : viewport.height / preview.height;
  final shown = preview * scale;
  final offset = Offset((viewport.width - shown.width) / 2, (viewport.height - shown.height) / 2);
  final r = frame.shift(-offset);
  double nx(double x) => (x / shown.width).clamp(0.0, 1.0);
  double ny(double y) => (y / shown.height).clamp(0.0, 1.0);
  return Rect.fromLTRB(nx(r.left), ny(r.top), nx(r.right), ny(r.bottom));
}

/// Crops [path] to [rect] (0–1, see [normalizedFrame]) and returns a new JPEG.
/// Runs in a background isolate: decoding a 12 MP photo takes a while.
Future<String> cropReceipt(String path, Rect rect) {
  final out = p.join(Directory.systemTemp.path, 'receipt_${DateTime.now().microsecondsSinceEpoch}.jpg');
  final (l, t, w, h) = (rect.left, rect.top, rect.width, rect.height);
  return Isolate.run(() {
    final photo = img.bakeOrientation(img.decodeImage(File(path).readAsBytesSync())!);
    final cropped = img.copyCrop(
      photo,
      x: (l * photo.width).round(),
      y: (t * photo.height).round(),
      width: (w * photo.width).round(),
      height: (h * photo.height).round(),
    );
    File(out).writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
    return out;
  });
}

/// Resolved thumbnails folder, set by [thumbsDir] (null on web / before startup).
String? thumbsPath;

/// Folder in the app's documents directory that holds receipt thumbnails.
Future<Directory> thumbsDir() async {
  final dir = await Directory(p.join((await getApplicationDocumentsDirectory()).path, 'thumbs')).create(recursive: true);
  thumbsPath = dir.path;
  return dir;
}

/// The thumbnail file for a stored name, if any.
File? thumbFile(String? name) => name == null || thumbsPath == null ? null : File(p.join(thumbsPath!, name));

/// Saves a downscaled copy (max 480 px wide) of the receipt photo and returns
/// its file name. Only the name is stored: on iOS the app's container path
/// changes between installs/updates.
Future<String> saveThumbnail(String path) async {
  final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
  final out = p.join((await thumbsDir()).path, name);
  return Isolate.run(() {
    final photo = img.bakeOrientation(img.decodeImage(File(path).readAsBytesSync())!);
    final small = photo.width > 480 ? img.copyResize(photo, width: 480) : photo;
    File(out).writeAsBytesSync(img.encodeJpg(small, quality: 85));
    return name;
  });
}

/// Deletes thumbnails no expense points to any more. Run at startup rather
/// than on delete, so "Undo" can still restore an expense with its photo.
Future<void> purgeThumbnails(Set<String> keep) async {
  await for (final f in (await thumbsDir()).list()) {
    if (f is File && !keep.contains(p.basename(f.path))) await f.delete();
  }
}
