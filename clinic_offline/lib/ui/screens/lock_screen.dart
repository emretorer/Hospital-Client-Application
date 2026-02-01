import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _hasPin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final service = ref.read(appLockServiceProvider);
    final hasPin = await service.hasPin();
    setState(() => _hasPin = hasPin);
    final canBio = await service.canCheckBiometrics();
    if (canBio) {
      await _authenticateBiometric();
    }
  }

  Future<void> _authenticateBiometric() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = ref.read(appLockServiceProvider);
    final success = await service.authenticate(reason: 'Unlock clinic records');
    if (mounted) {
      setState(() => _loading = false);
    }
    if (success && mounted) {
      context.go('/');
    }
  }

  Future<void> _submitPin() async {
    final service = ref.read(appLockServiceProvider);
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_hasPin) {
      final ok = await service.verifyPin(_pinController.text.trim());
      if (ok && mounted) {
        context.go('/');
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Invalid PIN.';
      });
      return;
    }

    if (_pinController.text.trim().length < 4) {
      setState(() {
        _loading = false;
        _error = 'PIN must be at least 4 digits.';
      });
      return;
    }

    if (_pinController.text.trim() != _confirmController.text.trim()) {
      setState(() {
        _loading = false;
        _error = 'PINs do not match.';
      });
      return;
    }

    await service.setPin(_pinController.text.trim());
    if (mounted) {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Clinic Offline',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hasPin
                        ? 'Enter PIN or use biometrics.'
                        : 'Set a local PIN for offline access.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'PIN'),
                  ),
                  if (!_hasPin) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Confirm PIN'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submitPin,
                    child: Text(_hasPin ? 'Unlock' : 'Set PIN'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _authenticateBiometric,
                    child: const Text('Use Face ID / Touch ID'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}