import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';
import '../widgets/money_format.dart';

class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  static const double _labelWidth = 110;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _nameController.text = product.name;
      _qtyController.text = product.quantity.toString();
      _unitCostController.text =
          (product.unitCost / 100).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final unitCost = tryToCents(_unitCostController.text.trim()) ?? 0;

    final repo = ref.read(productsRepositoryProvider);
    final id = widget.product?.id ?? const Uuid().v4();

    await repo.upsert(
      ProductsCompanion(
        id: Value(id),
        name: Value(_normalizeName(_nameController.text)),
        quantity: Value(qty),
        unitCost: Value(unitCost),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final product = widget.product;
    if (product == null) return;
    await ref.read(productsRepositoryProvider).deleteById(product.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.product == null ? 'New Product' : 'Edit Product'),
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
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Name:'),
                  ),
                  child: CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Required',
                  ),
                ),
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text(
                      'Qty:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                CupertinoFormRow(
                  prefix: const SizedBox(
                    width: _labelWidth,
                    child: Text('Unit Cost (\u20BA):'),
                  ),
                  child: CupertinoTextField(
                    controller: _unitCostController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '0.00',
                  ),
                ),
              ],
            ),
            if (widget.product != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoButton(
                  onPressed: _delete,
                  color: CupertinoColors.systemRed,
                  child: const Text('Delete Product'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _normalizeName(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.map((part) {
    if (part.isEmpty) return part;
    final lower = _trToLower(part);
    final first = _trToUpper(lower.substring(0, 1));
    final rest = lower.substring(1);
    return '$first$rest';
  }).join(' ');
}

String _trToUpper(String value) {
  return value
      .replaceAll('i', '\u0130')
      .replaceAll('\u0131', 'I')
      .toUpperCase();
}

String _trToLower(String value) {
  return value
      .replaceAll('I', '\u0131')
      .replaceAll('\u0130', 'i')
      .toLowerCase();
}
