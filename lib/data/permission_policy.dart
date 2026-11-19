import 'models/account.dart';
import 'models/report.dart';
import 'repositories/auth_repository.dart';

class PermissionPolicy {
  const PermissionPolicy();

  bool canManage(Account? actor) =>
      actor?.enabled == true && actor?.role == AccountRole.admin;

  bool canEditName(Account? actor, String userId) =>
      actor?.enabled == true && (actor?.id == userId || canManage(actor));

  bool isCitizen(Account? actor, String citizenId) =>
      actor?.enabled == true &&
      actor?.role == AccountRole.citizen &&
      actor?.id == citizenId;

  bool canViewMunicipalReports(Account? actor) =>
      canManage(actor) ||
      (actor?.enabled == true &&
          actor?.role == AccountRole.agent &&
          actor?.municipalityId != null);

  bool canReadReport(Account? actor, Report report) =>
      isCitizen(actor, report.citizenId) || canChangeStatus(actor, report);

  bool canCreateReport(Account? actor, String citizenId, ReportStatus status) =>
      isCitizen(actor, citizenId) && status == ReportStatus.enAttente;

  bool canChangeStatus(Account? actor, Report report) =>
      canManage(actor) ||
      (canViewMunicipalReports(actor) &&
          actor!.municipalityId == report.municipalityId);

  void require(bool allowed) {
    if (!allowed) {
      throw const RepositoryException('Vous n’avez pas accès à cette action.');
    }
  }
}
