import 'package:flutter/cupertino.dart';

import 'appointments_screen.dart';
import 'backup_screen.dart';
import 'patients_screen.dart';
import 'products_screen.dart';
import 'revenue_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cube_box),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: 'Revenue',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.archivebox),
            label: 'Backup',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (_) => const PatientsScreen(),
            );
          case 1:
            return CupertinoTabView(
              builder: (_) => const AppointmentsScreen(),
            );
          case 2:
            return CupertinoTabView(
              builder: (_) => const ProductsScreen(),
            );
          case 3:
            return CupertinoTabView(
              builder: (_) => const RevenueScreen(),
            );
          case 4:
            return CupertinoTabView(
              builder: (_) => const BackupScreen(),
            );
          case 5:
            return CupertinoTabView(
              builder: (_) => const SettingsScreen(),
            );
          default:
            return CupertinoTabView(
              builder: (_) => const PatientsScreen(),
            );
        }
      },
    );
  }
}
