import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../widgets/money_format.dart';
import 'product_edit_screen.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(_productsProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Products'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const ProductEditScreen()),
            );
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: products.when(
          data: (items) {
            return CupertinoListSection.insetGrouped(
              children: [
                if (items.isEmpty)
                  const CupertinoListTile(title: Text('No products yet.')),
                for (final product in items)
                  CupertinoListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'Qty: ${product.quantity}',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(fontSize: 13),
                    ),
                    trailing: Text(centsToTry(product.unitCost)),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) =>
                              ProductEditScreen(product: product),
                        ),
                      );
                    },
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
}

final _productsProvider = StreamProvider((ref) {
  return ref.watch(productsRepositoryProvider).watchAll();
});
