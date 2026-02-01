import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';

class VisitEditScreen extends ConsumerStatefulWidget {
  const VisitEditScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<VisitEditScreen> createState() => _VisitEditScreenState();
}

class _VisitEditScreenState extends ConsumerState<VisitEditScreen> {
  final _complaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _visitAt = DateTime.now();
  final List<_PendingPhoto> _photos = [];
  static final DateFormat _trFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  void dispose() {
    _complaintController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(String kind) async {
    final picker = ImagePicker();
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add Photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Camera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Photo Library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;

    setState(() {
      _photos.add(_PendingPhoto(kind: kind, file: file));
    });
  }

  Future<void> _save() async {
    final visitId = const Uuid().v4();
    final visitsRepo = ref.read(visitsRepositoryProvider);
    final photosRepo = ref.read(photosRepositoryProvider);
    final storage = ref.read(imageStorageProvider);

    final visit = VisitsCompanion(
      id: Value(visitId),
      patientId: Value(widget.patientId),
      visitAt: Value(_visitAt),
      complaint: Value(_complaintController.text.trim().isEmpty
          ? null
          : _complaintController.text.trim()),
      diagnosis: Value(_diagnosisController.text.trim().isEmpty
          ? null
          : _diagnosisController.text.trim()),
      notes: Value(_notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()),
    );

    await visitsRepo.insert(visit);

    for (final pending in _photos) {
      final bytes = await pending.file.readAsBytes();
      final photoId = const Uuid().v4();
      final stored = await storage.saveImage(
        patientId: widget.patientId,
        photoId: photoId,
        bytes: bytes,
      );

      await photosRepo.insert(
        PhotosCompanion(
          id: Value(photoId),
          patientId: Value(widget.patientId),
          visitId: Value(visitId),
          kind: Value(pending.kind),
          takenAt: Value(DateTime.now()),
          relativePath: Value(stored.relativePath),
          thumbRelativePath: Value(stored.thumbRelativePath),
          sha256: Value(stored.sha256),
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('New Visit'),
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
                  prefix: const Text('Visit date'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final picked = await showCupertinoModalPopup<DateTime>(
                        context: context,
                        builder: (context) => _DatePickerSheet(initial: _visitAt),
                      );
                      if (picked != null) {
                        setState(() => _visitAt = picked);
                      }
                    },
                    child: Text(_formatTurkeyTime(_visitAt)),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Complaint'),
                  child: CupertinoTextField(
                    controller: _complaintController,
                    placeholder: 'Optional',
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('Diagnosis'),
                  child: CupertinoTextField(
                    controller: _diagnosisController,
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
            CupertinoFormSection.insetGrouped(
              header: Text('Photos (${_photos.length})'),
              children: [
                CupertinoListTile(
                  title: const Text('Add Before Photo'),
                  trailing: const Icon(CupertinoIcons.camera),
                  onTap: () => _pickPhoto('before'),
                ),
                CupertinoListTile(
                  title: const Text('Add After Photo'),
                  trailing: const Icon(CupertinoIcons.camera),
                  onTap: () => _pickPhoto('after'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTurkeyTime(DateTime value) {
    final trTime = value.toUtc().add(const Duration(hours: 3));
    return _trFormat.format(trTime);
  }
}

class _PendingPhoto {
  _PendingPhoto({required this.kind, required this.file});

  final String kind;
  final XFile file;
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initial});

  final DateTime initial;

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
              mode: CupertinoDatePickerMode.dateAndTime,
              initialDateTime: _value,
              onDateTimeChanged: (value) => setState(() => _value = value),
            ),
          ),
        ],
      ),
    );
  }
}