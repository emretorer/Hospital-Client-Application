import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers.dart';
import 'backup_screen.dart';
import 'procedures_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPin = false;
  bool _lockEnabled = true;
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lock = ref.read(appLockServiceProvider);
    final hasPin = await lock.hasPin();
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('app_lock_enabled') ?? true;
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _lockEnabled = enabled;
        _version = info.version;
      });
    }
  }

  Future<void> _toggleLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
    if (mounted) {
      setState(() => _lockEnabled = value);
    }
  }

  Future<void> _changePin() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();

    final pin = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              placeholder: 'PIN',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              placeholder: 'Confirm PIN',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (controller.text.trim() != confirmController.text.trim()) {
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (pin == null || pin.isEmpty) return;
    await ref.read(appLockServiceProvider).setPin(pin);
    if (mounted) {
      setState(() => _hasPin = true);
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => const CupertinoAlertDialog(
          title: Text('PIN updated'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('Security'),
              children: [
                CupertinoListTile(
                  title: const Text('App Lock'),
                  trailing: CupertinoSwitch(
                    value: _lockEnabled,
                    onChanged: _toggleLock,
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Change PIN'),
                  subtitle: Text(_hasPin ? 'Configured' : 'Not set'),
                  trailing: const Icon(CupertinoIcons.chevron_forward),
                  onTap: _changePin,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Diagnostics'),
              children: const [
                CupertinoListTile(
                  title: Text('Export Diagnostics'),
                  trailing: Icon(CupertinoIcons.chevron_forward),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Catalog'),
              children: [
                CupertinoListTile(
                  title: const Text('Procedures'),
                  trailing: const Icon(CupertinoIcons.chevron_forward),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const ProceduresScreen()),
                    );
                  },
                ),
                CupertinoListTile(
                  title: const Text('Backup'),
                  trailing: const Icon(CupertinoIcons.chevron_forward),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const BackupScreen()),
                    );
                  },
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('About'),
              children: [
                CupertinoListTile(
                  title: const Text('Version'),
                  trailing: Text(_version),
                ),
                const CupertinoListTile(
                  title: Text('Offline-only mode'),
                  subtitle: Text('No online sync. Use encrypted backups.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
