import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../../data/repositories/visit_procedures_repository.dart';
import '../widgets/money_format.dart';
import 'visit_procedure_edit_screen.dart';

class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(_visitProvider(visitId));
    final itemsAsync = ref.watch(_visitProceduresProvider(visitId));
    final totalAsync = ref.watch(_visitTotalProvider(visitId));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Visit'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => VisitProcedureEditScreen(visitId: visitId),
              ),
            );
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            visitAsync.when(
              data: (visit) => CupertinoListSection.insetGrouped(
                header: const Text('Visit Details'),
                children: [
                  CupertinoListTile(
                    title: const Text('Date'),
                    trailing: Text(
                      DateFormat('dd.MM.yyyy HH:mm', 'tr_TR')
                          .format(visit.visitAt.toUtc().add(const Duration(hours: 3))),
                    ),
                  ),
                  if (visit.complaint != null)
                    CupertinoListTile(
                      title: const Text('Complaint'),
                      subtitle: Text(visit.complaint!),
                    ),
                  if (visit.diagnosis != null)
                    CupertinoListTile(
                      title: const Text('Diagnosis'),
                      subtitle: Text(visit.diagnosis!),
                    ),
                  if (visit.notes != null)
                    CupertinoListTile(
                      title: const Text('Notes'),
                      subtitle: Text(visit.notes!),
                    ),
                ],
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Procedures & Charges'),
              children: [
                itemsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const CupertinoListTile(
                        title: Text('No procedures yet.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          CupertinoListTile(
                            title: Text(item.procedureName),
                            subtitle: Text(
                              'Qty ${item.quantity} - '
                              'Fee ${centsToTry(item.unitPrice)}'
                              '${item.discount > 0 ? ' - Discount ${centsToTry(item.discount)}' : ''}',
                            ),
                            trailing: Text(centsToTry(item.lineTotalCents)),
                            onTap: () => _showLineItemActions(context, item),
                          ),
                      ],
                    );
                  },
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $err'),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
              ],
            ),
            totalAsync.when(
              data: (total) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Visit Total'),
                    Text(centsToTry(total)),
                  ],
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLineItemActions(
    BuildContext context,
    VisitProcedureWithName item,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(item.procedureName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => VisitProcedureEditScreen(
                    visitId: item.visitId,
                    existing: item,
                  ),
                ),
              );
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteLineItem(context, item);
            },
            isDestructiveAction: true,
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _deleteLineItem(
    BuildContext context,
    VisitProcedureWithName item,
  ) async {
    final repo = ProviderScope.containerOf(context)
        .read(visitProceduresRepositoryProvider);
    await repo.deleteById(item.id);
  }
}

final _visitProvider = FutureProvider.family((ref, String id) {
  return ref.watch(visitsRepositoryProvider).getById(id);
});

final _visitProceduresProvider = StreamProvider.family((ref, String id) {
  return ref.watch(visitProceduresRepositoryProvider).watchByVisit(id);
});

final _visitTotalProvider = StreamProvider.family((ref, String id) {
  return ref.watch(visitProceduresRepositoryProvider).watchVisitTotalCents(id);
});
