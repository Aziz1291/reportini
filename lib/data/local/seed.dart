import '../models/account.dart';
import '../models/municipality.dart';
import '../models/report.dart';

const demoPassword = 'Reportini2026';

const demoMunicipalities = [
  Municipality('nabeul', 'Nabeul', 36.4561, 10.7376, 7),
  Municipality('hammamet', 'Hammamet', 36.4000, 10.6167, 8),
  Municipality('tunis', 'Tunis', 36.8065, 10.1815, 10),
  Municipality('sousse', 'Sousse', 35.8256, 10.6369, 8),
];

List<Account> demoAccounts(DateTime now) => [
  Account(
    id: 'admin',
    name: 'Administration Reportini',
    email: 'admin@reportini.tn',
    role: AccountRole.admin,
    createdAt: now,
  ),
  Account(
    id: 'agent-nabeul',
    name: 'Agent Nabeul',
    email: 'agent.nabeul@reportini.tn',
    role: AccountRole.agent,
    municipalityId: 'nabeul',
    createdAt: now,
  ),
  Account(
    id: 'agent-hammamet',
    name: 'Agent Hammamet',
    email: 'agent.hammamet@reportini.tn',
    role: AccountRole.agent,
    municipalityId: 'hammamet',
    createdAt: now,
  ),
  Account(
    id: 'citoyen',
    name: 'Claire Dubois',
    email: 'citoyen@reportini.tn',
    role: AccountRole.citizen,
    createdAt: now,
  ),
];

List<Report> demoReports(DateTime now) {
  Report report({
    required int number,
    required int age,
    required ReportCategory category,
    required ReportStatus status,
    required String title,
    required String description,
    required String photo,
    required ReportLocation location,
    String? progress,
    String? resolution,
  }) {
    final created = now.subtract(Duration(days: age, hours: 3));
    final events = [
      ReportEvent(
        ReportStatus.enAttente,
        created,
        'citoyen',
        'Transmis aux agents techniques.',
      ),
      if (progress != null)
        ReportEvent(
          ReportStatus.enCours,
          created.add(const Duration(hours: 4)),
          'agent-nabeul',
          progress,
        ),
      if (resolution != null)
        ReportEvent(
          ReportStatus.traite,
          created.add(const Duration(days: 2)),
          'agent-nabeul',
          resolution,
        ),
    ];
    return Report(
      id: 'demo-$number',
      reference: 'RPT-${created.year}-0000$number',
      citizenId: 'citoyen',
      category: category,
      title: title,
      description: description,
      photo: 'assets/images/$photo.png',
      location: location,
      municipalityId: 'nabeul',
      municipalityName: 'Nabeul',
      status: status,
      history: events,
      createdAt: created,
      updatedAt: events.last.at,
    );
  }

  return [
    report(
      number: 1,
      age: 0,
      category: ReportCategory.roads,
      status: ReportStatus.enAttente,
      title: 'Nid-de-poule dangereux sur chaussée',
      description: 'Nid-de-poule profond sur la voie cyclable, risque de chute pour les vélos et deux-roues.',
      photo: 'pothole',
      location: const ReportLocation(
        36.456,
        10.737,
        '14 Rue de la République, Nabeul',
        accuracy: 5,
      ),
    ),
    report(
      number: 2,
      age: 1,
      category: ReportCategory.waste,
      status: ReportStatus.enCours,
      title: 'Dépôt sauvage de cartons et poubelle débordante',
      description: 'Des cartons bloquent le passage à côté du bac de collecte.',
      photo: 'bin',
      location: const ReportLocation(
        36.451,
        10.736,
        'Place du Marché, Nabeul',
        accuracy: 8,
      ),
      progress: 'Équipe de collecte en cours de tournée.',
    ),
    report(
      number: 3,
      age: 5,
      category: ReportCategory.lighting,
      status: ReportStatus.traite,
      title: 'Lanterne de candélabre cassée',
      description: 'Le lampadaire reste éteint depuis plusieurs soirs.',
      photo: 'lamp',
      location: const ReportLocation(
        36.455,
        10.739,
        'Place de l’Horloge, Nabeul',
        accuracy: 6,
      ),
      progress: 'Intervention transmise à l’équipe électrique.',
      resolution: 'Réparé par l’équipe électrique.',
    ),
  ];
}
