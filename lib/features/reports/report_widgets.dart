import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/report.dart';
import 'report_photo.dart';

IconData categoryIcon(ReportCategory category) => switch (category) {
  ReportCategory.waste => Icons.delete_outline,
  ReportCategory.roads => Icons.traffic_outlined,
  ReportCategory.lighting => Icons.lightbulb_outline,
  ReportCategory.equipment => Icons.chair_outlined,
  ReportCategory.other => Icons.construction_outlined,
};

String reportDate(DateTime date) =>
    DateFormat("d MMM yyyy 'à' HH:mm", 'fr').format(date.toLocal());

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.label});
  final ReportStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (ink, fill) = switch (status) {
      ReportStatus.enAttente => (
        const Color(0xFF92400E),
        const Color(0xFFFEF3C7),
      ),
      ReportStatus.enCours => (
        const Color(0xFF1D4ED8),
        const Color(0xFFEFF6FF),
      ),
      ReportStatus.traite => (const Color(0xFF047857), const Color(0xFFECFDF5)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == ReportStatus.traite ? Icons.check : Icons.circle,
              size: 8,
              color: ink,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label ?? status.label,
                style: TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetadataLine extends StatelessWidget {
  const MetadataLine(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: civicMuted, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: civicMuted),
        ),
      ),
    ],
  );
}

class ReportSection extends StatelessWidget {
  const ReportSection(this.icon, this.title, {super.key, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: civicBlue, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ?trailing,
    ],
  );
}

class ReportCard extends StatelessWidget {
  const ReportCard(
    this.report, {
    super.key,
    this.recent = false,
    this.onOpen,
    this.municipal = false,
    this.municipalityLabel,
  });
  final Report report;
  final bool recent;
  final VoidCallback? onOpen;
  final bool municipal;
  final String? municipalityLabel;

  void _open(BuildContext context) {
    if (onOpen case final open?) {
      open();
    } else {
      context.push('/signalements/${report.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CivicCard(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!recent) ...[
            Row(
              children: [
                Expanded(
                  child: MetadataLine(
                    categoryIcon(report.category),
                    report.category.label,
                  ),
                ),
                const SizedBox(width: 6),
                StatusBadge(report.status),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: ReportPhoto(report.photo),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recent) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            report.category.label,
                            style: text.labelMedium?.copyWith(color: civicBlue),
                          ),
                          StatusBadge(report.status),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    MetadataLine(
                      Icons.location_on_outlined,
                      report.location.address,
                    ),
                    if (municipal) ...[
                      const SizedBox(height: 4),
                      MetadataLine(Icons.tag, report.reference),
                      if (report.municipalityId == null)
                        const MetadataLine(Icons.apartment, 'Hors zone')
                      else if (municipalityLabel case final label?)
                        MetadataLine(Icons.apartment, label),
                    ],
                    if (!recent) ...[
                      const SizedBox(height: 4),
                      MetadataLine(
                        Icons.schedule,
                        reportDate(report.createdAt),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (recent)
            Row(
              children: [
                Expanded(
                  child: MetadataLine(
                    Icons.schedule,
                    reportDate(report.createdAt),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _open(context),
                  icon: const Icon(Icons.arrow_forward, size: 15),
                  iconAlignment: IconAlignment.end,
                  label: const Text('Détails'),
                ),
              ],
            )
          else ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: civicCanvas,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: MetadataLine(
                        Icons.update,
                        report.history.isEmpty ||
                                report.history.last.note.isEmpty
                            ? report.status.stage
                            : report.history.last.note,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: civicMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
