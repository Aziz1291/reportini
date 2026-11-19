import '../models/report.dart';

abstract interface class ReportRepository {
  Stream<List<Report>> watchReports(String citizenId);
  Future<List<Report>> listReports(String citizenId);
  Future<Report> createReport(String citizenId, ReportDraft draft);
  Stream<List<Report>> watchMunicipalReports();
  Future<void> changeStatus(String id, ReportStatus status, String note);
  Future<void> assignReport(String id, String municipalityId);
}
