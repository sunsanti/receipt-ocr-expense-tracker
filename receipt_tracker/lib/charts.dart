import 'dart:math';

import 'package:flutter/material.dart';

import 'expense.dart';
import 'theme.dart';

/// Totals for the [months] months ending at [now]'s month, oldest first.
List<(DateTime, int)> monthlyTotals(List<Expense> xs, DateTime now, {int months = 6}) =>
    List.generate(months, (i) {
      final m = DateTime(now.year, now.month - (months - 1 - i));
      return (m, xs.where((e) => e.date.year == m.year && e.date.month == m.month).fold(0, (s, e) => s + e.amount));
    });

/// Non-zero category totals for [month], largest first.
List<(String, int)> categoryTotals(List<Expense> xs, DateTime month) {
  final totals = <String, int>{};
  for (final e in xs.where((e) => e.date.year == month.year && e.date.month == month.month)) {
    totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  }
  return totals.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Replays a 0→1 ease-out animation whenever [data] changes (by value).
/// Instant when the system asks for reduced motion.
Widget animatedPaint(BuildContext context, Object data, CustomPainter Function(double progress) painter) =>
    TweenAnimationBuilder<double>(
      key: ValueKey(data),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.chart),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => CustomPaint(painter: painter(t), size: Size.infinite),
    );

String compactVnd(int v) => v >= 1000000
    ? '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M'
    : v >= 1000
        ? '${(v / 1000).round()}K'
        : '$v';

String shortMonth(DateTime m) => monthNames[m.month - 1].substring(0, 3);

class ChartsView extends StatefulWidget {
  final List<Expense> expenses;
  const ChartsView({super.key, required this.expenses});

  @override
  State<ChartsView> createState() => _ChartsViewState();
}

class _ChartsViewState extends State<ChartsView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final monthly = monthlyTotals(widget.expenses, DateTime.now());
    final byCategory = categoryTotals(widget.expenses, _month);
    final monthTotal = byCategory.fold(0, (s, c) => s + c.$2);
    final average = monthly.fold(0, (s, m) => s + m.$2) ~/ monthly.length;
    final selected = monthly.indexWhere((m) => m.$1 == _month);

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl),
        children: [
          Row(children: [
            Expanded(child: _Stat(label: 'This month', value: formatVnd(monthly.last.$2), icon: Icons.calendar_month_outlined)),
            const SizedBox(width: Space.md),
            Expanded(child: _Stat(label: '6-month average', value: formatVnd(average), icon: Icons.functions)),
          ]),
          const SizedBox(height: Space.lg),
          _ChartCard(
            title: 'Monthly spending',
            subtitle: 'Last 6 months · tap a bar to see its categories',
            child: Semantics(
              label: 'Bar chart of monthly spending: '
                  '${monthly.map((m) => '${monthNames[m.$1.month - 1]} ${formatVnd(m.$2)}').join(', ')}',
              child: SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    onTapUp: (d) {
                      final i = (d.localPosition.dx / (c.maxWidth / monthly.length)).floor().clamp(0, monthly.length - 1);
                      setState(() => _month = monthly[i].$1);
                    },
                    child: animatedPaint(
                      context,
                      Object.hashAll(monthly),
                      (t) => BarChartPainter(
                        monthly,
                        bar: scheme.primary,
                        muted: scheme.primary.withValues(alpha: .28),
                        label: scheme.onSurfaceVariant,
                        grid: scheme.outlineVariant,
                        selected: selected,
                        textStyle: text.labelMedium!,
                        progress: t,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          _ChartCard(
            title: 'By category',
            subtitle: '${monthNames[_month.month - 1]} ${_month.year}',
            actions: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
            child: byCategory.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xxl),
                    child: Column(children: [
                      Icon(Icons.donut_large_outlined, size: 40, color: scheme.onSurfaceVariant),
                      const SizedBox(height: Space.sm),
                      Text('No expenses this month', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                    ]),
                  )
                : Column(children: [
                    SizedBox(
                      height: 200,
                      child: Stack(alignment: Alignment.center, children: [
                        ExcludeSemantics(
                          child: animatedPaint(
                            context,
                            Object.hash(_month, Object.hashAll(byCategory)),
                            (t) => DonutChartPainter(
                              byCategory,
                              colors: [for (final (c, _) in byCategory) categoryColor(context, c)],
                              progress: t,
                            ),
                          ),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('Total', style: text.bodySmall),
                          Text(formatVnd(monthTotal), style: text.titleMedium!.copyWith(fontFeatures: tabular)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: Space.lg),
                    // Legend doubles as the accessible table: icon, name, amount, % and a share bar.
                    for (final (cat, v) in byCategory)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: Row(children: [
                          CategoryBadge(cat, size: 36),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(cat, style: weight(text.bodyLarge!, 600))),
                                Text(formatVnd(v), style: text.bodyMedium!.copyWith(fontFeatures: tabular)),
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    '${(v * 100 / monthTotal).round()}%',
                                    textAlign: TextAlign.right,
                                    style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabular),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: v / monthTotal,
                                  minHeight: 6,
                                  color: categoryColor(context, cat),
                                  backgroundColor: scheme.surfaceContainerHigh,
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: Space.sm),
          Text(label, style: text.bodySmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.titleLarge!.copyWith(fontFeatures: tabular)),
          ),
        ]),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, this.actions = const [], required this.child});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleMedium),
                Text(subtitle, style: text.bodySmall),
              ]),
            ),
            ...actions,
          ]),
          const SizedBox(height: Space.lg),
          Padding(padding: const EdgeInsets.only(right: Space.sm), child: child),
        ]),
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<(DateTime, int)> data;
  final Color bar, muted, label, grid;
  final int selected; // highlighted bar (the month shown in "By category"), -1 for none
  final TextStyle textStyle;
  final double progress; // 0→1: bars grow from the baseline
  BarChartPainter(
    this.data, {
    required this.bar,
    required this.muted,
    required this.label,
    required this.grid,
    required this.textStyle,
    this.selected = -1,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 24.0, valueH = 20.0;
    final chartH = size.height - labelH - valueH;
    final maxV = data.map((d) => d.$2).fold(0, max);
    final slot = size.width / data.length;
    final baseline = valueH + chartH;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, .5, 1.0]) {
      final y = baseline - chartH * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < data.length; i++) {
      final (month, v) = data[i];
      final h = maxV == 0 ? 0.0 : chartH * v / maxV * progress;
      final x = slot * i + slot * .18;
      final isSelected = i == selected;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, baseline - h, slot * .64, h),
            topLeft: const Radius.circular(8), topRight: const Radius.circular(8)),
        Paint()..color = isSelected ? bar : muted,
      );
      if (v > 0) {
        _text(canvas, compactVnd((v * progress).round()), Offset(slot * i + slot / 2, baseline - h - valueH + 2), slot,
            isSelected ? bar : label, isSelected);
      }
      _text(canvas, shortMonth(month), Offset(slot * i + slot / 2, baseline + 6), slot, isSelected ? bar : label, isSelected);
    }
  }

  void _text(Canvas canvas, String s, Offset topCenter, double maxWidth, Color color, bool bold) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: weight(textStyle.copyWith(color: color), bold ? 700 : 500)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, topCenter - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(BarChartPainter old) =>
      old.data != data ||
      old.bar != bar ||
      old.muted != muted ||
      old.label != label ||
      old.grid != grid ||
      old.selected != selected ||
      old.progress != progress;
}

class DonutChartPainter extends CustomPainter {
  final List<(String, int)> data;
  final List<Color> colors; // one per [data] entry
  final double progress; // 0→1: segments sweep in clockwise
  DonutChartPainter(this.data, {required this.colors, this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 28.0;
    final total = data.fold(0, (s, d) => s + d.$2);
    final r = min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final gap = data.length > 1 ? .03 : 0.0;
    var start = -pi / 2; // largest slice starts at 12 o'clock
    final end = -pi / 2 + 2 * pi * progress;
    for (var i = 0; i < data.length; i++) {
      if (start >= end) break;
      final sweep = min(2 * pi * data[i].$2 / total, end - start);
      canvas.drawArc(
        rect,
        start + gap / 2,
        max(sweep - gap, .001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutChartPainter old) => old.data != data || old.colors != colors || old.progress != progress;
}
