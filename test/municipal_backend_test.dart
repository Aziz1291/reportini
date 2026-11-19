import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reportini/data/local/local_backend.dart';
import 'package:reportini/data/models/municipality.dart';
import 'package:reportini/data/models/report.dart';
import 'package:reportini/data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalBackend backend;
  late Directory directory;
  const password = 'Reportini2026';
  final forbidden = throwsA(isA<RepositoryException>());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('reportini_municipal_');
    backend = await LocalBackend.open(
      latency: Duration.zero,
      photoDirectory: directory.path,
    );
  });
  tearDown(() async {
    await backend.close();
    await directory.delete(recursive: true);
  });

  test(
    'municipalities validate values and protect referenced records',
    () async {
      await backend.signIn('admin@reportini.tn', password);
      for (final invalid in [
        const Municipality('', '  ', 0, 0, 1),
        const Municipality('', ' nabeul ', 0, 0, 1),
        const Municipality('', 'Test', 91, 0, 1),
        const Municipality('', 'Test', 0, -181, 1),
        const Municipality('', 'Test', 0, 0, 0),
        const Municipality('', 'Test', 0, 0, double.infinity),
      ]) {
        await expectLater(backend.saveMunicipality(invalid), forbidden);
      }
      final created = await backend.saveMunicipality(
        const Municipality('', ' Test ', -90, 180, 2),
      );
      expect(created.name, 'Test');
      final edited = await backend.saveMunicipality(
        Municipality(created.id, 'Test modifié', 0, 0, 3),
      );
      expect(edited.radiusKm, 3);
      expect(
        (await backend.listMunicipalities()).map((item) => item.name),
        contains('Test modifié'),
      );
      await expectLater(backend.deleteMunicipality('nabeul'), forbidden);
      await expectLater(backend.deleteMunicipality('hammamet'), forbidden);
      await backend.deleteMunicipality(created.id);
      expect(
        (await backend.listMunicipalities()).map((item) => item.id),
        isNot(contains(created.id)),
      );
    },
  );

  test(
    'agent creation preserves the admin session and supports disable',
    () async {
      final admin = await backend.signIn('admin@reportini.tn', password);
      await expectLater(
        backend.createAgent('Samia', 'samia@reportini.tn', 'court', 'tunis'),
        forbidden,
      );
      final agent = await backend.createAgent(
        'Samia',
        ' SAMIA@reportini.tn ',
        password,
        'tunis',
      );
      expect((await backend.restoreSession())?.id, admin.id);
      expect(agent.email, 'samia@reportini.tn');
      await backend.updateAgent(agent.id, municipalityId: 'sousse');
      await backend.setAgentEnabled(agent.id, false);
      await backend.signOut();
      await expectLater(
        backend.signIn(agent.email, password),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.message,
            'message',
            contains('désactivé'),
          ),
        ),
      );
      expect(await backend.restoreSession(), isNull);
      await backend.signIn('admin@reportini.tn', password);
      await backend.setAgentEnabled(agent.id, true);
      await backend.signOut();
      expect(
        (await backend.signIn(agent.email, password)).municipalityId,
        'sousse',
      );
    },
  );

  test(
    'scope and status updates are enforced and the citizen sees history',
    () async {
      await backend.signIn('agent.hammamet@reportini.tn', password);
      expect(
        (await backend.watchMunicipalReports().first).map(
          (report) => report.id,
        ),
        ['demo-4', 'demo-5'],
      );
      await expectLater(
        backend.changeStatus('demo-1', ReportStatus.traite, ''),
        forbidden,
      );
      await expectLater(backend.listReports('citoyen'), forbidden);
      await backend.signIn('agent.nabeul@reportini.tn', password);
      final reports = await backend.watchMunicipalReports().first;
      expect(reports.map((report) => report.id), [
        'demo-1',
        'demo-2',
        'demo-3',
      ]);
      final changed = expectLater(
        backend.watchMunicipalReports(),
        emitsInOrder([
          predicate<List<Report>>(
            (items) => items.first.status == ReportStatus.enAttente,
          ),
          predicate<List<Report>>(
            (items) => items.first.status == ReportStatus.traite,
          ),
        ]),
      );
      await backend.changeStatus('demo-1', ReportStatus.traite, '  Réparé  ');
      await changed;
      await expectLater(
        backend.changeStatus('demo-1', ReportStatus.traite, ''),
        forbidden,
      );
      final citizen = await backend.signIn('citoyen@reportini.tn', password);
      final updated = (await backend.watchReports(citizen.id).first)
          .singleWhere((report) => report.id == 'demo-1');
      expect(updated.history, hasLength(2));
      expect(updated.history.last.by, 'Agent Nabeul');
      expect(updated.history.last.note, 'Réparé');
      expect(updated.history.last.status, ReportStatus.traite);
      expect(updated.updatedAt.isAfter(reports.first.updatedAt), isTrue);
      expect(updated.updatedAt, updated.history.last.at);
      await expectLater(backend.watchMunicipalReports().first, forbidden);
    },
  );

  test(
    'new coverage routes reports and only admin can assign Hors zone',
    () async {
      ReportDraft draft(String id, double lat) => ReportDraft(
        id: id,
        category: ReportCategory.roads,
        title: 'Route abîmée',
        description: '',
        location: ReportLocation(lat, 0, 'Rue du test'),
        photo: XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'test.jpg'),
        municipality: const Municipality('obsolete', 'Ancienne zone', 1, 0, 5),
      );

      await backend.signIn('admin@reportini.tn', password);
      final municipality = await backend.saveMunicipality(
        const Municipality('', 'Nouvelle commune', 0, 0, 5),
      );
      final citizen = await backend.signIn('citoyen@reportini.tn', password);
      final covered = await backend.createReport(
        citizen.id,
        draft('abcdef12-covered', 0),
      );
      final outside = await backend.createReport(
        citizen.id,
        draft('abcdef34-outside', 1),
      );
      expect(covered.municipalityId, municipality.id);
      expect(outside.municipalityId, isNull);
      expect(outside.municipalityName, 'Hors zone');
      await expectLater(
        backend.assignReport(outside.id, municipality.id),
        forbidden,
      );
      await backend.signIn('admin@reportini.tn', password);
      await backend.assignReport(outside.id, municipality.id);
      await expectLater(backend.deleteMunicipality(municipality.id), forbidden);
      final reports = await backend.watchMunicipalReports().first;
      final assigned = reports.singleWhere((item) => item.id == outside.id);
      expect(assigned.municipalityName, municipality.name);
      expect(assigned.status, ReportStatus.enAttente);
    },
  );
}
