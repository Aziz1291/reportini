import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:reportini/core/ai/ai_keys.dart';
import 'package:reportini/core/ai/ai_service.dart';
import 'package:reportini/core/ai/image_analysis.dart';
import 'package:reportini/core/ai/image_analyzer.dart';
import 'package:reportini/core/ai/suggestion.dart';
import 'package:reportini/data/models/report.dart';
import 'package:reportini/features/ai/ai_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _utf8Response(String body, int status) =>
    http.Response.bytes(utf8.encode(body), status);

final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

const _validJson = {
  'category': 'roads',
  'title': 'Nid-de-poule sur la chaussée',
  'description': 'Un trou profond au milieu de la voie.',
  'confidence': 0.91,
  'isUrbanIssue': true,
  'reason': 'Chaussée dégradée visible',
};

// Independent of the key currently written in lib/core/ai/ai_keys.dart.
const _placeholderSettings = AiSettings(
  enabled: true,
  provider: AiProvider.gemini,
  apiKey: kAiApiKeyPlaceholder,
  model: '',
  baseUrl: '',
);

void main() {
  group('ImageAnalysis.fromJson', () {
    test('parses a well-formed answer', () {
      final result = ImageAnalysis.fromJson(_validJson);
      expect(result.category, ReportCategory.roads);
      expect(result.confidencePercent, 91);
      expect(result.isUrbanIssue, isTrue);
    });

    test('accepts French labels, accents and synonyms', () {
      expect(ImageAnalysis.parseCategory('Éclairage'), ReportCategory.lighting);
      expect(ImageAnalysis.parseCategory('DECHETS'), ReportCategory.waste);
      expect(
        ImageAnalysis.parseCategory('lampadaire'),
        ReportCategory.lighting,
      );
      expect(ImageAnalysis.parseCategory('banane'), ReportCategory.other);
      expect(ImageAnalysis.parseCategory(null), ReportCategory.other);
    });

    test('clamps confidence and truncates long texts', () {
      final result = ImageAnalysis.fromJson({
        'category': 'waste',
        'title': 'T' * 200,
        'description': 'D' * 600,
        'confidence': 87,
        'isUrbanIssue': 'false',
      });
      expect(result.confidence, closeTo(.87, .001));
      expect(result.title.length, ImageAnalysis.maxTitleLength);
      expect(result.description.length, ImageAnalysis.maxDescriptionLength);
      expect(result.isUrbanIssue, isFalse);
      expect(ImageAnalysis.fromJson({'confidence': 5.0}).confidence, .05);
      expect(ImageAnalysis.fromJson({'confidence': -2}).confidence, 0);
    });
  });

  group('GeminiImageAnalyzer', () {
    test('sends the image inline with a JSON schema and parses it', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return _utf8Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': jsonEncode(_validJson)},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final analyzer = GeminiImageAnalyzer(apiKey: 'k-123', client: client);

      final result = await analyzer.analyze(_photo);

      expect(
        sent.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '${GeminiImageAnalyzer.defaultModel}:generateContent',
      );
      expect(sent.headers['x-goog-api-key'], 'k-123');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      final parts = (body['contents'] as List).first['parts'] as List;
      expect(parts.last['inline_data']['data'], base64Encode(_photo));
      expect(parts.last['inline_data']['mime_type'], 'image/jpeg');
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect(result.category, ReportCategory.roads);
      expect(result.title, 'Nid-de-poule sur la chaussée');
    });

    test('maps HTTP errors to French messages', () async {
      Future<String> failWith(int status, [String body = '{}']) async {
        final analyzer = GeminiImageAnalyzer(
          apiKey: 'k',
          client: MockClient((_) async => http.Response(body, status)),
        );
        try {
          await analyzer.analyze(_photo);
          return 'no error';
        } on AiException catch (error) {
          return error.message;
        }
      }

      expect(await failWith(401), contains('Clé API invalide'));
      expect(
        await failWith(
          400,
          '{"error":{"message":"API key not valid.","status":"INVALID_ARGUMENT"}}',
        ),
        contains('Clé API invalide'),
      );
      expect(await failWith(400), contains('Vérifiez le modèle'));
      expect(await failWith(403), contains('Clé API invalide'));
      expect(await failWith(404), contains('Modèle introuvable'));
      expect(await failWith(429), contains('Quota'));
      expect(await failWith(503), contains('indisponible'));
    });

    test('reports a network failure', () async {
      final analyzer = GeminiImageAnalyzer(
        apiKey: 'k',
        client: MockClient((_) => throw http.ClientException('offline')),
      );
      expect(
        analyzer.analyze(_photo),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('connexion'),
          ),
        ),
      );
    });
  });

  group('OpenAiCompatibleImageAnalyzer', () {
    test('uses Bearer auth, a data URL and strips ```json fences', () async {
      late http.Request sent;
      final analyzer = OpenAiCompatibleImageAnalyzer(
        apiKey: 'xai-key',
        model: 'grok-vision-latest',
        baseUrl: 'https://api.x.ai/v1/',
        client: MockClient((request) async {
          sent = request;
          return _utf8Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        'Voici :\n```json\n${jsonEncode({..._validJson, 'category': 'Déchets'})}\n```',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await analyzer.analyze(_photo);

      expect(sent.url.toString(), 'https://api.x.ai/v1/chat/completions');
      expect(sent.headers['Authorization'], 'Bearer xai-key');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      final content = (body['messages'] as List).first['content'] as List;
      expect(
        content.last['image_url']['url'],
        startsWith('data:image/jpeg;base64,'),
      );
      expect(result.category, ReportCategory.waste);
    });

    test('rejects an unreadable answer', () {
      expect(
        () => parseAnalysisText('désolé, je ne peux pas'),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('AiSettings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('the placeholder key keeps the AI disabled', () {
      final settings = _placeholderSettings;
      expect(settings.hasKey, isFalse);
      expect(createAnalyzer(settings), isA<DisabledImageAnalyzer>());
    });

    test('a key saved in the app overrides the build-time key', () async {
      final store = AiSettingsStore();
      final fallback = AiSettings.buildTime();
      expect(await store.load(fallback), same(fallback));

      await store.save(
        fallback.copyWith(provider: AiProvider.grok, apiKey: ' xai-9876 '),
      );
      final loaded = await store.load(fallback);

      expect(loaded.apiKey, 'xai-9876');
      expect(loaded.provider, AiProvider.grok);
      expect(loaded.effectiveModel, AiProvider.grok.defaultModel);
      expect(loaded.effectiveBaseUrl, 'https://api.x.ai/v1');
      expect(loaded.maskedKey, '••••9876');
      expect(createAnalyzer(loaded), isA<OpenAiCompatibleImageAnalyzer>());

      await store.save(loaded.copyWith(enabled: false));
      expect(createAnalyzer(await store.load(fallback)).isEnabled, isFalse);
    });

    test('Gemini is the default provider', () {
      final settings = AiSettings.buildTime().copyWith(apiKey: 'AIza-test');
      expect(createAnalyzer(settings), isA<GeminiImageAnalyzer>());
    });
  });

  group('mergeSuggestion', () {
    final analysis = ImageAnalysis.fromJson(_validJson);

    test('fills empty fields', () {
      final merged = mergeSuggestion(
        analysis: analysis,
        category: null,
        categoryChosenByUser: false,
        title: '',
        description: ' ',
      );
      expect(merged.category, ReportCategory.roads);
      expect(merged.title, analysis.title);
      expect(merged.description, analysis.description);
    });

    test('never overwrites what the citizen chose or typed', () {
      final merged = mergeSuggestion(
        analysis: analysis,
        category: ReportCategory.lighting,
        categoryChosenByUser: true,
        title: 'Mon titre',
        description: 'Ma description',
      );
      expect(merged.category, ReportCategory.lighting);
      expect(merged.title, 'Mon titre');
      expect(merged.description, 'Ma description');
    });

    test('Appliquer forces the suggestion', () {
      final merged = mergeSuggestion(
        analysis: analysis,
        category: ReportCategory.lighting,
        categoryChosenByUser: true,
        title: 'Mon titre',
        description: 'Ma description',
        force: true,
      );
      expect(merged.category, ReportCategory.roads);
      expect(merged.title, analysis.title);
    });
  });

  testWidgets('AI settings screen saves the key and only shows it masked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = AiService(
      initial: _placeholderSettings,
      store: AiSettingsStore(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );

    expect(find.text('Désactivé · aucune clé valide'), findsOneWidget);
    expect(find.text('Google Gemini (recommandé)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('ai-key')),
      'AIzaSyTEST1234',
    );
    await tester.scrollUntilVisible(
      find.text('Enregistrer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(service.settings.apiKey, 'AIzaSyTEST1234');
    expect(service.isActive, isTrue);
    await tester.scrollUntilVisible(
      find.text('Activé · clé ••••1234'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Activé · clé ••••1234'), findsOneWidget);
    expect(find.textContaining('AIzaSyTEST1234'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai.apiKey'), 'AIzaSyTEST1234');
    unawaited(service.clear());
  });
}
