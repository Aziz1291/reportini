import 'package:image_picker/image_picker.dart';

import 'municipality.dart';

enum ReportCategory {
  waste('Déchets'),
  roads('Voirie'),
  lighting('Éclairage'),
  equipment('Équipement'),
  other('Autre anomalie urbaine');

  const ReportCategory(this.label);
  final String label;
}

enum ReportStatus {
  enAttente('en_attente', 'En attente', 'Signalement envoyé'),
  enCours('en_cours', 'En cours', 'Prise en charge'),
  traite('traite', 'Traité', 'Problème résolu');

  const ReportStatus(this.code, this.label, this.stage);
  final String code;
  final String label;
  final String stage;

  static ReportStatus fromCode(String code) =>
      values.firstWhere((status) => status.code == code);
}

class ReportLocation {
  const ReportLocation(this.lat, this.lng, this.address, {this.accuracy});
  final double lat;
  final double lng;
  final String address;
  final double? accuracy;
}

class ReportEvent {
  const ReportEvent(this.status, this.at, this.by, this.note);

  factory ReportEvent.fromJson(Map<String, dynamic> json) => ReportEvent(
    ReportStatus.fromCode(json['status'] as String),
    DateTime.parse(json['at'] as String),
    json['by'] as String,
    json['note'] as String? ?? '',
  );

  final ReportStatus status;
  final DateTime at;
  final String by;
  final String note;

  Map<String, dynamic> toJson() => {
    'status': status.code,
    'at': at.toUtc().toIso8601String(),
    'by': by,
    'note': note,
  };
}

class ReportDraft {
  const ReportDraft({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    required this.photo,
    this.municipality,
  });

  final String id;
  final ReportCategory category;
  final String title;
  final String description;
  final ReportLocation location;
  final XFile photo;
  final Municipality? municipality;

  ReportDraft withMunicipality(Municipality? assigned) => ReportDraft(
    id: id,
    category: category,
    title: title,
    description: description,
    location: location,
    photo: photo,
    municipality: assigned,
  );
}

class Report {
  const Report({
    required this.id,
    required this.reference,
    required this.citizenId,
    required this.category,
    required this.title,
    required this.description,
    required this.photo,
    required this.location,
    required this.municipalityId,
    required this.municipalityName,
    required this.status,
    required this.history,
    required this.createdAt,
    required this.updatedAt,
    this.citizenName,
  });

  factory Report.submitted(
    ReportDraft draft,
    String citizenId,
    String photo, {
    String? citizenName,
  }) {
    final now = DateTime.now();
    final referenceSeed = int.parse(draft.id.substring(0, 8), radix: 16);
    final suffix = (referenceSeed % 60466176)
        .toRadixString(36)
        .padLeft(5, '0')
        .toUpperCase();
    return Report(
      id: draft.id,
      reference: 'RPT-${now.year}-$suffix',
      citizenId: citizenId,
      citizenName: citizenName,
      category: draft.category,
      title: draft.title,
      description: draft.description,
      photo: photo,
      location: draft.location,
      municipalityId: draft.municipality?.id,
      municipalityName: draft.municipality?.name ?? 'Hors zone',
      status: ReportStatus.enAttente,
      history: [
        ReportEvent(
          ReportStatus.enAttente,
          now,
          citizenId,
          'Signalement enregistré. En attente de prise en charge.',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Report.fromJson(String id, Map<String, dynamic> json) => Report(
    id: id,
    reference: json['reference'] as String,
    citizenId: json['citizenId'] as String,
    citizenName: json['citizenName'] as String?,
    category: ReportCategory.values.byName(json['category'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    photo: (json['photoUrl'] ?? json['photo']) as String,
    location: ReportLocation(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
      json['address'] as String,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
    ),
    municipalityId: json['municipalityId'] as String?,
    municipalityName: json['municipalityName'] as String,
    status: ReportStatus.fromCode(json['status'] as String),
    history: List.unmodifiable(
      (json['history'] as List).map(
        (event) =>
            ReportEvent.fromJson(Map<String, dynamic>.from(event as Map)),
      ),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String reference;
  final String citizenId;
  final String? citizenName;
  final ReportCategory category;
  final String title;
  final String description;
  final String photo;
  final ReportLocation location;
  final String? municipalityId;
  final String municipalityName;
  final ReportStatus status;
  final List<ReportEvent> history;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'reference': reference,
    'citizenId': citizenId,
    'citizenName': citizenName,
    'category': category.name,
    'title': title,
    'description': description,
    'photoUrl': photo,
    'lat': location.lat,
    'lng': location.lng,
    'address': location.address,
    'accuracy': location.accuracy,
    'municipalityId': municipalityId,
    'municipalityName': municipalityName,
    'status': status.code,
    'history': history.map((event) => event.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
