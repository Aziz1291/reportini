import '../models/report.dart';

abstract interface class ReportRepository {
  Stream<List<Report>> watchReports(String citizenId);
  Future<List<Report>> listReports(String citizenId);
  Future<Report> createReport(String citizenId, ReportDraft draft);
}
