import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

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
        await showCupertinoDialog<void>(
          context: context,
          builder: (context) => const CupertinoAlertDialog(
            title: Text('Backup imported'),
            content: Text('Please restart the app.'),
          ),
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

    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(confirm ? 'Set Backup Password' : 'Enter Backup Password'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              obscureText: true,
              placeholder: 'Password',
            ),
            if (confirm) ...[
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: confirmController,
                obscureText: true,
                placeholder: 'Confirm Password',
              ),
            ]
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
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
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Backup'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('Last backup'),
                  trailing: Text(_lastBackup ?? 'Never'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  CupertinoButton.filled(
                    onPressed: _busy ? null : _exportBackup,
                    child: const Text('Export Backup'),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: _busy ? null : _importBackup,
                    child: const Text('Import Backup'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const CupertinoActivityIndicator(),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}