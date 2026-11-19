import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/report.dart';
import 'report_map.dart';
import 'report_photo.dart';
import 'report_widgets.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    this.showCitizen = false,
    this.backPath = '/signalements',
    this.actions,
  });
  final Report report;
  final bool showCitizen;
  final String backPath;
  final Widget? actions;

  void _zoom(BuildContext context) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Photo du constat')),
        body: SafeArea(
          child: InteractiveViewer(
            maxScale: 5,
            child: ReportPhoto(report.photo, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final point = LatLng(report.location.lat, report.location.lng);
    final history = [...report.history]..sort((a, b) => a.at.compareTo(b.at));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(backPath);
            }
          },
        ),
        title: const Text('Détails du signalement'),
      ),
      body: SafeArea(
        child: PageList(
          children: [
            CivicCard(
              color: civicTint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(report.status),
                      Text(
                        'Réf. ${report.reference}',
                        style: text.labelLarge?.copyWith(color: civicBlue),
                      ),
                    ],
                  ),
                  if (history.isNotEmpty && history.last.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      history.last.note,
                      style: text.bodySmall?.copyWith(color: civicMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            CivicCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 205,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ReportPhoto(report.photo),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 10,
                          right: 10,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reportDate(report.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _zoom(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.fullscreen, size: 20),
                                label: const Text('Agrandir'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MetadataLine(
                          categoryIcon(report.category),
                          report.category.label,
                        ),
                        const SizedBox(height: 6),
                        Text(report.title, style: text.headlineSmall),
                        if (showCitizen) ...[
                          const SizedBox(height: 7),
                          MetadataLine(
                            Icons.person_outline,
                            report.citizenName ?? 'Nom du citoyen indisponible',
                          ),
                        ],
                        if (report.description.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            report.description,
                            style: const TextStyle(color: civicMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ReportSection(
                    Icons.location_on_outlined,
                    'Localisation',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 145,
                    child: ReportMap(center: point, point: point),
                  ),
                  const SizedBox(height: 10),
                  MetadataLine(
                    Icons.signpost_outlined,
                    report.location.address,
                  ),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    onPressed: () => openInGps(context, report.location),
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Ouvrir dans le GPS'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReportSection(
                    Icons.account_balance_outlined,
                    'Service municipal en charge',
                  ),
                  const SizedBox(height: 10),
                  MetadataLine(Icons.apartment, report.municipalityName),
                  const SizedBox(height: 7),
                  MetadataLine(
                    Icons.schedule,
                    'Date d’enregistrement · ${reportDate(report.createdAt)}',
                  ),
                ],
              ),
            ),
            if (actions case final controls?) ...[
              const SizedBox(height: 12),
              CivicCard(child: controls),
            ],
            const SizedBox(height: 12),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReportSection(Icons.timeline, 'Suivi d’avancement'),
                  const SizedBox(height: 14),
                  if (history.isEmpty)
                    const Text('Aucune mise à jour pour le moment.'),
                  for (var index = 0; index < history.length; index++)
                    _TimelineEvent(
                      history[index],
                      latest: index == history.length - 1,
                      author: history[index].by == report.citizenId
                          ? report.citizenName
                          : history[index].by,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent(this.event, {required this.latest, this.author});
  final ReportEvent event;
  final bool latest;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: latest ? civicBlue : civicTint,
                foregroundColor: latest ? Colors.white : civicBlue,
                child: Icon(
                  event.status == ReportStatus.enCours
                      ? Icons.sync
                      : Icons.check,
                  size: 15,
                ),
              ),
              if (!latest) Container(width: 1, height: 22, color: civicLine),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: latest ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.status.label, style: text.titleMedium),
                Text(
                  reportDate(event.at),
                  style: text.bodySmall?.copyWith(color: civicMuted),
                ),
                if (author case final name?) Text(name, style: text.bodySmall),
                if (event.note.isNotEmpty) Text(event.note),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
