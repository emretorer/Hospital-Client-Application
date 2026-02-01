import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../providers.dart';

class VisitEditScreen extends ConsumerStatefulWidget {
  const VisitEditScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<VisitEditScreen> createState() => _VisitEditScreenState();
}

class _VisitEditScreenState extends ConsumerState<VisitEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _visitAt = DateTime.now();
  final List<_PendingPhoto> _photos = [];
  static final DateFormat _trFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void dispose() {
    _complaintController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(String kind) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
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
    if (!_formKey.currentState!.validate()) return;

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
    return Scaffold(
      appBar: AppBar(title: const Text('New Visit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Visit date: ${_formatTurkeyTime(_visitAt)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDate: _visitAt,
                );
                if (picked != null) {
                  setState(() => _visitAt = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintController,
              decoration: const InputDecoration(labelText: 'Complaint'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(labelText: 'Diagnosis'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('Photos (${_photos.length})'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto('before'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add Before'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto('after'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add After'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save Visit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPhoto {
  _PendingPhoto({required this.kind, required this.file});

  final String kind;
  final XFile file;
}

String _formatTurkeyTime(DateTime value) {
  final trTime = value.toUtc().add(const Duration(hours: 3));
  return '${_VisitEditScreenState._trFormat.format(trTime)} (TRT)';
}
