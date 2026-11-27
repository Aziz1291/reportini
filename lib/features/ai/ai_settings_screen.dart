import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ai/ai_service.dart';
import '../../core/ai/image_analyzer.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// "Assistant IA": where the API key for photo recognition is entered.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, this.embedded = false});

  /// True when shown inside the dashboard (no own Scaffold/AppBar).
  final bool embedded;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final AiService _service = context.read<AiService>();
  late AiSettings _initial = _service.settings;
  late bool _enabled = _initial.enabled;
  late AiProvider _provider = _initial.provider;
  // The field starts empty: a saved key is only shown masked.
  final _key = TextEditingController();
  late final _model = TextEditingController(text: _initial.model);
  late final _baseUrl = TextEditingController(text: _initial.baseUrl);
  bool _showKey = false;
  bool _testing = false;
  bool _saving = false;
  String? _testResult;
  bool _testFailed = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  AiSettings get _draft => _initial.copyWith(
    enabled: _enabled,
    provider: _provider,
    apiKey: _key.text.trim().isEmpty ? _initial.apiKey : _key.text.trim(),
    model: _model.text,
    baseUrl: _provider.isOpenAiCompatible ? _baseUrl.text : '',
  );

  void _selectProvider(AiProvider? provider) {
    if (provider == null || provider == _provider) return;
    setState(() {
      _provider = provider;
      _model.text = '';
      _baseUrl.text = '';
      _testResult = null;
    });
  }

  Future<void> _test() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final result = await _service.testConnection(_draft);
      if (!mounted) return;
      setState(() {
        _testFailed = false;
        _testResult =
            'Clé valide ✓  Photo de test reconnue : ${result.category.label} '
            '(${result.confidencePercent} %) — « ${result.title} »';
      });
    } on AiException catch (error) {
      if (mounted) {
        setState(() {
          _testFailed = true;
          _testResult = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _testFailed = true;
          _testResult = 'Test impossible. Vérifiez la connexion Internet.';
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final draft = _draft;
      await _service.save(draft);
      if (!mounted) return;
      setState(() {
        _initial = draft;
        _key.clear();
      });
      showMessage(
        context,
        draft.isActive
            ? 'Assistant IA activé.'
            : 'Réglages enregistrés. Ajoutez une clé pour activer l’IA.',
      );
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Impossible d’enregistrer les réglages.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    await _service.clear();
    if (!mounted) return;
    setState(() {
      _initial = _service.settings;
      _enabled = _initial.enabled;
      _provider = _initial.provider;
      _key.clear();
      _model.text = _initial.model;
      _baseUrl.text = _initial.baseUrl;
      _testResult = null;
    });
    showMessage(context, 'Clé supprimée de l’appareil.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = context.watch<AiService>().settings;
    final busy = _testing || _saving;
    final content = PageList(
      children: [
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: civicTint,
                    foregroundColor: civicBlue,
                    child: Icon(Icons.auto_awesome),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reconnaissance automatique',
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Après la prise de photo, l’IA propose la catégorie, un titre et '
                'une description. Vous gardez toujours la main pour modifier.',
                style: TextStyle(color: civicMuted),
              ),
              const SizedBox(height: 10),
              _StatusPill(
                active: settings.isActive,
                masked: settings.maskedKey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activer la reconnaissance automatique'),
                value: _enabled,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AiProvider>(
                initialValue: _provider,
                decoration: const InputDecoration(labelText: 'Fournisseur'),
                items: [
                  for (final provider in AiProvider.values)
                    DropdownMenuItem(
                      value: provider,
                      child: Text(provider.label),
                    ),
                ],
                onChanged: busy ? null : _selectProvider,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('ai-key'),
                controller: _key,
                enabled: !busy,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Clé API',
                  hintText: settings.hasKey
                      ? 'Clé enregistrée ${settings.maskedKey}'
                      : 'Collez votre clé API ici',
                  suffixIcon: IconButton(
                    tooltip: _showKey ? 'Masquer la clé' : 'Afficher la clé',
                    onPressed: () => setState(() => _showKey = !_showKey),
                    icon: Icon(
                      _showKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _model,
                enabled: !busy,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Modèle',
                  hintText: _provider.defaultModel,
                  helperText:
                      'Laissez vide pour utiliser ${_provider.defaultModel}',
                ),
              ),
              if (_provider.isOpenAiCompatible) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _baseUrl,
                  enabled: !busy,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL de l’API',
                    hintText: _provider.defaultBaseUrl,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (_provider == AiProvider.gemini)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.https('aistudio.google.com', '/apikey'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Obtenir une clé Gemini gratuite'),
                  ),
                ),
            ],
          ),
        ),
        if (_testing) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_testResult case final result?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: CivicCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testFailed
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _testFailed
                        ? Theme.of(context).colorScheme.error
                        : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(result)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy ? null : _test,
          icon: const Icon(Icons.science_outlined, size: 18),
          label: WorkingLabel('Tester la clé', busy: _testing),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: busy ? null : _save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: WorkingLabel('Enregistrer', busy: _saving),
        ),
        if (settings.hasKey) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: busy ? null : _clear,
            child: const Text('Supprimer la clé de l’appareil'),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'La photo est envoyée au fournisseur choisi uniquement pour l’analyse. '
          'En production, la clé doit rester sur un serveur (ex. Cloud Function).',
          style: TextStyle(color: civicMuted, fontSize: 12),
        ),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA')),
      body: SafeArea(child: content),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.masked});
  final bool active;
  final String masked;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF15803D) : civicMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 6),
            Text(
              active ? 'Activé · clé $masked' : 'Désactivé · aucune clé valide',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
