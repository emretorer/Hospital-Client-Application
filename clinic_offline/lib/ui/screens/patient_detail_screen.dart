import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'edit_patient_screen.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  static final DateFormat _trFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(_patientProvider(widget.patientId));
    final appointmentsAsync = ref.watch(
      _appointmentsProvider(widget.patientId),
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Patient'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openEditPatient,
          child: const Text('Edit'),
        ),
      ),
      child: SafeArea(
        child: patientAsync.when(
          data: (patient) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    children: [
                      CupertinoListTile(title: Text(patient.fullName)),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    header: const Text('Info'),
                    children: [
                      CupertinoListTile(
                        title: const Text('Phone'),
                        trailing: Text(patient.phone ?? '-'),
                      ),
                      CupertinoListTile(
                        title: const Text('Gender'),
                        trailing: Text(_genderLabel(patient.gender)),
                      ),
                      if (patient.dateOfBirth != null)
                        CupertinoListTile(
                          title: const Text('Date of Birth'),
                          trailing: Text(
                            DateFormat(
                              'dd.MM.yyyy',
                              'tr_TR',
                            ).format(patient.dateOfBirth!),
                          ),
                        ),
                      if (patient.notes != null)
                        CupertinoListTile(
                          title: const Text('Notes'),
                          trailing: Text(
                            patient.notes!,
                            style: CupertinoTheme.of(
                              context,
                            ).textTheme.textStyle,
                          ),
                        ),
                    ],
                  ),
                ),
                appointmentsAsync.when(
                  data: (items) => SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      header: const Text('Appointments'),
                      children: [
                        if (items.isEmpty)
                          const CupertinoListTile(
                            title: Text('No appointments yet.'),
                          ),
                        for (final appt in items)
                          CupertinoListTile(
                            title: Text(_formatTurkeyTime(appt.scheduledAt)),
                            subtitle: Text(appt.note ?? '-'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Center(
                                    child: Icon(_statusIcon(appt.status)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(appt.status),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $err')),
                  ),
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                ),
              ],
            );
          },
          error: (err, _) => Center(child: Text('Error: $err')),
          loading: () => const Center(child: CupertinoActivityIndicator()),
        ),
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

  String _genderLabel(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'female':
        return 'Female';
      case 'male':
        return 'Male';
      case 'other':
        return 'Other';
      default:
        return '-';
    }
  }

  Future<void> _openEditPatient() async {
    final patient = await ref
        .read(patientsRepositoryProvider)
        .getById(widget.patientId);
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => EditPatientScreen(patient: patient)),
    );
    ref.invalidate(_patientProvider(widget.patientId));
  }
}

final _patientProvider = FutureProvider.family((ref, String id) {
  return ref.watch(patientsRepositoryProvider).getById(id);
});

final _appointmentsProvider = StreamProvider.family((ref, String id) {
  return ref.watch(appointmentsRepositoryProvider).watchByPatient(id);
});
