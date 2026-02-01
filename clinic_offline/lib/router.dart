import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ui/screens/backup_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/patient_detail_screen.dart';
import 'ui/screens/patients_screen.dart';
import 'ui/screens/appointments_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/visit_edit_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/lock',
    routes: [
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'patients/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PatientDetailScreen(patientId: id);
            },
          ),
          GoRoute(
            path: 'patients/:id/visit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return VisitEditScreen(patientId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/patients',
        builder: (context, state) => const PatientsScreen(),
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});