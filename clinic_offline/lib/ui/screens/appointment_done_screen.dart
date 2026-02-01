import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';
import '../widgets/money_format.dart';
import 'procedure_edit_screen.dart';

class AppointmentDoneScreen extends ConsumerStatefulWidget {
  const AppointmentDoneScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<AppointmentDoneScreen> createState() =>
      _AppointmentDoneScreenState();
}

class _AppointmentDoneScreenState extends ConsumerState<AppointmentDoneScreen> {
  static const double _labelWidth = 140;
  String? _procedureId;
  String? _procedureName;
  final _unitPriceController = TextEditingController();
  final _discountController = TextEditingController();
  String? _productId;
  String? _productName;
  int? _productMaxQty;
  final _productQtyController = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _unitPriceController.dispose();
    _discountController.dispose();
    _productQtyController.dispose();
    super.dispose();
  }

  Future<void> _pickProcedure() async {
    final procedures =
        await ref.read(proceduresRepositoryProvider).watchAll().first;
    if (!mounted) return;

    if (procedures.isEmpty) {
      await _showError('No procedures found. Add a procedure first.');
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

  Future<void> _createProcedure() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const ProcedureEditScreen()),
    );
    if (!mounted) return;
    await _pickProcedure();
  }

  Future<void> _pickProduct() async {
    final products =
        await ref.read(productsRepositoryProvider).watchAll().first;
    if (!mounted) return;

    if (products.isEmpty) {
      await _showError('No products found. Add a product first.');
      return;
    }

    final selected = await showCupertinoModalPopup<Product>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Product'),
        actions: [
          for (final product in products)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(product),
              child: Text(product.name),
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
        _productId = selected.id;
        _productName = selected.name;
        _productMaxQty = selected.quantity;
        if (int.tryParse(_productQtyController.text) == null) {
          _productQtyController.text = '0';
        }
      });
    }
  }

  Future<void> _save() async {
    if (_procedureId == null) {
      await _showError('Select a procedure.');
      return;
    }
    if (_unitPriceController.text.trim().isEmpty) {
      await _showError('Enter a price.');
      return;
    }
    final unitPrice = tryToCents(_unitPriceController.text.trim());
    if (unitPrice == null) {
      await _showError('Enter a valid price.');
      return;
    }
    final discount = tryToCents(_discountController.text.trim()) ?? 0;
    final productQty = int.tryParse(_productQtyController.text.trim()) ?? 0;
    if (_productId != null &&
        _productMaxQty != null &&
        productQty > _productMaxQty!) {
      await _showError('Max available: $_productMaxQty');
      return;
    }

    setState(() => _saving = true);
    try {
      final visitId = const Uuid().v4();
      final visitsRepo = ref.read(visitsRepositoryProvider);
      final visitProceduresRepo = ref.read(visitProceduresRepositoryProvider);
      final appointmentsRepo = ref.read(appointmentsRepositoryProvider);
      final productsRepo = ref.read(productsRepositoryProvider);
      final productUsagesRepo = ref.read(productUsagesRepositoryProvider);

      await visitsRepo.insert(
        VisitsCompanion(
          id: Value(visitId),
          patientId: Value(widget.appointment.patientId),
          visitAt: Value(widget.appointment.scheduledAt),
        ),
      );

      await visitProceduresRepo.upsert(
        VisitProceduresCompanion(
          id: Value(const Uuid().v4()),
          visitId: Value(visitId),
          procedureId: Value(_procedureId!),
          quantity: const Value(1),
          unitPrice: Value(unitPrice),
          discount: Value(discount),
          createdAt: Value(DateTime.now()),
        ),
      );

      if (_productId != null && productQty > 0) {
        await productsRepo.adjustQuantity(_productId!, -productQty);
        await productUsagesRepo.insert(
          ProductUsagesCompanion(
            id: Value(const Uuid().v4()),
            visitId: Value(visitId),
            productId: Value(_productId!),
            quantity: Value(productQty),
            createdAt: Value(DateTime.now()),
          ),
        );
      }

      await appointmentsRepo.upsert(
        AppointmentsCompanion(
          id: Value(widget.appointment.id),
          patientId: Value(widget.appointment.patientId),
          scheduledAt: Value(widget.appointment.scheduledAt),
          status: const Value('done'),
          note: Value(widget.appointment.note),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      await _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Mark Done'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('Procedure & Charge'),
              children: [
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Procedure'),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: CupertinoColors.systemGrey4,
                              ),
                            ),
                      child: Align(
                        alignment: Alignment.center,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _pickProcedure,
                                child: Text(_procedureName ?? 'Select'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        width: 36,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                            ),
                          ),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _createProcedure,
                            child: const Icon(CupertinoIcons.add),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Procedure Fee (\u20BA)'),
                  ),
                  child: CupertinoTextField(
                    controller: _unitPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Discount (\u20BA)'),
                  ),
                  child: CupertinoTextField(
                    controller: _discountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    placeholder: 'Optional',
                  ),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Product Usage'),
              children: [
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Product'),
                  ),
                  child: SizedBox(
                    height: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: CupertinoColors.systemGrey4,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _pickProduct,
                          child: Text(_productName ?? 'Not used'),
                        ),
                      ),
                    ),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Qty Used'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CupertinoTextField(
                        controller: _productQtyController,
                        keyboardType: TextInputType.number,
                      ),
                      if (_productId != null && _productMaxQty != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Available: $_productMaxQty',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
