import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';
import '../../data/repositories/patients_repository.dart';

class EditPatientScreen extends ConsumerStatefulWidget {
  const EditPatientScreen({super.key, this.patient});

  final Patient? patient;

  @override
  ConsumerState<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends ConsumerState<EditPatientScreen> {
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
    if (_nameController.text.trim().isEmpty) return;

    final repo = ref.read(patientsRepositoryProvider);
    final id = widget.patient?.id ?? const Uuid().v4();
    final companion = PatientsCompanion(
      id: Value(id),
      fullName:
          Value(PatientsRepository.normalizePatientName(_nameController.text)),
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.patient == null ? 'Add Patient' : 'Edit Patient'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              children: [
                CupertinoFormRow(
                  prefix: const Text('Full name'),
                  child: CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Required',
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Phone'),
                  child: CupertinoTextField(
                    controller: _phoneController,
                    placeholder: 'Optional',
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('DOB'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final picked = await showCupertinoModalPopup<DateTime>(
                        context: context,
                        builder: (context) => _DatePickerSheet(
                          initial: _dob ?? DateTime(1990, 1, 1),
                          mode: CupertinoDatePickerMode.date,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _dob = picked);
                      }
                    },
                    child: Text(_dob == null
                        ? 'Select'
                        : _dob!.toLocal().toString().split(' ').first),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Notes'),
                  child: CupertinoTextField(
                    controller: _notesController,
                    placeholder: 'Optional',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initial, required this.mode});

  final DateTime initial;
  final CupertinoDatePickerMode mode;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
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
              mode: widget.mode,
              initialDateTime: _value,
              onDateTimeChanged: (value) => setState(() => _value = value),
            ),
          ),
        ],
      ),
    );
  }
}
