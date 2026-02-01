import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class ClinicApp extends ConsumerWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Clinic Offline',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0E5C8F),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      routerConfig: router,
    );
  }
}