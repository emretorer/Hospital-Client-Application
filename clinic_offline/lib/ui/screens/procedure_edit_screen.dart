import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';

class ProcedureEditScreen extends ConsumerStatefulWidget {
  const ProcedureEditScreen({super.key, this.procedure});

  final Procedure? procedure;

  @override
  ConsumerState<ProcedureEditScreen> createState() =>
      _ProcedureEditScreenState();
}

class _ProcedureEditScreenState extends ConsumerState<ProcedureEditScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final procedure = widget.procedure;
    if (procedure != null) {
      _nameController.text = procedure.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    final repo = ref.read(proceduresRepositoryProvider);
    final id = widget.procedure?.id ?? const Uuid().v4();

    await repo.upsert(
      ProceduresCompanion(
        id: Value(id),
        name: Value(_nameController.text.trim()),
        defaultPrice: const Value(null),
        createdAt: Value(widget.procedure?.createdAt ?? DateTime.now()),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final procedure = widget.procedure;
    if (procedure == null) return;
    await ref.read(proceduresRepositoryProvider).deleteById(procedure.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.procedure == null ? 'New Procedure' : 'Edit Procedure',
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoFormSection.insetGrouped(
                  margin: EdgeInsets.zero,
                  children: [
                    CupertinoFormRow(
                      prefix: const Text('Name'),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: CupertinoTextField(
                          controller: _nameController,
                          placeholder: 'Required',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.procedure != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: CupertinoButton(
                  onPressed: _delete,
                  color: const Color(0xFFFF4D4D),
                  child: const Text(
                    'Delete Procedure',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
