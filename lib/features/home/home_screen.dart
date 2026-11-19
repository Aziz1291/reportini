import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/report.dart';
import '../reports/report_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final account = state.account;
    final text = Theme.of(context).textTheme;
    final resolved = state.myReports
        .where((report) => report.status == ReportStatus.traite)
        .length;
    return PageList(
      children: [
        Text(
          'Bonjour ${account?.firstName ?? ''} 👋',
          style: text.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Une dégradation dans votre quartier ? Signalez-la en moins d’une minute aux services municipaux.',
          style: TextStyle(color: civicMuted),
        ),
        const SizedBox(height: 18),
        _ReportAction(onTap: () => context.push('/nouveau')),
        const SizedBox(height: 16),
        CivicCard(
          color: const Color(0xFFECFDF5),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFA7F3D0),
                foregroundColor: Color(0xFF00452D),
                child: Icon(Icons.task_alt),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resolved == 1
                      ? '1 signalement résolu'
                      : '$resolved signalements résolus',
                  style: text.titleMedium?.copyWith(
                    color: const Color(0xFF00452D),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Expanded(
              child: Text('Mes derniers signalements', style: text.titleLarge),
            ),
            TextButton.icon(
              onPressed: () => context.go('/signalements'),
              icon: const Icon(Icons.chevron_right, size: 18),
              iconAlignment: IconAlignment.end,
              label: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (state.reportsLoading)
          const LinearProgressIndicator()
        else if (state.reportsUnavailable && state.myReports.isEmpty)
          OutlinedButton(
            onPressed: state.refreshReports,
            child: const Text('Réessayer le chargement'),
          )
        else if (state.myReports.isEmpty)
          const CivicCard(
            child: Text('Vos derniers signalements apparaîtront ici.'),
          ),
        for (final report in state.myReports.take(3)) ...[
          ReportCard(report, recent: true),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ReportAction extends StatelessWidget {
  const _ReportAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    color: civicBlue,
    child: Ink(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [civicBlue, Color(0xFF1E50A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0x33FFFFFF),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.photo_camera_outlined, size: 22),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 21),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                'Signaler un problème',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Photo, localisation automatique et transmission directe',
                style: TextStyle(color: Color(0xFFE0EAFF)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
