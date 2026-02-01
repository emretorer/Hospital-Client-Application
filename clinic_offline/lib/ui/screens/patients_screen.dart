import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'edit_patient_screen.dart';
import 'patient_detail_screen.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  String _query = '';
  bool _normalized = false;

  @override
  void initState() {
    super.initState();
    _normalizeExisting();
  }

  Future<void> _normalizeExisting() async {
    if (_normalized) return;
    _normalized = true;
    await ref.read(patientsRepositoryProvider).normalizeAllNames();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_patientsStreamProvider(_query));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Patients'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const EditPatientScreen()),
            );
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CupertinoSearchTextField(
                  placeholder: 'Search patients',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            patients.when(
              data: (items) {
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No patients yet.')),
                  );
                }
                return SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    children: [
                      for (final patient in items)
                        CupertinoListTile(
                          title: Text(patient.fullName),
                          trailing: const Icon(CupertinoIcons.chevron_forward),
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) =>
                                    PatientDetailScreen(patientId: patient.id),
                              ),
                            );
                          },
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
            ),
          ],
        ),
      ),
    );
  }
}

final _patientsStreamProvider = StreamProvider.family((ref, String query) {
  final repo = ref.watch(patientsRepositoryProvider);
  return repo.watchAll(query: query);
});
