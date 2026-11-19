import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/account.dart';
import '../data/models/report.dart';
import '../features/auth/auth_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/municipal_report_detail.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/confirmation_screen.dart';
import '../features/reports/my_reports_screen.dart';
import '../features/reports/new_report_screen.dart';
import '../features/reports/report_detail_screen.dart';
import 'app_state.dart';
import 'theme.dart';
import 'ui.dart';

GoRouter createRouter(AppState appState) => GoRouter(
  refreshListenable: appState,
  redirect: (context, state) {
    final path = state.uri.path;
    final isAuth = path == '/connexion' || path == '/inscription';
    final role = appState.account?.role;
    final isDashboard = path == '/dashboard' || path.startsWith('/dashboard/');
    if (role == null) return isAuth ? null : '/connexion';
    if (role != AccountRole.citizen) {
      return isDashboard ? null : '/dashboard';
    }
    return isAuth || isDashboard || path == '/' ? '/accueil' : null;
  },
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/accueil'),
    GoRoute(path: '/connexion', builder: (_, _) => const AuthScreen()),
    GoRoute(
      path: '/inscription',
      builder: (_, _) => const AuthScreen(registration: true),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (_, _) => const DashboardScreen(),
      routes: [
        GoRoute(
          path: 'signalements/:id',
          builder: (_, state) =>
              MunicipalReportDetail(id: state.pathParameters['id']!),
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _CitizenShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/accueil', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/signalements',
              builder: (_, _) => const MyReportsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profil', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    GoRoute(path: '/nouveau', builder: (_, _) => const NewReportScreen()),
    GoRoute(
      path: '/signalements/:id',
      builder: (_, state) =>
          _ReportRoute(id: state.pathParameters['id']!, confirmation: false),
    ),
    GoRoute(
      path: '/confirmation/:id',
      builder: (_, state) =>
          _ReportRoute(id: state.pathParameters['id']!, confirmation: true),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page indisponible')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/'),
        child: const Text('Retour à Reportini'),
      ),
    ),
  ),
);

class _CitizenShell extends StatelessWidget {
  const _CitizenShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final account = context.select<AppState, Account?>(
      (state) => state.account,
    );
    final titles = ['Accueil', 'Mes signalements', 'Profil'];
    return Scaffold(
      appBar: AppBar(
        title: BrandTitle(titles[shell.currentIndex]),
        actions: [
          if (account != null)
            IconButton(
              tooltip: 'Profil',
              onPressed: () => shell.goBranch(2),
              icon: AccountAvatar(id: account.id, name: account.name),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(bottom: false, child: shell),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: civicLine)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              label: titles[0],
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home, color: civicBlue),
            ),
            NavigationDestination(
              label: titles[1],
              icon: const Icon(Icons.assignment_outlined),
              selectedIcon: const Icon(Icons.assignment, color: civicBlue),
            ),
            NavigationDestination(
              label: titles[2],
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: civicBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRoute extends StatelessWidget {
  const _ReportRoute({required this.id, required this.confirmation});
  final String id;
  final bool confirmation;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Report? report;
    for (final item in state.myReports) {
      if (item.id == id) {
        report = item;
        break;
      }
    }
    if (report != null) {
      return confirmation
          ? ConfirmationScreen(report: report)
          : ReportDetailScreen(report: report);
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/signalements')),
        title: const Text('Signalement'),
      ),
      body: Center(
        child: state.reportsLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.reportsUnavailable
                        ? 'Impossible de charger ce signalement.'
                        : 'Signalement introuvable.',
                  ),
                  if (state.reportsUnavailable)
                    TextButton(
                      onPressed: state.refreshReports,
                      child: const Text('Réessayer'),
                    ),
                  TextButton(
                    onPressed: () => context.go('/signalements'),
                    child: const Text('Mes signalements'),
                  ),
                ],
              ),
      ),
    );
  }
}
