import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/models/report.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/municipality_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/user_repository.dart';

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
  List<Report> municipalReports = const [];
  StreamSubscription<List<Report>>? _watch;
  StreamSubscription<Account?>? _profileWatch;
  int _reportScope = 0;
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
    unawaited(_profileWatch?.cancel());
    account = value;
    _startReportWatch();
    if (value != null) {
      _profileWatch = users
          .watchOwnAccount(value.id)
          .listen(
            (profile) {
              if (_disposed || account?.id != value.id) return;
              if (profile?.enabled != true) {
                _setAccount(null);
                return;
              }
              final current = account!;
              final updated = profile!;
              account = updated;
              if (current.role != updated.role ||
                  current.municipalityId != updated.municipalityId) {
                _startReportWatch();
              } else if (current.name != updated.name ||
                  current.email != updated.email) {
                notifyListeners();
              }
            },
            onError: (Object _) {
              // Repository and server rules continue to enforce the stored role.
            },
          );
    }
  }

  void _startReportWatch() {
    unawaited(_watch?.cancel());
    final scope = ++_reportScope;
    final current = account;
    myReports = const [];
    municipalReports = const [];
    reportsLoading = current != null;
    reportsUnavailable = false;
    if (current != null) {
      final citizen = current.role == AccountRole.citizen;
      final stream = citizen
          ? reports.watchReports(current.id)
          : reports.watchMunicipalReports();
      _watch = stream.listen(
        (items) {
          if (_disposed || scope != _reportScope) return;
          if (citizen) {
            _setReports(items);
          } else {
            municipalReports = List.unmodifiable(items);
            reportsLoading = false;
            reportsUnavailable = false;
            notifyListeners();
          }
        },
        onError: (Object _) {
          if (_disposed || scope != _reportScope) return;
          if (!citizen) municipalReports = const [];
          reportsLoading = false;
          reportsUnavailable = true;
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  void retryMunicipalReports() {
    if (account != null && account!.role != AccountRole.citizen) {
      _startReportWatch();
    }
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
    final report = await reports.createReport(id, draft);
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
    unawaited(_profileWatch?.cancel());
    super.dispose();
  }
}
