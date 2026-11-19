import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/report.dart';
import 'report_photo.dart';
import 'report_widgets.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/accueil')),
        title: const Text('Confirmation du signalement'),
      ),
      body: SafeArea(
        child: PageList(
          children: [
            const SizedBox(height: 14),
            const Center(
              child: CircleAvatar(
                radius: 39,
                backgroundColor: Color(0xFFD1FAE5),
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: Color(0xFF005F40),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.check_circle_outline, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Signalement envoyé avec succès !',
              textAlign: TextAlign.center,
              style: text.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Merci pour votre contribution civique. Vous pouvez suivre l’avancement depuis vos signalements.',
              textAlign: TextAlign.center,
              style: TextStyle(color: civicMuted),
            ),
            const SizedBox(height: 20),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: civicCanvas,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Référence du dossier',
                                style: text.bodySmall,
                              ),
                              SelectableText(
                                report.reference,
                                style: text.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: report.reference),
                              );
                              if (context.mounted) {
                                showMessage(context, 'Référence copiée.');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showMessage(
                                  context,
                                  'Sélectionnez la référence pour la copier.',
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copier'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.square(
                        dimension: 76,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ReportPhoto(report.photo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.category.label,
                              style: text.labelMedium?.copyWith(
                                color: civicBlue,
                              ),
                            ),
                            Text(report.title, style: text.titleMedium),
                            const SizedBox(height: 5),
                            MetadataLine(
                              Icons.location_on_outlined,
                              report.location.address,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  ReportSection(Icons.flag_outlined, 'État actuel'),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      report.status,
                      label: report.status == ReportStatus.enAttente
                          ? 'En attente de prise en charge'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MetadataLine(Icons.apartment, report.municipalityName),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/signalements/${report.id}'),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Voir mon signalement'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/accueil'),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Retour à l’accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
