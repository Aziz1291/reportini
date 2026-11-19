import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../data/models/municipality.dart';
import '../../data/models/report.dart';
import '../reports/report_widgets.dart';
import 'dashboard_widgets.dart';

int countStatus(List<Report> reports, ReportStatus status) =>
    reports.where((report) => report.status == status).length;

class ReportMetrics extends StatelessWidget {
  const ReportMetrics({super.key, required this.reports});
  final List<Report> reports;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final columns = constraints.maxWidth >= 570
          ? 4
          : constraints.maxWidth >= 250
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          SizedBox(
            width: width,
            child: DashboardMetric('Total', reports.length),
          ),
          for (final status in ReportStatus.values)
            SizedBox(
              width: width,
              child: DashboardMetric(
                status == ReportStatus.traite ? 'Traités' : status.label,
                countStatus(reports, status),
              ),
            ),
        ],
      );
    },
  );
}

class MunicipalReportList extends StatefulWidget {
  const MunicipalReportList({
    super.key,
    required this.title,
    this.unassignedOnly = false,
    this.municipalities,
  });
  final String title;
  final bool unassignedOnly;
  final List<Municipality>? municipalities;

  @override
  State<MunicipalReportList> createState() => _MunicipalReportListState();
}

class _MunicipalReportListState extends State<MunicipalReportList> {
  ReportStatus? _status;
  ReportCategory? _category;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final reports = widget.unassignedOnly
        ? state.municipalReports
              .where((item) => item.municipalityId == null)
              .toList()
        : state.municipalReports;
    final names = {
      for (final item in widget.municipalities ?? const <Municipality>[])
        item.id: item.name,
    };
    final visible = reports.where((report) {
      return (_status == null || _status == report.status) &&
          (_category == null || _category == report.category) &&
          [
            report.title,
            report.reference,
            report.location.address,
          ].any((value) => value.toLowerCase().contains(_query));
    }).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: visible.isEmpty ? 2 : visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _filters(reports);
        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: DashboardMessage(
              reports.isEmpty
                  ? 'Aucun signalement pour le moment.'
                  : 'Aucun signalement ne correspond.',
            ),
          );
        }
        final report = visible[index - 1];
        final municipality =
            report.municipalityId == null || widget.municipalities == null
            ? null
            : names[report.municipalityId] ?? report.municipalityName;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ReportCard(
            report,
            key: ValueKey(report.id),
            municipal: true,
            municipalityLabel: municipality,
            onOpen: () => context.push(
              '/dashboard/signalements/${Uri.encodeComponent(report.id)}',
            ),
          ),
        );
      },
    );
  }

  Widget _filters(List<Report> reports) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DashboardHeading(widget.title),
      const SizedBox(height: 16),
      ReportMetrics(reports: reports),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const Key('municipal-report-search'),
            controller: _search,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              labelText: 'Rechercher un signalement',
              hintText: 'Titre, référence ou adresse',
              prefixIcon: Icon(Icons.search),
            ),
          );
          final category = DropdownButtonFormField<ReportCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            isExpanded: true,
            items: [
              const DropdownMenuItem<ReportCategory>(
                child: Text('Toutes les catégories'),
              ),
              for (final category in ReportCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          );
          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 12),
                Expanded(child: category),
              ],
            );
          }
          return Column(
            children: [search, const SizedBox(height: 10), category],
          );
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: Text('Tous (${reports.length})'),
            selected: _status == null,
            onSelected: (_) => setState(() => _status = null),
          ),
          for (final status in ReportStatus.values)
            ChoiceChip(
              label: Text('${status.label} (${countStatus(reports, status)})'),
              selected: _status == status,
              onSelected: (selected) =>
                  setState(() => _status = selected ? status : null),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
}
