import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';

class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;
  static final DateFormat _trFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(_patientProvider(patientId));
    final visitsAsync = ref.watch(_visitsProvider(patientId));
    final appointmentsAsync = ref.watch(_appointmentsProvider(patientId));
    final photosAsync = ref.watch(_photosProvider(patientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Patient')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patients/$patientId/visit'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('New Visit'),
      ),
      body: patientAsync.when(
        data: (patient) {
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                ListTile(
                  title: Text(patient.fullName),
                  subtitle: Text(patient.phone ?? 'No phone'),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Visits'),
                    Tab(text: 'Appointments'),
                    Tab(text: 'Photos'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      visitsAsync.when(
                        data: (visits) => ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final visit = visits[index];
                            final trTime = _formatTurkeyTime(visit.visitAt);
                            return ListTile(
                              title: Text(trTime),
                              subtitle: Text(visit.complaint ?? 'No complaint'),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(),
                          itemCount: visits.length,
                        ),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                      ),
                      appointmentsAsync.when(
                        data: (items) => ListView.separated(
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
                        ),
                        error: (err, _) => Center(child: Text('Error: $err')),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                      ),
                      photosAsync.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return const Center(child: Text('No photos yet.'));
                          }
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final photo = items[index];
                              return _PhotoThumb(relativePath: photo.thumbRelativePath);
                            },
                          );
                        },
                        error: (err, _) => Center(child: Text('Error: $err')),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

final _patientProvider = FutureProvider.family((ref, String id) {
  return ref.watch(patientsRepositoryProvider).getById(id);
});

final _visitsProvider = StreamProvider.family((ref, String id) {
  return ref.watch(visitsRepositoryProvider).watchByPatient(id);
});

final _appointmentsProvider = StreamProvider.family((ref, String id) {
  return ref.watch(appointmentsRepositoryProvider).watchByPatient(id);
});

final _photosProvider = StreamProvider.family((ref, String id) {
  return ref.watch(photosRepositoryProvider).watchByPatient(id);
});

class _PhotoThumb extends ConsumerWidget {
  const _PhotoThumb({required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(imageStorageProvider);
    return FutureBuilder<File>(
      future: service.resolveFromRelative(relativePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(color: Colors.black12);
        }
        return Image.file(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }
}

String _formatTurkeyTime(DateTime value) {
  final trTime = value.toUtc().add(const Duration(hours: 3));
  return '${PatientDetailScreen._trFormat.format(trTime)} (TRT)';
}
