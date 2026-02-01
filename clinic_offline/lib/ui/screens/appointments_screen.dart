import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(_upcomingProvider);
    final past = ref.watch(_pastProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            upcoming.when(
              data: (items) => _AppointmentList(items: items),
              error: (err, _) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            past.when(
              data: (items) => _AppointmentList(items: items),
              error: (err, _) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final patients = await ref.read(patientsRepositoryProvider).watchAll().first;
    if (!context.mounted) return;

    final result = await showDialog<_AppointmentDraft>(
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
}

final _upcomingProvider = StreamProvider((ref) {
  return ref.watch(appointmentsRepositoryProvider).watchUpcoming();
});

final _pastProvider = StreamProvider((ref) {
  return ref.watch(appointmentsRepositoryProvider).watchPast();
});

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({required this.items});

  final List<Appointment> items;
  static final DateFormat _trFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No appointments.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final appt = items[index];
        final trTime = _formatTurkeyTime(appt.scheduledAt);
        return ListTile(
          title: Text(trTime),
          subtitle: Text(appt.status),
        );
      },
      separatorBuilder: (_, __) => const Divider(),
      itemCount: items.length,
    );
  }
}

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
    return AlertDialog(
      title: const Text('New Appointment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _patientId,
            items: widget.patients
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.fullName),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _patientId = value),
            decoration: const InputDecoration(labelText: 'Patient'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Scheduled: ${_formatTurkeyTime(_scheduledAt)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                initialDate: _scheduledAt,
              );
              if (picked != null) {
                setState(() => _scheduledAt = picked);
              }
            },
          ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
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

String _formatTurkeyTime(DateTime value) {
  final trTime = value.toUtc().add(const Duration(hours: 3));
  return '${_AppointmentList._trFormat.format(trTime)} (TRT)';
}
