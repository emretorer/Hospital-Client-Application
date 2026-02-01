import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  int _segment = 0;
  String _query = '';
  int _statusFilter = 0;
  static final DateFormat _trFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(_upcomingProvider);
    final past = ref.watch(_pastProvider);
    final patientsAsync = ref.watch(_patientsProvider);
    final current = _segment == 0 ? upcoming : past;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Appointments'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCreateDialog(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _segment,
                  children: const {
                    0: Text('Upcoming'),
                    1: Text('Past'),
                  },
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() => _segment = value);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        placeholder: 'Search by patient',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showFilterPopup(context),
                      child: const Icon(CupertinoIcons.line_horizontal_3_decrease),
                    ),
                  ],
                ),
              ),
            ),
            patientsAsync.when(
              data: (patients) {
                final patientMap = {
                  for (final p in patients) p.id: p.fullName,
                };
                return current.when(
                  data: (items) {
                    final query = _query.trim().toLowerCase();
                    final filtered = items.where((appt) {
                      if (_statusFilter == 1 && appt.status != 'done') {
                        return false;
                      }
                      if (_statusFilter == 2 && appt.status != 'scheduled') {
                        return false;
                      }
                      if (_statusFilter == 3 && appt.status != 'cancelled') {
                        return false;
                      }
                      if (query.isEmpty) return true;
                      final name =
                          (patientMap[appt.patientId] ?? '').toLowerCase();
                      return name.contains(query);
                    }).toList();
                    if (filtered.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(child: Text('No appointments.')),
                      );
                    }
                    return SliverToBoxAdapter(
                      child: CupertinoListSection.insetGrouped(
                        children: [
                          for (final appt in filtered)
                            CupertinoListTile(
                              title: Text(_formatTurkeyTime(appt.scheduledAt)),
                              subtitle: Text(
                                'Patient: ${patientMap[appt.patientId] ?? 'Unknown patient'}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(appt.status)),
                                  const SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _showActionSheet(appt),
                                    child: const Icon(CupertinoIcons.ellipsis),
                                  ),
                                ],
                              ),
                              onTap: () => _showAppointmentDetail(
                                context,
                                appt,
                                patientMap[appt.patientId] ??
                                    'Unknown patient',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  error: (err, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $err')),
                  ),
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                );
              },
              error: (err, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $err')),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final patients = await ref.read(patientsRepositoryProvider).watchAll().first;
    if (!context.mounted) return;

    final result = await showCupertinoDialog<_AppointmentDraft>(
      context: context,
      builder: (context) => _AppointmentDialog(patients: patients),
    );

    if (result == null) return;

    final repo = ref.read(appointmentsRepositoryProvider);
    await repo.upsert(
      AppointmentsCompanion(
        id: Value(const Uuid().v4()),
        patientId: Value(result.patientId),
        scheduledAt: Value(result.scheduledAt),
        status: const Value('scheduled'),
        note: Value(result.note),
      ),
    );
  }

  Future<void> _showActionSheet(Appointment appt) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Update Status'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _updateStatus(appt, 'done');
            },
            child: const Text('Mark Done'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _updateStatus(appt, 'cancelled');
            },
            isDestructiveAction: true,
            child: const Text('Cancel Appointment'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          isDefaultAction: true,
          child: const Text('Close'),
        ),
      ),
    );
  }

  Future<void> _updateStatus(Appointment appt, String status) async {
    final repo = ref.read(appointmentsRepositoryProvider);
    await repo.upsert(
      AppointmentsCompanion(
        id: Value(appt.id),
        patientId: Value(appt.patientId),
        scheduledAt: Value(appt.scheduledAt),
        status: Value(status),
        note: Value(appt.note),
      ),
    );
  }

  String _formatTurkeyTime(DateTime value) {
    final trTime = value.toUtc().add(const Duration(hours: 3));
    return _trFormat.format(trTime);
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'done':
        return CupertinoIcons.check_mark_circled;
      case 'cancelled':
        return CupertinoIcons.xmark_circle;
      default:
        return CupertinoIcons.clock;
    }
  }

  Future<void> _showFilterPopup(BuildContext context) async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('All'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('Done ✓'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(2),
            child: const Text('Upcoming 🕒'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(3),
            child: const Text('Cancelled ✕'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _statusFilter = selected);
    }
  }

  Future<void> _showAppointmentDetail(
    BuildContext context,
    Appointment appt,
    String patientName,
  ) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Appointment'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text('Patient: $patientName'),
            const SizedBox(height: 6),
            Text('Note: ${appt.note ?? '-'}'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

final _upcomingProvider = StreamProvider((ref) {
  return ref.watch(appointmentsRepositoryProvider).watchUpcoming();
});

final _pastProvider = StreamProvider((ref) {
  return ref.watch(appointmentsRepositoryProvider).watchPast();
});

final _patientsProvider = StreamProvider((ref) {
  return ref.watch(patientsRepositoryProvider).watchAll();
});

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({required this.patients});

  final List<Patient> patients;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  String? _patientId;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('New Appointment'),
      content: Column(
        children: [
          const SizedBox(height: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickDate,
            child: Text('Scheduled: ${_formatTurkeyTime(_scheduledAt)}'),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _noteController,
            placeholder: 'Note',
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickPatient,
            child: Text(_patientId == null
                ? 'Select Patient'
                : _selectedPatientName()),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          onPressed: _patientId == null
              ? null
              : () {
                  Navigator.of(context).pop(
                    _AppointmentDraft(
                      patientId: _patientId!,
                      scheduledAt: _scheduledAt,
                      note: _noteController.text.trim().isEmpty
                          ? null
                          : _noteController.text.trim(),
                    ),
                  );
                },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => _DatePickerSheet(initial: _scheduledAt),
    );
    if (picked != null) {
      setState(() => _scheduledAt = picked);
    }
  }

  Future<void> _pickPatient() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Patient'),
        actions: [
          for (final patient in widget.patients)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(patient.id),
              child: Text(patient.fullName),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _patientId = selected);
    }
  }

  String _selectedPatientName() {
    final match = widget.patients.firstWhere(
      (p) => p.id == _patientId,
      orElse: () => widget.patients.first,
    );
    return match.fullName;
  }

  String _formatTurkeyTime(DateTime value) {
    final trTime = value.toUtc().add(const Duration(hours: 3));
    return _AppointmentsScreenState._trFormat.format(trTime);
  }
}

class _AppointmentDraft {
  _AppointmentDraft({
    required this.patientId,
    required this.scheduledAt,
    required this.note,
  });

  final String patientId;
  final DateTime scheduledAt;
  final String? note;
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _value;
  late DateTime _datePart;
  late DateTime _timePart;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    _datePart = DateTime(_value.year, _value.month, _value.day);
    _timePart = DateTime(0, 1, 1, _value.hour, _value.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
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
            child: Column(
              children: [
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _datePart,
                    minimumYear: 2000,
                    maximumYear: 2100,
                    onDateTimeChanged: (value) {
                      setState(() {
                        _datePart = DateTime(value.year, value.month, value.day);
                        _value = DateTime(
                          _datePart.year,
                          _datePart.month,
                          _datePart.day,
                          _timePart.hour,
                          _timePart.minute,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: _timePart,
                    use24hFormat: true,
                    onDateTimeChanged: (value) {
                      setState(() {
                        _timePart = DateTime(0, 1, 1, value.hour, value.minute);
                        _value = DateTime(
                          _datePart.year,
                          _datePart.month,
                          _datePart.day,
                          _timePart.hour,
                          _timePart.minute,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
