import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../../data/repositories/analytics_repository.dart';
import '../widgets/money_format.dart';

final _selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final _monthlyRevenueProvider = FutureProvider<int>((ref) async {
  final monthStart = ref.watch(_selectedMonthProvider);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getMonthlyRevenue(monthStart, monthEnd);
});

final _breakdownProvider = FutureProvider<List<ProcedureBreakdown>>((ref) async {
  final monthStart = ref.watch(_selectedMonthProvider);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getMonthlyBreakdownByProcedure(monthStart, monthEnd);
});

final _dailyTotalsProvider = FutureProvider<List<DailyTotal>>((ref) async {
  final monthStart = ref.watch(_selectedMonthProvider);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getDailyTotals(monthStart, monthEnd);
});

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_selectedMonthProvider);
    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(month);
    final totalAsync = ref.watch(_monthlyRevenueProvider);
    final breakdownAsync = ref.watch(_breakdownProvider);
    final dailyAsync = ref.watch(_dailyTotalsProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Revenue'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final prev = DateTime(month.year, month.month - 1, 1);
                      ref.read(_selectedMonthProvider.notifier).state = prev;
                    },
                    child: const Icon(CupertinoIcons.chevron_left),
                  ),
                  Text(
                    monthLabel,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navTitleTextStyle,
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final next = DateTime(month.year, month.month + 1, 1);
                      ref.read(_selectedMonthProvider.notifier).state = next;
                    },
                    child: const Icon(CupertinoIcons.chevron_right),
                  ),
                ],
              ),
            ),
            totalAsync.when(
              data: (total) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  centsToTry(total),
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navLargeTitleTextStyle,
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            ),
            breakdownAsync.when(
              data: (items) => CupertinoListSection.insetGrouped(
                header: const Text('By Procedure'),
                children: [
                  if (items.isEmpty)
                    const CupertinoListTile(title: Text('No data.')),
                  for (final item in items)
                    CupertinoListTile(
                      title: Text(item.procedureName),
                      subtitle: Text('Count: ${item.count}'),
                      trailing: Text(centsToTry(item.totalCents)),
                    ),
                ],
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            ),
            dailyAsync.when(
              data: (items) => CupertinoListSection.insetGrouped(
                header: const Text('Daily Totals'),
                children: [
                  if (items.isEmpty)
                    const CupertinoListTile(title: Text('No data.')),
                  for (final item in items)
                    CupertinoListTile(
                      title: Text(DateFormat('dd.MM.yyyy').format(item.day)),
                      trailing: Text(centsToTry(item.totalCents)),
                    ),
                ],
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}