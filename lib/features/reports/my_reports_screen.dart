import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/report.dart';
import 'report_widgets.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  ReportStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reports = state.myReports;
    final filtered = reports.where(
      (report) => _filter == null || _filter == report.status,
    );
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: state.refreshReports,
            child: PageList(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mes signalements',
                        style: text.headlineMedium,
                      ),
                    ),
                    Text(
                      '${reports.length} total',
                      style: text.labelMedium?.copyWith(color: civicMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Suivez l’avancement des interventions municipales en temps réel.',
                  style: TextStyle(color: civicMuted),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final status in <ReportStatus?>[
                        null,
                        ...ReportStatus.values,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(
                              '${status?.label ?? 'Tous'} · ${reports.where((r) => status == null || r.status == status).length}',
                            ),
                            selected: _filter == status,
                            selectedColor: civicBlue,
                            labelStyle: TextStyle(
                              color: _filter == status
                                  ? Colors.white
                                  : civicInk,
                            ),
                            checkmarkColor: Colors.white,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = status),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (state.reportsLoading)
                  const LinearProgressIndicator()
                else if (state.reportsUnavailable)
                  CivicCard(
                    child: Column(
                      children: [
                        const Text('Impossible d’actualiser les signalements.'),
                        TextButton(
                          onPressed: state.refreshReports,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                else if (filtered.isEmpty)
                  CivicCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          color: civicBlue,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          reports.isEmpty
                              ? 'Vous n’avez pas encore de signalement.'
                              : 'Aucun signalement avec ce statut.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final report in filtered) ...[
                  ReportCard(report),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 618),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/nouveau'),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau signalement'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
