import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../data/models/account.dart';
import '../../data/models/municipality.dart';
import '../../data/models/report.dart';
import '../../data/repositories/report_repository.dart';
import '../reports/report_detail_screen.dart';
import 'dashboard_widgets.dart';

class MunicipalReportDetail extends StatelessWidget {
  const MunicipalReportDetail({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    for (final report in state.municipalReports) {
      if (report.id != id) continue;
      return ReportDetailScreen(
        report: report,
        showCitizen: true,
        backPath: '/dashboard',
        actions: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Changer le statut'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => _StatusDialog(report, state.reports),
              ),
            ),
            if (state.account?.role == AccountRole.admin &&
                report.municipalityId == null)
              OutlinedButton.icon(
                icon: const Icon(Icons.apartment_outlined),
                label: const Text('Affecter à une municipalité'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => _AssignmentDialog(report.id, state),
                ),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du signalement'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
      ),
      body: state.reportsLoading
          ? const Center(child: CircularProgressIndicator())
          : DashboardMessage(
              state.reportsUnavailable
                  ? 'Impossible de charger le signalement.'
                  : 'Signalement indisponible dans votre espace.',
              retry: state.reportsUnavailable
                  ? state.retryMunicipalReports
                  : null,
            ),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog(this.report, this.repository);
  final Report report;
  final ReportRepository repository;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  ReportStatus? _status;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DashboardFormDialog(
    title: 'Changer le statut',
    submitLabel: 'Enregistrer',
    onSubmit: () =>
        widget.repository.changeStatus(widget.report.id, _status!, _note.text),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Statut actuel · ${widget.report.status.label}'),
        const SizedBox(height: 12),
        DropdownButtonFormField<ReportStatus>(
          decoration: const InputDecoration(labelText: 'Nouveau statut'),
          items: [
            for (final status in ReportStatus.values)
              if (status != widget.report.status)
                DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          validator: (value) =>
              value == null ? 'Sélectionnez un statut.' : null,
          onChanged: (value) => _status = value,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (facultative)'),
          maxLines: 3,
        ),
      ],
    ),
  );
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog(this.reportId, this.state);
  final String reportId;
  final AppState state;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late final _municipalities = widget.state.municipalities
      .watchMunicipalities();
  String? _selected;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Municipality>>(
    stream: _municipalities,
    builder: (context, snapshot) {
      final list = snapshot.data;
      if (snapshot.hasError || list?.isEmpty == true) {
        return AlertDialog(
          title: const Text('Affecter le signalement'),
          content: Text(
            snapshot.hasError
                ? 'Impossible de charger les municipalités.'
                : 'Créez une municipalité avant d’affecter ce signalement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      }
      if (list == null) {
        return const AlertDialog(
          content: Center(child: CircularProgressIndicator()),
        );
      }
      return DashboardFormDialog(
        title: 'Affecter le signalement',
        submitLabel: 'Affecter',
        onSubmit: () =>
            widget.state.reports.assignReport(widget.reportId, _selected!),
        child: municipalityField(
          key: ValueKey(list.map((item) => item.id).join(',')),
          selected: _selected,
          municipalities: list,
          onChanged: (value) => _selected = value,
        ),
      );
    },
  );
}
