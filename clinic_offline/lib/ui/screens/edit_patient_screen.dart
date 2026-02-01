import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';

class EditPatientScreen extends ConsumerStatefulWidget {
  const EditPatientScreen({super.key, this.patient});

  final Patient? patient;

  @override
  ConsumerState<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends ConsumerState<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    if (patient != null) {
      _nameController.text = patient.fullName;
      _phoneController.text = patient.phone ?? '';
      _notesController.text = patient.notes ?? '';
      _dob = patient.dateOfBirth;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(patientsRepositoryProvider);
    final id = widget.patient?.id ?? const Uuid().v4();
    final companion = PatientsCompanion(
      id: Value(id),
      fullName: Value(_nameController.text.trim()),
      phone: Value(_phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim()),
      notes: Value(_notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()),
      dateOfBirth: Value(_dob),
      createdAt: Value(widget.patient?.createdAt ?? DateTime.now()),
    );

    await repo.upsert(companion);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient == null ? 'Add Patient' : 'Edit Patient'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dob == null
                  ? 'Date of birth'
                  : 'DOB: ${_dob!.toLocal().toString().split(' ').first}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  initialDate: _dob ?? DateTime(1990, 1, 1),
                );
                if (picked != null) {
                  setState(() => _dob = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
