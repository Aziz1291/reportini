import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_keys.dart';
import 'image_analysis.dart';
import 'image_analyzer.dart';

enum AiProvider {
  gemini('Google Gemini (recommandé)', GeminiImageAnalyzer.defaultModel, ''),
  grok('xAI Grok', 'grok-vision-latest', 'https://api.x.ai/v1'),
  openai('OpenAI', 'gpt-4o-mini', 'https://api.openai.com/v1');

  const AiProvider(this.label, this.defaultModel, this.defaultBaseUrl);
  final String label;
  final String defaultModel;
  final String defaultBaseUrl;

  bool get isOpenAiCompatible => this != gemini;

  static AiProvider parse(String? value) => values.firstWhere(
    (provider) => provider.name == value?.trim().toLowerCase(),
    orElse: () => gemini,
  );
}

@immutable
class AiSettings {
  const AiSettings({
    required this.enabled,
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

  /// Values coming from lib/core/ai/ai_keys.dart or --dart-define.
  factory AiSettings.buildTime() => AiSettings(
    enabled: true,
    provider: AiProvider.parse(kAiProvider),
    apiKey: kAiApiKey,
    model: kAiModel,
    baseUrl: kAiBaseUrl,
  );

  final bool enabled;
  final AiProvider provider;
  final String apiKey;
  final String model;
  final String baseUrl;

  /// A key that is empty or still the placeholder counts as "no key".
  bool get hasKey {
    final key = apiKey.trim();
    return key.isNotEmpty && key != kAiApiKeyPlaceholder;
  }

  bool get isActive => enabled && hasKey;

  String get effectiveModel =>
      model.trim().isEmpty ? provider.defaultModel : model.trim();

  String get effectiveBaseUrl =>
      baseUrl.trim().isEmpty ? provider.defaultBaseUrl : baseUrl.trim();

  /// "••••1234" — the key itself is never displayed.
  String get maskedKey {
    if (!hasKey) return 'Aucune clé';
    final key = apiKey.trim();
    return '••••${key.length > 4 ? key.substring(key.length - 4) : key}';
  }

  AiSettings copyWith({
    bool? enabled,
    AiProvider? provider,
    String? apiKey,
    String? model,
    String? baseUrl,
  }) => AiSettings(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    baseUrl: baseUrl ?? this.baseUrl,
  );
}

/// Persists the settings typed in the "Assistant IA" screen.
/// Stored values take precedence over the build-time key.
class AiSettingsStore {
  static const _prefix = 'ai.';

  Future<AiSettings> load(AiSettings fallback) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('${_prefix}saved') ?? false)) return fallback;
    final storedKey = prefs.getString('${_prefix}apiKey') ?? '';
    return AiSettings(
      enabled: prefs.getBool('${_prefix}enabled') ?? true,
      provider: AiProvider.parse(prefs.getString('${_prefix}provider')),
      // An empty stored key falls back to the key written in the code.
      apiKey: storedKey.isEmpty ? fallback.apiKey : storedKey,
      model: prefs.getString('${_prefix}model') ?? '',
      baseUrl: prefs.getString('${_prefix}baseUrl') ?? '',
    );
  }

  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}saved', true);
    await prefs.setBool('${_prefix}enabled', settings.enabled);
    await prefs.setString('${_prefix}provider', settings.provider.name);
    await prefs.setString('${_prefix}apiKey', settings.apiKey.trim());
    await prefs.setString('${_prefix}model', settings.model.trim());
    await prefs.setString('${_prefix}baseUrl', settings.baseUrl.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}

typedef AnalyzerFactory = ImageAnalyzer Function(AiSettings settings);

ImageAnalyzer createAnalyzer(AiSettings settings, {http.Client? client}) {
  if (!settings.isActive) return const DisabledImageAnalyzer();
  if (settings.provider == AiProvider.gemini) {
    return GeminiImageAnalyzer(
      apiKey: settings.apiKey.trim(),
      model: settings.effectiveModel,
      client: client,
    );
  }
  return OpenAiCompatibleImageAnalyzer(
    apiKey: settings.apiKey.trim(),
    model: settings.effectiveModel,
    baseUrl: settings.effectiveBaseUrl,
    client: client,
  );
}

class AiService extends ChangeNotifier {
  AiService({
    AiSettings? initial,
    AiSettingsStore? store,
    AnalyzerFactory? analyzerFactory,
  }) : _settings = initial ?? AiSettings.buildTime(),
       _store = store ?? AiSettingsStore(),
       _factory = analyzerFactory ?? createAnalyzer;

  static Future<AiService> load() async {
    final store = AiSettingsStore();
    var settings = AiSettings.buildTime();
    try {
      settings = await store.load(settings);
    } catch (_) {
      // Storage problems must never block the app: keep build-time values.
    }
    return AiService(initial: settings, store: store);
  }

  AiSettings _settings;
  final AiSettingsStore _store;
  final AnalyzerFactory _factory;
  late ImageAnalyzer _analyzer = _factory(_settings);

  AiSettings get settings => _settings;
  ImageAnalyzer get analyzer => _analyzer;
  bool get isActive => _analyzer.isEnabled;

  Future<void> save(AiSettings settings) async {
    await _store.save(settings);
    _apply(settings);
  }

  Future<void> clear() async {
    await _store.clear();
    _apply(AiSettings.buildTime());
  }

  /// Analyzes a bundled sample photo with the given (unsaved) settings.
  Future<ImageAnalysis> testConnection(AiSettings settings) async {
    final analyzer = _factory(settings);
    if (!analyzer.isEnabled) {
      throw const AiException('Saisissez une clé API valide.');
    }
    final data = await rootBundle.load('assets/images/pothole.png');
    final bytes = data.buffer.asUint8List();
    return analyzer.analyze(bytes, mimeType: detectMimeType(bytes));
  }

  void _apply(AiSettings settings) {
    _settings = settings;
    _analyzer = _factory(settings);
    notifyListeners();
  }
}
