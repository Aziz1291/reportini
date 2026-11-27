import '../../data/models/report.dart';

/// Result of the AI photo recognition, already cleaned and bounded.
class ImageAnalysis {
  const ImageAnalysis({
    required this.category,
    required this.title,
    required this.description,
    required this.confidence,
    required this.isUrbanIssue,
    this.reason,
  });

  /// Tolerant parser: the model output is never trusted as-is.
  factory ImageAnalysis.fromJson(Map<String, dynamic> json) {
    final confidence = switch (json['confidence']) {
      final num value => value > 1 ? value / 100 : value.toDouble(),
      final String value => double.tryParse(value.replaceAll('%', '')) ?? 0,
      _ => 0.0,
    };
    final reason = _clean(json['reason'], 160);
    return ImageAnalysis(
      category: parseCategory(json['category']),
      title: _clean(json['title'], maxTitleLength),
      description: _clean(json['description'], maxDescriptionLength),
      confidence: (confidence > 1 ? confidence / 100 : confidence)
          .clamp(0.0, 1.0)
          .toDouble(),
      isUrbanIssue: switch (json['isUrbanIssue']) {
        final bool value => value,
        final String value => value.toLowerCase() != 'false',
        _ => true,
      },
      reason: reason.isEmpty ? null : reason,
    );
  }

  static const maxTitleLength = 60;
  static const maxDescriptionLength = 250;

  final ReportCategory category;
  final String title;
  final String description;
  final double confidence;
  final bool isUrbanIssue;
  final String? reason;

  int get confidencePercent => (confidence * 100).round();

  /// Accepts an enum id (`roads`) or a French label (`Voirie`, `eclairage`…).
  static ReportCategory parseCategory(Object? raw) {
    final value = _fold(raw?.toString() ?? '');
    for (final category in ReportCategory.values) {
      if (value == _fold(category.name) || value == _fold(category.label)) {
        return category;
      }
    }
    const synonyms = {
      'dechet': ReportCategory.waste,
      'ordure': ReportCategory.waste,
      'poubelle': ReportCategory.waste,
      'route': ReportCategory.roads,
      'chaussee': ReportCategory.roads,
      'trottoir': ReportCategory.roads,
      'nid': ReportCategory.roads,
      'lampadaire': ReportCategory.lighting,
      'eclairage': ReportCategory.lighting,
      'lumiere': ReportCategory.lighting,
      'equipement': ReportCategory.equipment,
      'mobilier': ReportCategory.equipment,
      'banc': ReportCategory.equipment,
    };
    for (final entry in synonyms.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return ReportCategory.other;
  }

  static String _fold(String input) {
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = input.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString();
  }

  static String _clean(Object? raw, int max) {
    final text = (raw?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1).trimRight()}…';
  }
}
