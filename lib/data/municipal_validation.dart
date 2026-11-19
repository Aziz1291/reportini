import '../core/validators.dart';
import 'models/municipality.dart';
import 'models/report.dart';
import 'repositories/auth_repository.dart';

String municipalityNameKey(String name) => name.trim().toLowerCase();

void validateMunicipality(Municipality input, Iterable<Municipality> existing) {
  final error =
      requiredText(input.name, 'Saisissez le nom de la municipalité.') ??
      validateCoordinate(input.centerLat, 90) ??
      validateCoordinate(input.centerLng, 180) ??
      validateRadius(input.radiusKm);
  if (error != null) throw RepositoryException(error);
  if (existing.any(
    (item) =>
        item.id != input.id &&
        municipalityNameKey(item.name) == municipalityNameKey(input.name),
  )) {
    throw const RepositoryException('Une municipalité porte déjà ce nom.');
  }
}

void validateAgentCredentials(String name, String email, String password) {
  final error =
      requiredText(name, 'Saisissez le nom complet.') ??
      validateEmail(email) ??
      validatePassword(password);
  if (error != null) throw RepositoryException(error);
}

ReportEvent statusEvent(
  Report report,
  ReportStatus status,
  String author,
  String note,
) {
  if (report.status == status) {
    throw const RepositoryException('Ce signalement a déjà ce statut.');
  }
  final now = DateTime.now();
  final at = now.isAfter(report.updatedAt)
      ? now
      : report.updatedAt.add(const Duration(milliseconds: 1));
  return ReportEvent(status, at, author, note.trim());
}
