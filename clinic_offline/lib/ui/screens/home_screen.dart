import 'package:flutter/material.dart';

import 'appointments_screen.dart';
import 'backup_screen.dart';
import 'patients_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          PatientsScreen(),
          AppointmentsScreen(),
          BackupScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Patients'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Appointments'),
          NavigationDestination(icon: Icon(Icons.backup), label: 'Backup'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}