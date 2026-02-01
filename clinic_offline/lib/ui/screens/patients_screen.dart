import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import 'edit_patient_screen.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(patientsRepositoryProvider);
    final patients = ref.watch(_patientsStreamProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch<String?>(
                context: context,
                delegate: _PatientSearchDelegate(initial: _query),
              );
              if (result != null) {
                setState(() => _query = result);
              }
            },
          ),
        ],
      ),
      body: patients.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No patients yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final patient = items[index];
              return ListTile(
                title: Text(patient.fullName),
                subtitle: patient.phone == null
                    ? null
                    : Text(patient.phone!),
                onTap: () => context.go('/patients/${patient.id}'),
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: items.length,
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditPatientScreen()),
          );
          repo.watchAll(query: _query);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

final _patientsStreamProvider = StreamProvider.family((ref, String query) {
  final repo = ref.watch(patientsRepositoryProvider);
  return repo.watchAll(query: query);
});

class _PatientSearchDelegate extends SearchDelegate<String?> {
  _PatientSearchDelegate({required this.initial}) {
    query = initial;
  }

  final String initial;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildPrompt(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildPrompt(context);
  }

  Widget _buildPrompt(BuildContext context) {
    return ListTile(
      title: Text('Search for "$query"'),
      onTap: () => close(context, query),
    );
  }
}