import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lock = ref.read(appLockServiceProvider);
    final hasPin = await lock.hasPin();
    if (mounted) {
      setState(() => _hasPin = hasPin);
    }
  }

  Future<void> _changePin() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();

    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('App Lock PIN'),
            subtitle: Text(_hasPin ? 'Configured' : 'Not set'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePin,
          ),
          const Divider(),
          const ListTile(
            title: Text('Offline-only mode'),
            subtitle: Text('No online sync. Use encrypted backups.'),
          ),
        ],
      ),
    );
  }
}