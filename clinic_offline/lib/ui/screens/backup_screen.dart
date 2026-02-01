import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final backupService = ref.read(backupServiceProvider);
    final value = await backupService.lastBackupTimestamp();
    if (mounted) {
      setState(() => _lastBackup = value);
    }
  }

  Future<void> _exportBackup() async {
    final appLock = ref.read(appLockServiceProvider);
    final ok = await appLock.authenticate(reason: 'Export clinic backup');
    if (!ok) {
      _showError('Authentication failed.');
      return;
    }

    final password = await _promptPassword(confirm: true);
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final file = await backupService.exportBackup(password);
      await Share.shareXFiles([XFile(file.path)], text: 'Clinic backup');
      await _loadLastBackup();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importBackup() async {
    final appLock = ref.read(appLockServiceProvider);
    final ok = await appLock.authenticate(reason: 'Import clinic backup');
    if (!ok) {
      _showError('Authentication failed.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['enc'],
    );
    if (result == null || result.files.single.path == null) return;

    final password = await _promptPassword(confirm: false);
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.importBackup(File(result.files.single.path!), password);
      await _loadLastBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported. Restart app.')),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _promptPassword({required bool confirm}) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirm ? 'Set Backup Password' : 'Enter Backup Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (confirm && controller.text != confirmController.text) {
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result == null || result.isEmpty ? null : result;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last backup: ${_lastBackup ?? 'Never'}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _exportBackup,
              icon: const Icon(Icons.backup),
              label: const Text('Export Backup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _importBackup,
              icon: const Icon(Icons.download),
              label: const Text('Import Backup'),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ]
          ],
        ),
      ),
    );
  }
}