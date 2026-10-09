import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'camera_screen.dart';
import 'charts.dart';
import 'demo_data.dart';
import 'expense.dart';
import 'receipt_image.dart';
import 'review_screen.dart';
import 'theme.dart';

/// Latest Android build (GitHub Releases), offered by the web demo.
final apkUrl = Uri.parse('https://github.com/sunsanti/receipt-ocr-expense-tracker/releases/latest/download/receipt-tracker.apk');

void main() => runApp(const ProviderScope(child: App()));

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Receipt Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeScreen(),
      );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Today", "Yesterday" or "Tue, 06/10/2026".
String dayLabel(DateTime d, DateTime today) {
  final days = DateUtils.dateOnly(today).difference(DateUtils.dateOnly(d)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${_weekdays[d.weekday - 1]}, ${formatDate(d)}';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  Future<void> _openReview({Expense? expense, String? imagePath}) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ReviewScreen(expense: expense, imagePath: imagePath)),
    );
    if (result == ReviewScreen.deleted && expense != null) _delete(expense);
  }

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, Space.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.sm),
              child: Text('Add expense', style: Theme.of(context).textTheme.titleLarge),
            ),
            // ML Kit OCR is mobile-only, so the web demo offers manual entry only.
            if (kIsWeb)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
                leading: const Icon(Icons.info_outline),
                title: const Text('Receipt scanning runs in the mobile app'),
                subtitle: const Text('On-device OCR (ML Kit) needs Android or iOS. Tap to download the Android app.'),
                trailing: const Icon(Icons.download_outlined),
                onTap: () => launchUrl(apkUrl),
              ),
            for (final (value, icon, title, subtitle) in const [
              ('camera', Icons.photo_camera_outlined, 'Scan with camera', 'Frame the receipt, tap to focus, flash if it is dark'),
              ('gallery', Icons.photo_library_outlined, 'Choose from gallery', 'Use a receipt photo you already took'),
              ('manual', Icons.edit_outlined, 'Enter manually', 'Type the merchant, total and date'),
            ])
              if (!kIsWeb || value == 'manual')
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xs),
                leading: _IconTile(icon),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, value),
              ),
          ]),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'manual') return _openReview();
    if (choice == 'camera') {
      if (!mounted) return;
      final cropped = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
      if (cropped != null) await _openReview(imagePath: cropped);
      return;
    }
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (img != null) await _openReview(imagePath: img.path);
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open $choice: ${e.message}')));
      }
    }
  }

  Future<void> _delete(Expense e) async {
    final notifier = ref.read(expensesProvider.notifier);
    await notifier.delete(e);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted ${e.merchant}'),
        action: SnackBarAction(label: 'Undo', onPressed: () => notifier.save(e)),
      ));
  }

  Widget _empty() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 44, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: Space.xl),
          Text('No expenses yet', style: text.titleLarge),
          const SizedBox(height: Space.sm),
          Text(
            'Scan a receipt and the app reads the total, date and merchant for you — all on your phone.',
            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xl),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(kIsWeb ? 'Add your first expense' : 'Scan your first receipt'),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () async {
                final notifier = ref.read(expensesProvider.notifier);
                for (final e in demoExpenses(DateTime.now())) {
                  await notifier.save(e);
                }
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Load demo data'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _list(List<Expense> expenses) {
    if (expenses.isEmpty) return _empty();
    final now = DateTime.now();
    final byDay = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      byDay.putIfAbsent(DateUtils.dateOnly(e.date), () => []).add(e);
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ContentWidth(
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.sm),
          sliver: SliverToBoxAdapter(child: SummaryCard(expenses: expenses, now: now)),
        ),
        for (final MapEntry(key: day, value: items) in byDay.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.sm),
              child: Row(children: [
                Expanded(
                  child: Text(dayLabel(day, now), style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Text(
                  formatVnd(items.fold(0, (s, e) => s + e.amount)),
                  style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabular),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            sliver: SliverToBoxAdapter(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final (i, e) in items.indexed) ...[
                    if (i > 0) const Divider(indent: 72),
                    _ExpenseTile(
                      key: ValueKey(e.id),
                      expense: e,
                      onTap: () => _openReview(expense: e),
                      onDismissed: () => _delete(e),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 112)), // clear the FAB
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Expenses' : 'Charts'),
        actions: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: TextButton.icon(
                onPressed: () => launchUrl(apkUrl),
                icon: const Icon(Icons.android),
                label: const Text('Get the app'),
              ),
            ),
        ],
      ),
      body: switch (ref.watch(expensesProvider)) {
        AsyncData(:final value) => _tab == 0 ? _list(value) : ChartsView(expenses: value),
        AsyncError(:final error) => Center(child: Text('Could not load expenses: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(kIsWeb ? 'Add expense' : 'Scan receipt'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Charts',
          ),
        ],
      ),
    );
  }
}

/// This month's total, receipt count and change vs last month.
class SummaryCard extends StatelessWidget {
  final List<Expense> expenses;
  final DateTime now;
  const SummaryCard({super.key, required this.expenses, required this.now});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    bool inMonth(Expense e, DateTime m) => e.date.year == m.year && e.date.month == m.month;
    final last = DateTime(now.year, now.month - 1);
    final thisMonth = expenses.where((e) => inMonth(e, now)).toList();
    final total = thisMonth.fold(0, (s, e) => s + e.amount);
    final prev = expenses.where((e) => inMonth(e, last)).fold(0, (s, e) => s + e.amount);
    final change = prev == 0 ? null : (total - prev) * 100 / prev;
    final onCard = scheme.brightness == Brightness.dark ? scheme.onPrimaryContainer : scheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.dark ? scheme.primaryContainer : scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Spent in ${monthNames[now.month - 1]}', style: text.bodyMedium!.copyWith(color: onCard)),
        const SizedBox(height: Space.xs),
        Text(
          formatVnd(total),
          style: text.displaySmall!.copyWith(color: onCard, fontSize: 34, fontFeatures: tabular),
        ),
        const SizedBox(height: Space.lg),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          _Pill(
            icon: Icons.receipt_outlined,
            label: '${thisMonth.length} ${thisMonth.length == 1 ? 'receipt' : 'receipts'}',
            color: onCard,
          ),
          if (change != null)
            _Pill(
              icon: change > 0 ? Icons.trending_up : Icons.trending_down,
              label: '${change > 0 ? '+' : '−'}${change.abs().round()}% vs ${monthNames[last.month - 1].substring(0, 3)}',
              color: onCard,
            ),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color)),
        ]),
      );
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  const _IconTile(this.icon);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: scheme.onPrimaryContainer),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap, onDismissed;
  const _ExpenseTile({super.key, required this.expense, required this.onTap, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = expense;
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Delete', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: scheme.onError)),
          const SizedBox(width: Space.sm),
          Icon(Icons.delete_outline, color: scheme.onError),
        ]),
      ),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        leading: _Leading(e),
        title: Text(e.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(e.note.isEmpty ? e.category : '${e.category} · ${e.note}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          formatVnd(e.amount),
          style: weight(Theme.of(context).textTheme.bodyLarge!, 600).copyWith(fontFeatures: tabular),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Receipt thumbnail with a small category badge, or just the badge when the
/// expense has no photo (manual entry, web).
class _Leading extends StatelessWidget {
  final Expense expense;
  const _Leading(this.expense);

  @override
  Widget build(BuildContext context) {
    final file = kIsWeb ? null : thumbFile(expense.thumbPath);
    if (file == null) return CategoryBadge(expense.category);
    return SizedBox.square(
      dimension: 48,
      child: Stack(clipBehavior: Clip.none, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            cacheWidth: 132, // decode small: it's a 44 dp tile
            semanticLabel: 'Receipt photo',
            errorBuilder: (_, _, _) => CategoryBadge(expense.category),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerLowest, width: 2),
            ),
            child: CategoryBadge(expense.category, size: 20),
          ),
        ),
      ]),
    );
  }
}
