import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/account.dart';
import '../../data/models/municipality.dart';
import '../../data/models/report.dart';
import '../profile/profile_screen.dart';
import 'agent_management.dart';
import 'dashboard_widgets.dart';
import 'municipal_report_list.dart';
import 'municipality_management.dart';

enum _Section {
  overview('Vue d’ensemble', Icons.space_dashboard_outlined),
  reports('Signalements', Icons.assignment_outlined),
  unassigned('Hors zone', Icons.location_off_outlined),
  municipalities('Municipalités', Icons.apartment_outlined),
  agents('Comptes agents', Icons.groups_outlined),
  account('Compte', Icons.person_outline);

  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.select((AppState state) => state.account);
    if (account == null || account.role == AccountRole.citizen) {
      return const SizedBox.shrink();
    }
    return _Dashboard(
      key: ValueKey((account.id, account.role)),
      account: account,
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({super.key, required this.account});
  final Account account;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late final _admin = widget.account.role == AccountRole.admin;
  late final _sections = _admin
      ? const [
          _Section.overview,
          _Section.reports,
          _Section.unassigned,
          _Section.municipalities,
          _Section.agents,
        ]
      : const [_Section.reports, _Section.account];
  late final _repository = context.read<AppState>().municipalities;
  late var _municipalities = _repository.watchMunicipalities();
  int _selected = 0;
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await context.read<AppState>().signOut();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Impossible de se déconnecter. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Municipality>>(
    stream: _municipalities,
    builder: (context, snapshot) {
      final municipalities = snapshot.data ?? const <Municipality>[];
      final names = {for (final item in municipalities) item.id: item.name};
      final account = widget.account;
      final subtitle = _admin
          ? 'Administration'
          : names[account.municipalityId] ??
                (snapshot.connectionState == ConnectionState.waiting
                    ? 'Chargement de la municipalité…'
                    : 'Municipalité indisponible');
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  if (wide) ...[
                    const BrandTitle('Espace municipal'),
                    const SizedBox(width: 24),
                  ] else if (!_admin) ...[
                    const BrandLogo(),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Se déconnecter',
                  onPressed: _signingOut ? null : _signOut,
                  icon: const Icon(Icons.logout),
                ),
                const SizedBox(width: 8),
              ],
            ),
            drawer: wide || !_admin
                ? null
                : Drawer(
                    child: SafeArea(
                      child: ListView(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: BrandTitle('Espace municipal'),
                          ),
                          for (var index = 0; index < _sections.length; index++)
                            ListTile(
                              selected: _selected == index,
                              leading: Icon(_sections[index].icon),
                              title: Text(_sections[index].label),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _selected = index);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
            bottomNavigationBar: wide || _admin
                ? null
                : NavigationBar(
                    selectedIndex: _selected,
                    onDestinationSelected: (index) =>
                        setState(() => _selected = index),
                    destinations: [
                      for (final section in _sections)
                        NavigationDestination(
                          icon: Icon(section.icon),
                          label: section.label,
                        ),
                    ],
                  ),
            body: SafeArea(
              child: Row(
                children: [
                  if (wide) ...[
                    NavigationRail(
                      backgroundColor: Colors.white,
                      scrollable: true,
                      extended: constraints.maxWidth >= 1150,
                      labelType: constraints.maxWidth >= 1150
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      selectedIndex: _selected,
                      onDestinationSelected: (index) =>
                          setState(() => _selected = index),
                      destinations: [
                        for (final section in _sections)
                          NavigationRailDestination(
                            icon: Icon(section.icon),
                            label: Text(section.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, color: civicLine),
                  ],
                  Expanded(
                    child: DashboardContent(
                      child: _buildSection(snapshot, municipalities, subtitle),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Widget _buildSection(
    AsyncSnapshot<List<Municipality>> snapshot,
    List<Municipality> municipalities,
    String subtitle,
  ) {
    final section = _sections[_selected];
    if (section == _Section.overview ||
        section == _Section.agents ||
        section == _Section.municipalities) {
      if (snapshot.hasError) {
        return DashboardMessage(
          'Impossible de charger les municipalités.',
          retry: () => setState(
            () => _municipalities = _repository.watchMunicipalities(),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
    }
    return switch (section) {
      _Section.overview => _Overview(municipalities: municipalities),
      _Section.reports => MunicipalReportList(
        title: _admin ? 'Tous les signalements' : 'Signalements reçus',
        municipalities: _admin ? municipalities : null,
      ),
      _Section.unassigned => const MunicipalReportList(
        key: ValueKey('hors-zone'),
        title: 'Hors zone',
        unassignedOnly: true,
      ),
      _Section.municipalities => MunicipalityManagement(
        municipalities: municipalities,
      ),
      _Section.agents => AgentManagement(municipalities: municipalities),
      _Section.account => PageList(
        children: [
          const DashboardHeading('Compte'),
          const SizedBox(height: 16),
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.account.name),
                Text(widget.account.email),
                Text(subtitle),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const LogoutButton(),
        ],
      ),
    };
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.municipalities});
  final List<Municipality> municipalities;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.reportsUnavailable) {
      return DashboardMessage(
        'Impossible de charger les signalements.',
        retry: state.retryMunicipalReports,
      );
    }
    if (state.reportsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final reports = state.municipalReports;
    final names = <String?, String>{
      for (final report in reports)
        report.municipalityId: report.municipalityName,
      for (final item in municipalities) item.id: item.name,
      null: 'Hors zone',
    };
    final groups = <String?, List<Report>>{};
    for (final report in reports) {
      (groups[report.municipalityId] ??= []).add(report);
    }
    final entries = names.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DashboardHeading('Vue d’ensemble'),
        const SizedBox(height: 16),
        ReportMetrics(reports: reports),
        const SizedBox(height: 24),
        Text(
          'Signalements par municipalité',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Total ${groups[entry.key]?.length ?? 0}'),
                      for (final status in ReportStatus.values)
                        Text(
                          '${status.label} ${countStatus(groups[entry.key] ?? const [], status)}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
