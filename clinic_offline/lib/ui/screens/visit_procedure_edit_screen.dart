import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/visit_procedures_repository.dart';
import '../../providers.dart';
import '../widgets/money_format.dart';
import 'procedure_edit_screen.dart';

class VisitProcedureEditScreen extends ConsumerStatefulWidget {
  const VisitProcedureEditScreen({
    super.key,
    required this.visitId,
    this.existing,
  });

  final String visitId;
  final VisitProcedureWithName? existing;

  @override
  ConsumerState<VisitProcedureEditScreen> createState() =>
      _VisitProcedureEditScreenState();
}

class _VisitProcedureEditScreenState
    extends ConsumerState<VisitProcedureEditScreen> {
  String? _procedureId;
  String? _procedureName;
  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _procedureId = existing.procedureId;
      _procedureName = existing.procedureName;
      _qtyController.text = existing.quantity.toString();
      _unitPriceController.text =
          (existing.unitPrice / 100).toStringAsFixed(2);
      if (existing.discount > 0) {
        _discountController.text =
            (existing.discount / 100).toStringAsFixed(2);
      }
      _notesController.text = existing.notes ?? '';
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitPriceController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProcedure() async {
    final procedures = await ref.read(proceduresRepositoryProvider).watchAll().first;
    if (!mounted) return;

    if (procedures.isEmpty) {
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const ProcedureEditScreen()),
      );
      return;
    }

    final selected = await showCupertinoModalPopup<Procedure>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Procedure'),
        actions: [
          for (final proc in procedures)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(proc),
              child: Text(proc.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _procedureId = selected.id;
        _procedureName = selected.name;
        if (_unitPriceController.text.trim().isEmpty &&
            selected.defaultPrice != null) {
          _unitPriceController.text =
              (selected.defaultPrice! / 100).toStringAsFixed(2);
        }
      });
    }
  }

  Future<void> _save() async {
    if (_procedureId == null) return;

    final quantity = int.tryParse(_qtyController.text.trim()) ?? 1;
    final unitPrice = tryToCents(_unitPriceController.text.trim());
    if (unitPrice == null) return;
    final discount = tryToCents(_discountController.text.trim()) ?? 0;

    final repo = ref.read(visitProceduresRepositoryProvider);
    final id = widget.existing?.id ?? const Uuid().v4();

    await repo.upsert(
      VisitProceduresCompanion(
        id: Value(id),
        visitId: Value(widget.visitId),
        procedureId: Value(_procedureId!),
        quantity: Value(quantity),
        unitPrice: Value(unitPrice),
        discount: Value(discount),
        notes: Value(
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
        createdAt: Value(widget.existing?.createdAt ?? DateTime.now()),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.existing == null ? 'Add Procedure' : 'Edit Procedure'),
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
                  prefix: const Text('Procedure'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickProcedure,
                    child: Text(_procedureName ?? 'Select'),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Quantity'),
                  child: CupertinoTextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Unit Price (\u20BA)'),
                  child: CupertinoTextField(
                    controller: _unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Discount (\u20BA)'),
                  child: CupertinoTextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: 'Optional',
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
            if (_procedureName == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select a procedure to continue.'),
              ),
          ],
        ),
      ),
    );
  }
}
