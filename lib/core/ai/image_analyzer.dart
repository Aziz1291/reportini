import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/models/report.dart';
import 'image_analysis.dart';

/// Error shown to the user (already in French). Never contains the API key.
class AiException implements Exception {
  const AiException(this.message);
  final String message;

  /// [body] lets us spot invalid keys that some providers (Gemini) report
  /// with HTTP 400 instead of 401.
  factory AiException.fromStatus(int status, [String body = '']) =>
      switch (status) {
        400
            when RegExp(
              r'API[ _]?key|API_KEY_INVALID|api_key',
              caseSensitive: false,
            ).hasMatch(body) =>
          const AiException('Clé API invalide ou non autorisée.'),
        400 => const AiException(
          'Requête refusée par le service IA. Vérifiez le modèle choisi.',
        ),
        401 || 403 => const AiException('Clé API invalide ou non autorisée.'),
        404 => const AiException(
          'Modèle introuvable. Vérifiez le nom du modèle dans l’Assistant IA.',
        ),
        429 => const AiException(
          'Quota du service IA dépassé. Réessayez dans quelques instants.',
        ),
        _ when status >= 500 => const AiException(
          'Le service IA est momentanément indisponible.',
        ),
        _ => AiException('Erreur du service IA (code $status).'),
      };

  @override
  String toString() => message;
}

abstract class ImageAnalyzer {
  bool get isEnabled;
  Future<ImageAnalysis> analyze(Uint8List bytes, {String mimeType});
}

class DisabledImageAnalyzer implements ImageAnalyzer {
  const DisabledImageAnalyzer();

  @override
  bool get isEnabled => false;

  @override
  Future<ImageAnalysis> analyze(Uint8List bytes, {String mimeType = ''}) =>
      throw const AiException('L’assistant IA n’est pas configuré.');
}

/// Shared French instructions for every provider.
final aiPrompt =
    '''
Tu es l'assistant de Reportini, une application municipale où les citoyens signalent des problèmes dans l'espace public.
Analyse la photo et réponds UNIQUEMENT avec un objet JSON :
{"category": "...", "title": "...", "description": "...", "confidence": 0.0, "isUrbanIssue": true, "reason": "..."}

Catégories autorisées (utilise exactement l'identifiant) :
${ReportCategory.values.map((c) => '- ${c.name} : ${c.label}${_examples[c]}').join('\n')}

Règles :
- title : titre court en français (60 caractères maximum), ex. "Nid-de-poule sur la chaussée".
- description : 1 à 2 phrases en français (250 caractères maximum) décrivant ce qu'on voit et le risque éventuel.
- confidence : nombre entre 0 et 1.
- isUrbanIssue : false si la photo ne montre pas un problème de l'espace public (selfie, intérieur, capture d'écran, objet sans rapport…), sinon true.
- reason : courte justification en français.
''';

const _examples = {
  ReportCategory.waste: ' (dépôt sauvage, poubelle débordante, ordures)',
  ReportCategory.roads:
      ' (nid-de-poule, chaussée ou trottoir dégradé, signalisation au sol)',
  ReportCategory.lighting: ' (lampadaire cassé, éteint ou endommagé)',
  ReportCategory.equipment:
      ' (banc, aire de jeux, fontaine, mobilier urbain abîmé)',
  ReportCategory.other: ' (tout autre problème urbain)',
};

const _timeout = Duration(seconds: 30);

abstract class _HttpImageAnalyzer implements ImageAnalyzer {
  _HttpImageAnalyzer({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  bool get isEnabled => true;

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('Délai dépassé : le service IA ne répond pas.');
    } on http.ClientException {
      // package:http wraps socket/network failures in ClientException.
      throw const AiException('Pas de connexion Internet.');
    }
    if (response.statusCode != 200) {
      throw AiException.fromStatus(response.statusCode, response.body);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw const AiException('Réponse du service IA illisible.');
    }
  }
}

/// Parses the JSON object returned by a model, tolerating ```json fences
/// and text around the object.
ImageAnalysis parseAnalysisText(String text) {
  var cleaned = text.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(cleaned);
  if (fence != null) cleaned = fence.group(1)!.trim();
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const AiException('Réponse du service IA illisible.');
  }
  try {
    final json = jsonDecode(cleaned.substring(start, end + 1));
    return ImageAnalysis.fromJson(Map<String, dynamic>.from(json as Map));
  } catch (_) {
    throw const AiException('Réponse du service IA illisible.');
  }
}

/// Google Gemini (recommended): free tier, native image understanding and
/// schema-constrained JSON output.
class GeminiImageAnalyzer extends _HttpImageAnalyzer {
  GeminiImageAnalyzer({required super.apiKey, String? model, super.client})
    : super(model: (model == null || model.isEmpty) ? defaultModel : model);

  static const defaultModel = 'gemini-flash-lite-latest';

  @override
  Future<ImageAnalysis> analyze(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final json = await _post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      ),
      {'x-goog-api-key': apiKey},
      {
        'contents': [
          {
            'parts': [
              {'text': aiPrompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(bytes),
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'category': {
                'type': 'STRING',
                'enum': [for (final c in ReportCategory.values) c.name],
              },
              'title': {'type': 'STRING'},
              'description': {'type': 'STRING'},
              'confidence': {'type': 'NUMBER'},
              'isUrbanIssue': {'type': 'BOOLEAN'},
              'reason': {'type': 'STRING'},
            },
            'required': [
              'category',
              'title',
              'description',
              'confidence',
              'isUrbanIssue',
            ],
          },
        },
      },
    );
    try {
      final candidates = json['candidates'] as List;
      final parts =
          ((candidates.first as Map)['content'] as Map)['parts'] as List;
      final text = parts
          .map((part) => (part as Map)['text'] as String? ?? '')
          .join();
      return parseAnalysisText(text);
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException('Le service IA n’a pas pu analyser cette photo.');
    }
  }
}

/// Any OpenAI-compatible chat completions API: xAI Grok, OpenAI…
class OpenAiCompatibleImageAnalyzer extends _HttpImageAnalyzer {
  OpenAiCompatibleImageAnalyzer({
    required super.apiKey,
    required super.model,
    required this.baseUrl,
    super.client,
  });

  final String baseUrl;

  @override
  Future<ImageAnalysis> analyze(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final json = await _post(
      Uri.parse('$root/chat/completions'),
      {'Authorization': 'Bearer $apiKey'},
      {
        'model': model,
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': aiPrompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,${base64Encode(bytes)}',
                },
              },
            ],
          },
        ],
      },
    );
    try {
      final choices = json['choices'] as List;
      final message = (choices.first as Map)['message'] as Map;
      return parseAnalysisText(message['content'] as String);
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException('Le service IA n’a pas pu analyser cette photo.');
    }
  }
}

/// Guesses the image type from its first bytes (JPEG, PNG, WebP).
String detectMimeType(Uint8List bytes) {
  if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) {
    return 'image/png';
  }
  if (bytes.length > 11 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
