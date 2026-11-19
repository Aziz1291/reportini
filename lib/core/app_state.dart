import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/models/report.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/municipality_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/user_repository.dart';
import 'municipality_locator.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.reports,
    required this.municipalities,
    required this.users,
  });

  final AuthRepository auth;
  final ReportRepository reports;
  final MunicipalityRepository municipalities;
  final UserRepository users;
  Account? account;
  List<Report> myReports = const [];
  bool reportsLoading = false;
  bool reportsUnavailable = false;
  StreamSubscription<List<Report>>? _watch;
  bool _disposed = false;

  Future<void> restore() async => _setAccount(await auth.restoreSession());

  Future<void> signIn(String email, String password) async =>
      _setAccount(await auth.signIn(email, password));

  Future<void> signOut() async {
    await auth.signOut();
    _setAccount(null);
  }

  Future<void> updateName(String name) async {
    final current = account!;
    final updated = await users.updateName(current.id, name);
    if (!_disposed && account?.id == current.id) {
      account = updated;
      notifyListeners();
    }
  }

  void _setAccount(Account? value) {
    if (_disposed) return;
    unawaited(_watch?.cancel());
    account = value;
    myReports = const [];
    reportsLoading = value?.role == AccountRole.citizen;
    reportsUnavailable = false;
    if (value != null && reportsLoading) {
      _watch = reports
          .watchReports(value.id)
          .listen(
            (items) {
              if (account?.id != value.id || _disposed) return;
              _setReports(items);
            },
            onError: (Object _) {
              if (account?.id != value.id || _disposed) return;
              reportsLoading = false;
              reportsUnavailable = true;
              notifyListeners();
            },
          );
    }
    notifyListeners();
  }

  void _setReports(List<Report> items) {
    myReports = List.unmodifiable(items);
    reportsLoading = false;
    reportsUnavailable = false;
    notifyListeners();
  }

  Future<void> refreshReports() async {
    final id = account?.id;
    if (id == null) return;
    try {
      final items = await reports.listReports(id);
      if (!_disposed && account?.id == id) _setReports(items);
    } catch (_) {
      if (_disposed || account?.id != id) return;
      reportsLoading = false;
      reportsUnavailable = true;
      notifyListeners();
    }
  }

  Future<Report> submit(ReportDraft draft) async {
    final id = account!.id;
    final available = await municipalities.listMunicipalities();
    final point = draft.location;
    final assigned = const MunicipalityLocator().locate(
      point.lat,
      point.lng,
      available,
    );
    final report = await reports.createReport(
      id,
      ReportDraft(
        id: draft.id,
        category: draft.category,
        title: draft.title,
        description: draft.description,
        location: point,
        photo: draft.photo,
        municipality: assigned,
      ),
    );
    if (!_disposed && account?.id == id) {
      _setReports(
        [report, ...myReports.where((item) => item.id != report.id)]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
    }
    return report;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_watch?.cancel());
    super.dispose();
  }
}
