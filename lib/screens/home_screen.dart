import 'package:flutter/material.dart';

import '../security/security_service.dart';
import '../utils/app_info.dart';
import 'add_transaction_screen.dart';
import 'categories_screen.dart';
import 'dashboard_tab.dart';
import 'lock_screen.dart';
import 'plan_tab.dart';
import 'reports_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => SecurityService.instance.lock(),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: SecurityService.instance,
        builder: (context, _) {
          final service = SecurityService.instance;
          if (service.enabled && !service.unlocked) {
            return const LockScreen();
          }
          return IndexedStack(
            index: _index,
            children: [
              DashboardTab(onShowAll: () => setState(() => _index = 1)),
              const TransactionsScreen(),
              const PlanTab(),
              const ReportsScreen(),
              const CategoriesScreen(),
            ],
          );
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: SecurityService.instance,
        builder: (context, _) {
          final service = SecurityService.instance;
          if (service.enabled && !service.unlocked) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Movimiento'),
          );
        },
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomRight,
        children: [
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Movimientos',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart),
                label: 'Reportes',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: 'Categorías',
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10, bottom: 3),
            child: _NavVersionLabel(),
          ),
        ],
      ),
    );
  }
}

class _NavVersionLabel extends StatelessWidget {
  const _NavVersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: appVersionLabel(),
      builder: (context, snapshot) => Text(
        snapshot.data ?? '',
        style: const TextStyle(
          fontSize: 9,
          height: 1,
          color: Colors.black26,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
