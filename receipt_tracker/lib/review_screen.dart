import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'expense.dart';
import 'ocr.dart';
import 'receipt_parser.dart';
import 'theme.dart';

enum Field { total, date, merchant }

const fieldColors = {
  Field.total: Color(0xFF059669),
  Field.date: Color(0xFF2563EB),
  Field.merchant: Color(0xFF7C3AED),
};
const otherTextColor = Color(0xFFD97706);

extension on Field {
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

/// Box color for a field (or plain OCR text), lifted in dark mode.
Color fieldColor(BuildContext context, Field? f) {
  final c = fieldColors[f] ?? otherTextColor;
  return Theme.of(context).brightness == Brightness.dark ? Color.lerp(c, Colors.white, .3)! : c;
}

/// Which form field an OCR line currently feeds, so its box can be colored.
/// Computed from the current field values, so it follows the user's edits.
Field? fieldOf(String line, {int? total, DateTime? date, String merchant = ''}) {
  if (total != null && amounts(line).contains(total)) return Field.total;
  if (date != null && ReceiptParser.dateIn(line) == date) return Field.date;
  final n = normalize(line).trim(), m = normalize(merchant).trim();
  if (n.length >= 3 && m.isNotEmpty && m.contains(n)) return Field.merchant;
  return null;
}

/// Review & Verification: shows the OCR boxes over the photo and the parsed
/// fields; nothing is written to SQLite until the user taps Save. Also used to
/// edit an existing expense ([expense]) or enter one by hand (no [imagePath]).
class ReviewScreen extends ConsumerStatefulWidget {
  final Expense? expense;
  final String? imagePath;
  const ReviewScreen({super.key, this.expense, this.imagePath});

  /// Pop result asking the caller to delete [expense] (with undo there).
  static const deleted = 'deleted';

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _form = GlobalKey<FormState>();
  late final _merchant = TextEditingController(text: widget.expense?.merchant);
  late final _amount = TextEditingController(text: widget.expense?.amount.toString());
  late final _note = TextEditingController(text: widget.expense?.note);
  late final _raw = TextEditingController(text: widget.expense?.rawText);
  late DateTime _date = widget.expense?.date ?? DateUtils.dateOnly(DateTime.now());
  late String _category = widget.expense?.category ?? categories.first;
  late bool _dateSet = widget.expense != null; // false until parsed or picked
  List<OcrLine> _lines = [];
  Size? _imageSize;
  bool _scanning = false;
  bool _showBoxes = true;
  final _boxEdits = ValueNotifier(0); // repaints the zoom dialog, which setState can't reach

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) _scan(widget.imagePath!);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _note.dispose();
    _raw.dispose();
    _boxEdits.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _apply(ParsedReceipt r) => setState(() {
        if (r.merchant != null) _merchant.text = r.merchant!;
        if (r.total != null) _amount.text = '${r.total}';
        if (r.date != null) {
          _date = r.date!;
          _dateSet = true;
        }
      });

  Future<void> _scan(String path) async {
    setState(() => _scanning = true);
    try {
      final ocr = await recognizeText(path);
      if (!mounted) return;
      final r = ReceiptParser.parse(ocr.text);
      setState(() {
        _lines = ocr.lines;
        _imageSize = ocr.imageSize;
        _raw.text = ocr.text;
      });
      _apply(r);
      if (ocr.text.trim().isEmpty) {
        _snack('No text found. Retake the photo or enter the details.');
      } else if (r.total == null) {
        _snack('Total not found. Tap its box on the photo or type it.');
      }
    } catch (e) {
      if (mounted) _snack('Could not read the receipt: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Bottom sheet for one OCR line: fix its text, see its bounding box, and
  /// send it to a form field.
  Future<void> _inspect(int i) async {
    final (text, box) = _lines[i];
    final edit = TextEditingController(text: text);
    final field = await showModalBottomSheet<Field>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Recognized line', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.lg),
          TextField(
            controller: edit,
            decoration: const InputDecoration(
              labelText: 'Text (fix OCR mistakes here)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(children: [
            Icon(Icons.crop_free, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: Space.sm),
            Text(
              'Bounding box: x ${box.left.round()}, y ${box.top.round()}, '
              'w ${box.width.round()}, h ${box.height.round()} px',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(fontFeatures: tabular),
            ),
          ]),
          const SizedBox(height: Space.xl),
          Text('Use this line as', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
            for (final f in Field.values)
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, f),
                icon: Icon(_fieldIcons[f], color: fieldColor(context, f)),
                label: Text('Use as ${f.label}'),
              ),
          ]),
        ]),
      ),
    );
    final fixed = edit.text.trim();
    edit.dispose();
    if (!mounted) return;
    if (fixed.isNotEmpty && fixed != text) setState(() => _lines[i] = (fixed, box));
    switch (field) {
      case Field.total:
        final v = ReceiptParser.totalIn(fixed);
        v == null ? _snack('No amount in "$fixed"') : setState(() => _amount.text = '$v');
      case Field.date:
        final d = ReceiptParser.dateIn(fixed);
        d == null
            ? _snack('No valid date in "$fixed"')
            : setState(() {
                _date = d;
                _dateSet = true;
              });
      case Field.merchant:
        setState(() => _merchant.text = fixed);
      case null:
    }
    _boxEdits.value++;
  }

  /// The photo with every OCR line drawn as a tappable, color-coded box.
  /// Field boxes also get a text tag, so color is not the only cue.
  Widget _photo(String path) {
    final size = _imageSize;
    final image = Image.file(File(path), fit: BoxFit.fill, semanticLabel: 'Receipt photo');
    if (size == null || !_showBoxes) {
      return size == null ? image : AspectRatio(aspectRatio: size.aspectRatio, child: image);
    }
    final total = int.tryParse(_amount.text);
    final tagStyle = Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 10, color: Colors.white, height: 1.2);
    return AspectRatio(
      aspectRatio: size.aspectRatio,
      child: LayoutBuilder(builder: (context, c) {
        final k = c.maxWidth / size.width;
        final boxes = [
          for (var i = 0; i < _lines.length; i++)
            (i, _lines[i], fieldOf(_lines[i].$1, total: total, date: _date, merchant: _merchant.text)),
        ];
        Rect scaled(Rect b) => Rect.fromLTRB(b.left * k, b.top * k, b.right * k, b.bottom * k).inflate(2);
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: image),
          for (final (i, (text, box), field) in boxes)
            Positioned.fromRect(
              rect: scaled(box),
              child: Semantics(
                button: true,
                label: 'OCR line: $text${field == null ? '' : ', used as ${field.label}'}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _inspect(i),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fieldColor(context, field).withValues(alpha: field == null ? .06 : .18),
                      border: Border.all(color: fieldColor(context, field), width: field == null ? 1 : 2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          for (final (_, (_, box), field) in boxes)
            if (field != null)
              Positioned(
                left: scaled(box).left,
                top: scaled(box).top - 15,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: fieldColors[field],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    child: Text(field.label.toUpperCase(), style: tagStyle),
                  ),
                ),
              ),
        ]);
      }),
    );
  }

  Widget _legend() {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Field? f, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fieldColor(context, f).withValues(alpha: .18),
              border: Border.all(color: fieldColor(context, f), width: f == null ? 1 : 2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: style),
        ]);
    return Wrap(spacing: Space.lg, runSpacing: Space.xs, children: [
      for (final f in Field.values) item(f, f.label),
      item(null, 'Other text'),
    ]);
  }

  /// One chip per field: found on the receipt, or needs the user's attention.
  Widget _checks() {
    final ok = {
      Field.total: (int.tryParse(_amount.text) ?? 0) > 0,
      Field.date: _dateSet,
      Field.merchant: _merchant.text.trim().isNotEmpty,
    };
    final scheme = Theme.of(context).colorScheme;
    return Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
      for (final f in Field.values)
        Chip(
          avatar: Icon(
            ok[f]! ? Icons.check_circle : Icons.error_outline,
            color: ok[f]! ? scheme.tertiary : otherTextColor,
            size: 18,
          ),
          label: Text(ok[f]! ? '${f.label} found' : '${f.label} missing'),
          side: BorderSide(color: ok[f]! ? scheme.outlineVariant : otherTextColor),
          backgroundColor: scheme.surfaceContainerLowest,
        ),
    ]);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _dateSet = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(expensesProvider.notifier).save(Expense(
          id: widget.expense?.id,
          merchant: _merchant.text.trim(),
          amount: int.parse(_amount.text),
          date: _date,
          category: _category,
          note: _note.text.trim(),
          rawText: _raw.text,
        ));
    if (mounted) Navigator.pop(context);
  }

  void _zoom(String path) => showDialog(
        context: context,
        builder: (_) => Dialog.fullscreen(
          child: ValueListenableBuilder(
            valueListenable: _boxEdits,
            builder: (context, _, _) => Stack(children: [
              InteractiveViewer(maxScale: 6, child: Center(child: _photo(path))),
              const SafeArea(child: Padding(padding: EdgeInsets.all(Space.sm), child: CloseButton())),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath;
    final amount = int.tryParse(_amount.text);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Review & verify' : 'Edit expense'),
        actions: [
          if (widget.expense != null)
            IconButton(
              tooltip: 'Delete expense',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => Navigator.pop(context, ReviewScreen.deleted),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl),
            children: [
              if (path != null) ...[
                _Section(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scanned receipt',
                  subtitle: _scanning
                      ? 'Reading receipt…'
                      : _lines.isEmpty
                          ? 'No text recognized'
                          : 'Tap a box to inspect or correct it',
                  actions: [
                    if (_lines.isNotEmpty)
                      IconButton(
                        tooltip: _showBoxes ? 'Hide boxes' : 'Show boxes',
                        isSelected: _showBoxes,
                        icon: const Icon(Icons.layers_clear_outlined),
                        selectedIcon: const Icon(Icons.layers_outlined),
                        onPressed: () => setState(() => _showBoxes = !_showBoxes),
                      ),
                    IconButton(tooltip: 'Zoom', icon: const Icon(Icons.zoom_in), onPressed: () => _zoom(path)),
                  ],
                  children: [
                    if (_scanning) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: Space.md),
                    ],
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(color: scheme.surfaceContainerLow, child: _photo(path)),
                    ),
                    if (_lines.isNotEmpty) ...[
                      const SizedBox(height: Space.md),
                      _legend(),
                      const SizedBox(height: Space.lg),
                      Text('Verification', style: text.labelLarge),
                      const SizedBox(height: Space.sm),
                      _checks(),
                    ],
                  ],
                ),
                const SizedBox(height: Space.lg),
              ],
              _Section(
                icon: Icons.fact_check_outlined,
                title: 'Details',
                subtitle: path == null ? 'Nothing is saved until you tap Save' : 'Check every value before saving',
                children: [
                  TextFormField(
                    controller: _merchant,
                    decoration: const InputDecoration(
                      labelText: 'Merchant',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter the merchant' : null,
                  ),
                  const SizedBox(height: Space.lg),
                  TextFormField(
                    controller: _amount,
                    style: weight(text.titleMedium!.copyWith(fontFeatures: tabular), 600),
                    decoration: InputDecoration(
                      labelText: 'Total (VND)',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: 'đ',
                      helperText: amount != null && amount > 0 ? formatVnd(amount) : 'Digits only, e.g. 126000',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter a total greater than 0',
                  ),
                  const SizedBox(height: Space.lg),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.event_outlined),
                        suffixIcon: Icon(Icons.edit_calendar_outlined),
                      ),
                      child: Text(formatDate(_date), style: text.bodyLarge),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('Category', style: text.labelLarge),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                    for (final c in categories)
                      ChoiceChip(
                        avatar: Icon(categoryIcons[c], color: categoryColor(context, c)),
                        label: Text(c),
                        selected: _category == c,
                        showCheckmark: false,
                        selectedColor: scheme.primaryContainer,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ]),
                  const SizedBox(height: Space.xl),
                  TextFormField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ],
              ),
              if (_raw.text.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: const Icon(Icons.text_snippet_outlined),
                    title: const Text('Recognized text'),
                    subtitle: const Text('Fix the raw OCR text, then parse it again'),
                    childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
                    children: [
                      TextField(
                        controller: _raw,
                        maxLines: null,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _apply(ReceiptParser.parse(_raw.text)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Parse again'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _scanning ? null : _save,
                icon: _scanning
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Save expense'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _fieldIcons = {
  Field.total: Icons.payments_outlined,
  Field.date: Icons.event_outlined,
  Field.merchant: Icons.storefront_outlined,
};

/// Card with an icon + title header, optional header actions and a body.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Widget> actions, children;
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleMedium),
                Text(subtitle, style: text.bodySmall),
              ]),
            ),
            ...actions,
          ]),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ]),
      ),
    );
  }
}
