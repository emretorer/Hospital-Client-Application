import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../providers.dart';
import '../widgets/money_format.dart';

final _monthlyEntriesProvider =
    StreamProvider.family<List<RevenueEntry>, DateTime>((ref, monthStart) {
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
      final repo = ref.watch(analyticsRepositoryProvider);
      return repo.watchMonthlyRevenueEntries(monthStart, monthEnd);
    });

enum RevenueDateSort { newestFirst, oldestFirst }

enum RevenueCostSort { lowToHigh, highToLow }

enum RevenueProcedureSort { aToZ, zToA }

enum RevenueGenderFilter { all, female, male }

Widget _formPrefix(String text) {
  return SizedBox(
    width: 64,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, textAlign: TextAlign.left),
    ),
  );
}

class RevenueFilters {
  const RevenueFilters({
    this.startDate,
    this.endDate,
    this.patientName = '',
    this.gender = RevenueGenderFilter.all,
    this.minAge,
    this.maxAge,
    this.dateSort = RevenueDateSort.newestFirst,
    this.costSort = RevenueCostSort.highToLow,
    this.procedureSort = RevenueProcedureSort.aToZ,
    this.selectedProcedures = const <String>{},
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String patientName;
  final RevenueGenderFilter gender;
  final int? minAge;
  final int? maxAge;
  final RevenueDateSort dateSort;
  final RevenueCostSort costSort;
  final RevenueProcedureSort? procedureSort;
  final Set<String>? selectedProcedures;

  RevenueProcedureSort get procedureSortSafe =>
      procedureSort ?? RevenueProcedureSort.aToZ;
  Set<String> get selectedProceduresSafe =>
      selectedProcedures ?? const <String>{};

  RevenueFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? patientName,
    RevenueGenderFilter? gender,
    int? minAge,
    int? maxAge,
    RevenueDateSort? dateSort,
    RevenueCostSort? costSort,
    RevenueProcedureSort? procedureSort,
    Set<String>? selectedProcedures,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearMinAge = false,
    bool clearMaxAge = false,
    bool clearSelectedProcedures = false,
  }) {
    return RevenueFilters(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      patientName: patientName ?? this.patientName,
      gender: gender ?? this.gender,
      minAge: clearMinAge ? null : (minAge ?? this.minAge),
      maxAge: clearMaxAge ? null : (maxAge ?? this.maxAge),
      dateSort: dateSort ?? this.dateSort,
      costSort: costSort ?? this.costSort,
      procedureSort: procedureSort ?? procedureSortSafe,
      selectedProcedures: clearSelectedProcedures
          ? <String>{}
          : (selectedProcedures ?? selectedProceduresSafe),
    );
  }
}

class RevenueScreen extends ConsumerStatefulWidget {
  const RevenueScreen({super.key});

  @override
  ConsumerState<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends ConsumerState<RevenueScreen> {
  static const int _collapsedItemCount = 8;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  RevenueFilters _filters = const RevenueFilters();
  final Set<String> _expandedIds = <String>{};
  bool _showAll = false;
  bool _wasTickerModeEnabled = true;
  int _amountAnimVersion = 0;

  @override
  Widget build(BuildContext context) {
    final tickerEnabled = TickerMode.of(context);
    if (tickerEnabled && !_wasTickerModeEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _amountAnimVersion++);
      });
    }
    _wasTickerModeEnabled = tickerEnabled;

    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);
    final entriesAsync = ref.watch(_monthlyEntriesProvider(_selectedMonth));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Revenues'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showFilterSheet,
          child: const Icon(CupertinoIcons.line_horizontal_3_decrease_circle),
        ),
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
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month - 1,
                          1,
                        );
                        _expandedIds.clear();
                        _showAll = false;
                      });
                    },
                    child: const Icon(CupertinoIcons.chevron_left),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickMonth,
                    child: Text(
                      monthLabel,
                      style: CupertinoTheme.of(
                        context,
                      ).textTheme.navTitleTextStyle,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month + 1,
                          1,
                        );
                        _expandedIds.clear();
                        _showAll = false;
                      });
                    },
                    child: const Icon(CupertinoIcons.chevron_right),
                  ),
                ],
              ),
            ),
            if (_hasActiveFilters(_filters))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters active',
                        style: CupertinoTheme.of(context).textTheme.textStyle
                            .copyWith(color: CupertinoColors.systemBlue),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _filters = const RevenueFilters();
                          _expandedIds.clear();
                          _showAll = false;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            entriesAsync.when(
              data: (entries) => _buildContent(context, entries),
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

  Widget _buildContent(BuildContext context, List<RevenueEntry> entries) {
    final filtered = _applyFilters(entries, _selectedMonth, _filters);
    final sorted = [...filtered]
      ..sort((a, b) => _compareEntries(a, b, _filters));

    final grossTotal = sorted.fold<int>(
      0,
      (sum, item) => sum + item.totalCents,
    );
    final visitProductCosts = <String, int>{};
    for (final entry in sorted) {
      if (entry.isManualIncomeSafe) continue;
      visitProductCosts[entry.visitId] = entry.visitProductCostCents;
    }
    final totalProductCost = visitProductCosts.values.fold<int>(
      0,
      (sum, item) => sum + item,
    );
    final netTotal = grossTotal - totalProductCost;

    final visibleCount = _showAll
        ? sorted.length
        : math.min(_collapsedItemCount, sorted.length);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('amount-$_amountAnimVersion-$netTotal'),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: netTotal.toDouble()),
            builder: (context, value, _) {
              return Text(
                centsToTry(value.round()),
                style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CupertinoButton.filled(
            onPressed: _showAddIncomeSheet,
            child: const Text('Add Income'),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revenues',
                style: TextStyle(fontSize: 36 / 2, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (sorted.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(
                      context,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No procedures for this month.'),
                ),
              for (var i = 0; i < sorted.take(visibleCount).length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(
                      context,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGrey4.resolveFrom(context),
                    ),
                  ),
                  child: _buildEntryTile(context, sorted[i]),
                ),
              ],
            ],
          ),
        ),
        if (sorted.length > _collapsedItemCount)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: CupertinoButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'Load less' : 'Load more'),
            ),
          ),
      ],
    );
  }

  Widget _buildEntryTile(BuildContext context, RevenueEntry entry) {
    final isExpanded = _expandedIds.contains(entry.id);
    final lineTotalAfterCost =
        entry.totalCents -
        (entry.isManualIncomeSafe ? 0 : entry.visitProductCostCents);

    return Column(
      children: [
        CupertinoListTile(
          title: Text(entry.procedureName),
          subtitle: Text(
            '${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(entry.visitAt)} - ${entry.patientName}',
          ),
          trailing: Text(centsToTry(lineTotalAfterCost)),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedIds.remove(entry.id);
              } else {
                _expandedIds.add(entry.id);
              }
            });
          },
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.systemGrey4.resolveFrom(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    'Type',
                    entry.isManualIncomeSafe ? 'Manual income' : 'Procedure',
                  ),
                  _detailRow('Patient', entry.patientName),
                  if (!entry.isManualIncomeSafe)
                    _detailRow(
                      'Gender',
                      _genderLabelFromValue(entry.patientGender),
                    ),
                  if (!entry.isManualIncomeSafe)
                    _detailRow('Age', _ageLabel(entry)),
                  _detailRow('Procedure fee', centsToTry(entry.unitPrice)),
                  _detailRow('Discount', centsToTry(entry.discount)),
                  if (!entry.isManualIncomeSafe)
                    _detailRow(
                      'Product',
                      (entry.usedProductsSummary ?? '').trim().isEmpty
                          ? '-'
                          : entry.usedProductsSummary!.trim(),
                    ),
                  if (!entry.isManualIncomeSafe)
                    _detailRow(
                      'Product cost',
                      entry.visitProductCostCents <= 0
                          ? '-'
                          : '-${centsToTry(entry.visitProductCostCents)}',
                    ),
                  if ((entry.productName ?? '').trim().isNotEmpty)
                    _detailRow('Product', entry.productName!.trim()),
                  if ((entry.notes ?? '').trim().isNotEmpty)
                    _detailRow('Notes', entry.notes!.trim()),
                  _detailRow(
                    'Total',
                    centsToTry(lineTotalAfterCost),
                    hasDivider: false,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool hasDivider = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: CupertinoColors.label,
                fontSize: 16,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
        if (hasDivider) Container(height: 1, color: CupertinoColors.separator),
      ],
    );
  }

  Future<void> _pickMonth() async {
    final selected = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => _MonthPickerSheet(initial: _selectedMonth),
    );

    if (selected == null) return;

    setState(() {
      _selectedMonth = DateTime(selected.year, selected.month, 1);
      _expandedIds.clear();
      _showAll = false;
    });
  }

  Future<void> _showFilterSheet() async {
    final entries = await ref.read(
      _monthlyEntriesProvider(_selectedMonth).future,
    );
    if (!mounted) return;
    final procedureOptions =
        entries.map((e) => e.procedureName).toSet().toList()..sort();

    final result = await showCupertinoModalPopup<RevenueFilters>(
      context: context,
      builder: (context) => _RevenueFilterSheet(
        initial: _filters,
        procedureOptions: procedureOptions,
      ),
    );

    if (result == null) return;

    setState(() {
      _filters = result;
      _expandedIds.clear();
      _showAll = false;
    });
  }

  Future<void> _showAddIncomeSheet() async {
    final results = await Future.wait([
      ref.read(patientsRepositoryProvider).watchAll().first,
      ref.read(proceduresRepositoryProvider).watchAll().first,
      ref.read(productsRepositoryProvider).watchAll().first,
    ]);
    if (!mounted) return;
    final patients = results[0] as List<Patient>;
    final procedures = results[1] as List<Procedure>;
    final products = results[2] as List<Product>;

    final result = await showCupertinoModalPopup<_ManualIncomeDraft>(
      context: context,
      builder: (context) => _AddIncomeSheet(
        patients: patients,
        procedures: procedures,
        products: products,
      ),
    );
    if (result == null) return;

    await ref
        .read(analyticsRepositoryProvider)
        .addManualIncome(
          ManualIncomesCompanion(
            id: Value(const Uuid().v4()),
            title: Value(result.title),
            amount: Value(result.amount),
            incomeAt: Value(result.incomeAt),
            patientName: Value(result.patientName),
            procedureName: Value(result.procedureName),
            productName: Value(result.productName),
            notes: Value(result.notes),
            createdAt: Value(DateTime.now()),
          ),
        );

    ref.invalidate(_monthlyEntriesProvider(_selectedMonth));
  }

  List<RevenueEntry> _applyFilters(
    List<RevenueEntry> entries,
    DateTime monthStart,
    RevenueFilters filters,
  ) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final start = filters.startDate == null
        ? monthStart
        : DateTime(
            filters.startDate!.year,
            filters.startDate!.month,
            filters.startDate!.day,
          );
    final endExclusive = filters.endDate == null
        ? monthEnd
        : DateTime(
            filters.endDate!.year,
            filters.endDate!.month,
            filters.endDate!.day + 1,
          );
    final query = filters.patientName.trim().toLowerCase();

    return entries.where((entry) {
      if (entry.visitAt.isBefore(start) ||
          !entry.visitAt.isBefore(endExclusive)) {
        return false;
      }

      if (query.isNotEmpty &&
          !entry.patientName.toLowerCase().contains(query)) {
        return false;
      }

      if (!_matchesGender(entry.patientGender, filters.gender)) {
        return false;
      }

      final age = _computeAge(entry.patientDateOfBirth, entry.visitAt);
      if (filters.minAge != null && (age == null || age < filters.minAge!)) {
        return false;
      }
      if (filters.maxAge != null && (age == null || age > filters.maxAge!)) {
        return false;
      }
      if (filters.selectedProceduresSafe.isNotEmpty &&
          !filters.selectedProceduresSafe.contains(entry.procedureName)) {
        return false;
      }

      return true;
    }).toList();
  }

  int _compareEntries(RevenueEntry a, RevenueEntry b, RevenueFilters filters) {
    final procedureSort = filters.procedureSortSafe;
    final procedureCmp = a.procedureName.toLowerCase().compareTo(
      b.procedureName.toLowerCase(),
    );
    if (procedureCmp != 0) {
      return procedureSort == RevenueProcedureSort.aToZ
          ? procedureCmp
          : -procedureCmp;
    }

    final dateSort = filters.dateSort;
    final costSort = filters.costSort;

    final dateCmp = a.visitAt.compareTo(b.visitAt);
    if (dateCmp != 0) {
      return dateSort == RevenueDateSort.newestFirst ? -dateCmp : dateCmp;
    }

    final costCmp = a.totalCents.compareTo(b.totalCents);
    if (costCmp != 0) {
      return costSort == RevenueCostSort.lowToHigh ? costCmp : -costCmp;
    }

    return a.procedureName.compareTo(b.procedureName);
  }

  bool _matchesGender(String? value, RevenueGenderFilter filter) {
    if (filter == RevenueGenderFilter.all) return true;

    final normalized = (value ?? '').trim().toLowerCase();
    switch (filter) {
      case RevenueGenderFilter.female:
        return normalized == 'female';
      case RevenueGenderFilter.male:
        return normalized == 'male';
      case RevenueGenderFilter.all:
        return true;
    }
  }

  bool _hasActiveFilters(RevenueFilters filters) {
    return filters.startDate != null ||
        filters.endDate != null ||
        filters.patientName.trim().isNotEmpty ||
        filters.gender != RevenueGenderFilter.all ||
        filters.minAge != null ||
        filters.maxAge != null ||
        filters.selectedProceduresSafe.isNotEmpty ||
        filters.dateSort != RevenueDateSort.newestFirst ||
        filters.costSort != RevenueCostSort.highToLow ||
        filters.procedureSortSafe != RevenueProcedureSort.aToZ;
  }

  int? _computeAge(DateTime? dateOfBirth, DateTime atTime) {
    if (dateOfBirth == null) return null;
    var age = atTime.year - dateOfBirth.year;
    final hadBirthday =
        atTime.month > dateOfBirth.month ||
        (atTime.month == dateOfBirth.month && atTime.day >= dateOfBirth.day);
    if (!hadBirthday) age--;
    return age < 0 ? 0 : age;
  }

  String _ageLabel(RevenueEntry entry) {
    final age = _computeAge(entry.patientDateOfBirth, entry.visitAt);
    return age?.toString() ?? '-';
  }

  String _genderLabelFromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'female':
        return 'Female';
      case 'male':
        return 'Male';
      case 'other':
        return 'Other';
      default:
        return 'Unknown';
    }
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late DateTime _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: CupertinoColors.systemBackground,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: const Text('Done'),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.monthYear,
              initialDateTime: _value,
              minimumYear: 2000,
              maximumYear: 2100,
              onDateTimeChanged: (value) {
                setState(() => _value = DateTime(value.year, value.month, 1));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueFilterSheet extends StatefulWidget {
  const _RevenueFilterSheet({
    required this.initial,
    required this.procedureOptions,
  });

  final RevenueFilters initial;
  final List<String> procedureOptions;

  @override
  State<_RevenueFilterSheet> createState() => _RevenueFilterSheetState();
}

class _RevenueFilterSheetState extends State<_RevenueFilterSheet> {
  late RevenueFilters _filters;
  late TextEditingController _nameController;
  late TextEditingController _minAgeController;
  late TextEditingController _maxAgeController;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
    _nameController = TextEditingController(text: _filters.patientName);
    _minAgeController = TextEditingController(
      text: _filters.minAge?.toString() ?? '',
    );
    _maxAgeController = TextEditingController(
      text: _filters.maxAge?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 640,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Text('Filters'),
                  CupertinoButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  CupertinoFormSection.insetGrouped(
                    header: const Text('Date range'),
                    children: [
                      CupertinoFormRow(
                        prefix: _formPrefix('Start'),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _pickStartDate,
                          child: Text(_dateLabel(_filters.startDate)),
                        ),
                      ),
                      CupertinoFormRow(
                        prefix: _formPrefix('End'),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _pickEndDate,
                          child: Text(_dateLabel(_filters.endDate)),
                        ),
                      ),
                    ],
                  ),
                  CupertinoFormSection.insetGrouped(
                    header: const Text('Patient'),
                    children: [
                      CupertinoFormRow(
                        prefix: _formPrefix('Name'),
                        child: CupertinoTextField(
                          controller: _nameController,
                          placeholder: 'Contains...',
                        ),
                      ),
                      CupertinoFormRow(
                        prefix: _formPrefix('Gender'),
                        child:
                            CupertinoSlidingSegmentedControl<
                              RevenueGenderFilter
                            >(
                              groupValue: _filters.gender,
                              children: const {
                                RevenueGenderFilter.all: Text('All'),
                                RevenueGenderFilter.female: Text('F'),
                                RevenueGenderFilter.male: Text('M'),
                              },
                              onValueChanged: (value) {
                                if (value == null) return;
                                setState(
                                  () => _filters = _filters.copyWith(
                                    gender: value,
                                  ),
                                );
                              },
                            ),
                      ),
                      CupertinoFormRow(
                        prefix: _formPrefix('Min age'),
                        child: CupertinoTextField(
                          controller: _minAgeController,
                          keyboardType: TextInputType.number,
                          placeholder: 'Optional',
                        ),
                      ),
                      CupertinoFormRow(
                        prefix: _formPrefix('Max age'),
                        child: CupertinoTextField(
                          controller: _maxAgeController,
                          keyboardType: TextInputType.number,
                          placeholder: 'Optional',
                        ),
                      ),
                    ],
                  ),
                  CupertinoFormSection.insetGrouped(
                    header: const Text('Sorting'),
                    children: [
                      CupertinoFormRow(
                        prefix: _formPrefix('Cost'),
                        child:
                            CupertinoSlidingSegmentedControl<RevenueCostSort>(
                              groupValue: _filters.costSort,
                              children: const {
                                RevenueCostSort.lowToHigh: Text('Low-High'),
                                RevenueCostSort.highToLow: Text('High-Low'),
                              },
                              onValueChanged: (value) {
                                if (value == null) return;
                                setState(
                                  () => _filters = _filters.copyWith(
                                    costSort: value,
                                  ),
                                );
                              },
                            ),
                      ),
                      CupertinoFormRow(
                        prefix: _formPrefix('Select Procedure'),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _pickProcedures,
                          child: Text(_procedureLabel()),
                        ),
                      ),
                      CupertinoFormRow(
                        prefix: _formPrefix('Date'),
                        child:
                            CupertinoSlidingSegmentedControl<RevenueDateSort>(
                              groupValue: _filters.dateSort,
                              children: const {
                                RevenueDateSort.newestFirst: Text('New-Old'),
                                RevenueDateSort.oldestFirst: Text('Old-New'),
                              },
                              onValueChanged: (value) {
                                if (value == null) return;
                                setState(
                                  () => _filters = _filters.copyWith(
                                    dateSort: value,
                                  ),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CupertinoButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const RevenueFilters()),
                      child: const Text('Reset all'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final initial = _filters.startDate ?? DateTime.now();
    final picked = await showCupertinoModalPopup<DateTime?>(
      context: context,
      builder: (context) => _SimpleDatePickerSheet(initial: initial),
    );

    if (picked == null) return;
    setState(() => _filters = _filters.copyWith(startDate: picked));
  }

  Future<void> _pickEndDate() async {
    final initial = _filters.endDate ?? _filters.startDate ?? DateTime.now();
    final picked = await showCupertinoModalPopup<DateTime?>(
      context: context,
      builder: (context) => _SimpleDatePickerSheet(initial: initial),
    );

    if (picked == null) return;
    setState(() => _filters = _filters.copyWith(endDate: picked));
  }

  Future<void> _pickProcedures() async {
    final selected = await showCupertinoModalPopup<Set<String>?>(
      context: context,
      builder: (context) => _ProcedureMultiSelectSheet(
        options: widget.procedureOptions,
        selected: _filters.selectedProceduresSafe,
      ),
    );
    if (selected == null) return;
    setState(() => _filters = _filters.copyWith(selectedProcedures: selected));
  }

  void _apply() {
    final minAge = int.tryParse(_minAgeController.text.trim());
    final maxAge = int.tryParse(_maxAgeController.text.trim());

    Navigator.of(context).pop(
      _filters.copyWith(
        patientName: _nameController.text.trim(),
        minAge: minAge,
        maxAge: maxAge,
        clearMinAge: _minAgeController.text.trim().isEmpty,
        clearMaxAge: _maxAgeController.text.trim().isEmpty,
      ),
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Select';
    return DateFormat('dd.MM.yyyy', 'tr_TR').format(value);
  }

  String _procedureLabel() {
    if (_filters.selectedProceduresSafe.isEmpty) return 'All';
    if (_filters.selectedProceduresSafe.length == 1) {
      return _filters.selectedProceduresSafe.first;
    }
    return '${_filters.selectedProceduresSafe.length} selected';
  }
}

class _ProcedureMultiSelectSheet extends StatefulWidget {
  const _ProcedureMultiSelectSheet({
    required this.options,
    required this.selected,
  });

  final List<String> options;
  final Set<String> selected;

  @override
  State<_ProcedureMultiSelectSheet> createState() =>
      _ProcedureMultiSelectSheetState();
}

class _ProcedureMultiSelectSheetState
    extends State<_ProcedureMultiSelectSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  CupertinoListTile(
                    title: const Text('All procedures'),
                    trailing: _selected.isEmpty
                        ? const Icon(CupertinoIcons.check_mark)
                        : null,
                    onTap: () => setState(() => _selected.clear()),
                  ),
                  for (final option in widget.options)
                    CupertinoListTile(
                      title: Text(option),
                      trailing: _selected.contains(option)
                          ? const Icon(CupertinoIcons.check_mark)
                          : null,
                      onTap: () {
                        setState(() {
                          if (_selected.contains(option)) {
                            _selected.remove(option);
                          } else {
                            _selected.add(option);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleDatePickerSheet extends StatefulWidget {
  const _SimpleDatePickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_SimpleDatePickerSheet> createState() => _SimpleDatePickerSheetState();
}

class _AddIncomeSheet extends StatefulWidget {
  const _AddIncomeSheet({
    required this.patients,
    required this.procedures,
    required this.products,
  });

  final List<Patient> patients;
  final List<Procedure> procedures;
  final List<Product> products;

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _incomeAt = DateTime.now();
  String? _patientName;
  String? _procedureName;
  String? _productName;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 660,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
            Expanded(
              child: Container(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                child: ListView(
                  children: [
                    CupertinoFormSection.insetGrouped(
                      header: const Text('New Income'),
                      children: [
                        CupertinoFormRow(
                          prefix: _formPrefix('Title'),
                          child: CupertinoTextField(
                            controller: _titleController,
                            placeholder: 'Optional',
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: _formPrefix('Patient'),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _pickPatient,
                            child: Text(_patientName ?? 'Select'),
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: _formPrefix('Procedure'),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _pickProcedure,
                            child: Text(_procedureName ?? 'Select'),
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: _formPrefix('Product'),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _pickProduct,
                            child: Text(_productName ?? 'Optional'),
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: _formPrefix('Amount'),
                          child: CupertinoTextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            placeholder: '0.00',
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: _formPrefix('Date'),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _pickDate,
                            child: Text(
                              DateFormat('dd.MM.yyyy', 'tr_TR').format(
                                _incomeAt,
                              ),
                            ),
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: _formPrefix('Notes'),
                          child: CupertinoTextField(
                            controller: _notesController,
                            placeholder: 'Optional',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => _SimpleDatePickerSheet(initial: _incomeAt),
    );
    if (picked == null) return;
    setState(() => _incomeAt = picked);
  }

  Future<void> _pickPatient() async {
    final selected = await _pickFromOptions(
      title: 'Select Patient',
      options: widget.patients.map((e) => e.fullName).toList(),
      allowClear: false,
    );
    if (selected == null) return;
    setState(() => _patientName = selected);
  }

  Future<void> _pickProcedure() async {
    final selected = await _pickFromOptions(
      title: 'Select Procedure',
      options: widget.procedures.map((e) => e.name).toList(),
      allowClear: false,
    );
    if (selected == null) return;
    setState(() => _procedureName = selected);
  }

  Future<void> _pickProduct() async {
    final selected = await _pickFromOptions(
      title: 'Select Product',
      options: widget.products.map((e) => e.name).toList(),
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _productName = selected);
  }

  Future<String?> _pickFromOptions({
    required String title,
    required List<String> options,
    required bool allowClear,
  }) async {
    if (options.isEmpty) return null;
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(option),
            ),
          if (allowClear)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Clear'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop('__cancel__'),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected == null || selected == '__cancel__') return null;
    if (selected.isEmpty) return null;
    return selected;
  }

  void _save() {
    if (_patientName == null || _procedureName == null) {
      return;
    }
    final titleText = _titleController.text.trim();
    final amount = tryToCents(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      return;
    }
    final title = titleText.isEmpty
        ? '${_procedureName!} - ${_patientName!}'
        : titleText;

    Navigator.of(context).pop(
      _ManualIncomeDraft(
        title: title,
        amount: amount,
        incomeAt: _incomeAt,
        patientName: _patientName!,
        procedureName: _procedureName!,
        productName: _productName,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }
}

class _ManualIncomeDraft {
  const _ManualIncomeDraft({
    required this.title,
    required this.amount,
    required this.incomeAt,
    required this.patientName,
    required this.procedureName,
    required this.productName,
    required this.notes,
  });

  final String title;
  final int amount;
  final DateTime incomeAt;
  final String patientName;
  final String procedureName;
  final String? productName;
  final String? notes;
}

class _SimpleDatePickerSheetState extends State<_SimpleDatePickerSheet> {
  late DateTime _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: CupertinoColors.systemBackground,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: const Text('Done'),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _value,
              minimumYear: 2000,
              maximumYear: 2100,
              onDateTimeChanged: (value) => setState(() => _value = value),
            ),
          ),
        ],
      ),
    );
  }
}
