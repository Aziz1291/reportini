import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reportini/data/local/local_backend.dart';
import 'package:reportini/data/models/account.dart';
import 'package:reportini/data/models/report.dart';
import 'package:reportini/data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalBackend backend;
  late Directory directory;

  Future<LocalBackend> open() =>
      LocalBackend.open(latency: Duration.zero, photoDirectory: directory.path);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('reportini_test_');
    backend = await open();
  });

  tearDown(() async {
    await backend.close();
    await directory.delete(recursive: true);
  });

  test(
    'registers a citizen, rejects wrong credentials and restores the session',
    () async {
      await backend.register(
        '  Amal Ben Ali  ',
        'AMAL@reportini.tn',
        'Reportini42',
      );
      expect(await backend.restoreSession(), isNull);
      await expectLater(
        backend.signIn('amal@reportini.tn', 'Incorrect123'),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        backend.register('Doublon', 'amal@reportini.tn', 'Reportini42'),
        throwsA(isA<RepositoryException>()),
      );

      final account = await backend.signIn(
        ' amal@reportini.tn ',
        'Reportini42',
      );
      expect(account.name, 'Amal Ben Ali');
      expect(account.role, AccountRole.citizen);
      expect(await backend.listReports(account.id), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('reportini.local.v1')!;
      expect(stored, contains('passwordHash'));
      expect(stored, contains('salt'));
      expect(stored, isNot(contains('Reportini42')));

      final restarted = await open();
      addTearDown(restarted.close);
      expect((await restarted.restoreSession())?.id, account.id);
      expect(
        (await restarted.updateName(account.id, 'Amal Ali')).name,
        'Amal Ali',
      );
      await restarted.signOut();
      expect(await restarted.restoreSession(), isNull);
    },
  );

  test(
    'seeds reports and lists the new report as soon as it is saved',
    () async {
      final citizen = await backend.signIn(
        'citoyen@reportini.tn',
        'Reportini2026',
      );
      final seed = await backend.listReports(citizen.id);
      expect(
        seed.map((report) => report.status).toSet(),
        ReportStatus.values.toSet(),
      );
      expect(await backend.listMunicipalities(), hasLength(4));

      final updates = expectLater(
        backend.watchReports(citizen.id),
        emitsInOrder([hasLength(3), hasLength(4)]),
      );
      const id = 'aa332211-1020-4030-8040-a1b2c3d4e5f6';
      final draft = ReportDraft(
        id: id,
        category: ReportCategory.roads,
        title: 'Chaussée endommagée',
        description: 'Près du carrefour',
        location: const ReportLocation(36.4561, 10.7376, 'Nabeul', accuracy: 5),
        photo: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'constat.jpg',
        ),
        municipality: (await backend.listMunicipalities()).first,
      );
      final report = await backend.createReport(citizen.id, draft);
      await updates;

      expect(report.reference, matches(RegExp(r'^RPT-\d{4}-[A-Z0-9]{5}$')));
      expect(report.municipalityId, 'nabeul');
      expect(report.history.single.status, ReportStatus.enAttente);
      expect(await File.fromUri(Uri.parse(report.photo)).readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect((await backend.listReports(citizen.id)).first.id, id);
      expect(
        (await backend.createReport(citizen.id, draft)).reference,
        report.reference,
      );
      expect(await backend.listReports(citizen.id), hasLength(4));

      final restarted = await open();
      addTearDown(restarted.close);
      expect((await restarted.listReports(citizen.id)).first.id, id);
      await restarted.signOut();
      await restarted.register(
        'Autre compte',
        'autre@reportini.tn',
        'Reportini42',
      );
      final other = await restarted.signIn('autre@reportini.tn', 'Reportini42');
      await expectLater(
        restarted.listReports(citizen.id),
        throwsA(isA<RepositoryException>()),
      );
      expect(await restarted.listReports(other.id), isEmpty);
    },
  );

  test(
    'a photo write failure leaves no report and the same draft can be retried',
    () async {
      final citizen = await backend.signIn(
        'citoyen@reportini.tn',
        'Reportini2026',
      );
      final photo = File('${directory.path}/constat.jpg');
      final draft = ReportDraft(
        id: 'bbaa2211-1020-4030-8040-a1b2c3d4e5f6',
        category: ReportCategory.equipment,
        title: 'Banc cassé',
        description: '',
        location: const ReportLocation(0, 0, '0, 0'),
        photo: XFile(photo.path),
        municipality: null,
      );

      await expectLater(
        backend.createReport(citizen.id, draft),
        throwsA(isA<RepositoryException>()),
      );
      expect(await backend.listReports(citizen.id), hasLength(3));
      await photo.writeAsBytes([1, 2, 3]);
      final report = await backend.createReport(citizen.id, draft);
      expect(report.municipalityId, isNull);
      expect(report.municipalityName, 'Hors zone');
      expect(await backend.listReports(citizen.id), hasLength(4));
    },
  );
}
