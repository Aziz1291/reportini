import '../../data/models/report.dart';
import 'image_analysis.dart';

/// Form values after merging an AI suggestion.
typedef SuggestedFields = ({
  ReportCategory? category,
  String title,
  String description,
});

/// Merges an AI suggestion into the report form.
///
/// Without [force], the suggestion only fills what the citizen left empty:
/// a category the user picked, or text the user typed, is never overwritten.
/// [force] ("Appliquer") replaces everything with the suggestion.
SuggestedFields mergeSuggestion({
  required ImageAnalysis analysis,
  required ReportCategory? category,
  required bool categoryChosenByUser,
  required String title,
  required String description,
  bool force = false,
}) => (
  category: force || !categoryChosenByUser || category == null
      ? analysis.category
      : category,
  title: force || title.trim().isEmpty ? analysis.title : title,
  description: force || description.trim().isEmpty
      ? analysis.description
      : description,
);
