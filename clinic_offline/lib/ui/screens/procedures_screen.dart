import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../widgets/money_format.dart';
import 'procedure_edit_screen.dart';

class ProceduresScreen extends ConsumerWidget {
  const ProceduresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final procedures = ref.watch(_proceduresProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Procedures'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const ProcedureEditScreen()),
            );
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: procedures.when(
          data: (items) {
            return CupertinoListSection.insetGrouped(
              children: [
                if (items.isEmpty)
                  const CupertinoListTile(title: Text('No procedures yet.')),
                for (final proc in items)
                  CupertinoListTile(
                    title: Text(proc.name),
                    trailing: Text(proc.defaultPrice == null
                        ? '-'
                        : centsToTry(proc.defaultPrice!)),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => ProcedureEditScreen(procedure: proc),
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

final _proceduresProvider = StreamProvider((ref) {
  return ref.watch(proceduresRepositoryProvider).watchAll();
});