import '../models/account.dart';
import '../models/municipality.dart';
import '../models/report.dart';

const demoPassword = 'Reportini2026';
const seedVersion = 2;

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

List<Report> demoReports(
  DateTime now, {
  int afterVersion = 0,
  Iterable<Municipality> municipalities = demoMunicipalities,
}) {
  final byId = {
    for (final municipality in municipalities) municipality.id: municipality,
  };

  Report report({
    required int number,
    required int age,
    required ReportCategory category,
    required String title,
    required String description,
    required String photo,
    required ReportLocation location,
    String? municipalityId = 'nabeul',
    String? progress,
    String? resolution,
  }) {
    final municipality = byId[municipalityId];
    final agent = municipality == null
        ? 'Services municipaux'
        : 'Agent ${municipality.name}';
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
          agent,
          progress,
        ),
      if (resolution != null)
        ReportEvent(
          ReportStatus.traite,
          created.add(const Duration(days: 2)),
          agent,
          resolution,
        ),
    ];
    return Report(
      id: 'demo-$number',
      reference: 'RPT-${created.year}-0000$number',
      citizenId: 'citoyen',
      citizenName: 'Claire Dubois',
      category: category,
      title: title,
      description: description,
      photo: 'assets/images/$photo.png',
      location: location,
      municipalityId: municipality?.id,
      municipalityName: municipality?.name ?? 'Hors zone',
      status: events.last.status,
      history: events,
      createdAt: created,
      updatedAt: events.last.at,
    );
  }

  return [
    if (afterVersion < 1) ...[
      report(
        number: 1,
        age: 0,
        category: ReportCategory.roads,
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
        title: 'Dépôt sauvage de cartons et poubelle débordante',
        description:
            'Des cartons bloquent le passage à côté du bac de collecte.',
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
    ],
    if (afterVersion < 2) ...[
      report(
        number: 4,
        age: 1,
        category: ReportCategory.lighting,
        title: 'Lampadaire éteint près du fort de Hammamet',
        description: 'Le trottoir devant l’entrée de la médina reste sombre après la tombée de la nuit.',
        photo: 'lamp',
        location: const ReportLocation(
          36.3938,
          10.6149,
          'Rue de la Kasbah, Hammamet',
          accuracy: 8,
        ),
        municipalityId: 'hammamet',
        progress: 'Le service éclairage a planifié un contrôle du luminaire.',
      ),
      report(
        number: 5,
        age: 3,
        category: ReportCategory.waste,
        title: 'Bac à ordures débordant près du marché',
        description: 'Des sacs s’accumulent autour du bac et empiètent sur le passage piéton.',
        photo: 'bin',
        location: const ReportLocation(
          36.4009,
          10.6148,
          'Marché municipal, Hammamet',
          accuracy: 6,
        ),
        municipalityId: 'hammamet',
      ),
      report(
        number: 6,
        age: 6,
        category: ReportCategory.roads,
        title: 'Nid-de-poule sur la voie près de Bab Bhar',
        description: 'Le revêtement est creusé au bord de la chaussée, à quelques mètres du passage piéton.',
        photo: 'pothole',
        location: const ReportLocation(
          36.7985,
          10.1758,
          'Place de la Victoire, Tunis',
          accuracy: 7,
        ),
        municipalityId: 'tunis',
        progress: 'Une équipe de voirie a sécurisé le passage.',
        resolution: 'Le trou a été comblé et la chaussée rouverte.',
      ),
      report(
        number: 7,
        age: 0,
        category: ReportCategory.waste,
        title: 'Déchets au pied des remparts de Kairouan',
        description: 'Des sacs et des cartons occupent une partie du trottoir près de Bab el-Jalladin.',
        photo: 'bin',
        location: const ReportLocation(
          35.6781,
          10.0963,
          'Près de Bab el-Jalladin, Kairouan',
          accuracy: 9,
        ),
        municipalityId: null,
      ),
    ],
  ];
}
