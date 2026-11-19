import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/validators.dart';
import '../../data/repositories/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.registration = false});
  final bool registration;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  bool get registration => widget.registration;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      if (registration) {
        await state.auth.register(_name.text, _email.text, _password.text);
        if (!mounted) return;
        showMessage(context, 'Compte créé. Vous pouvez vous connecter.');
        context.go('/connexion');
      } else {
        await state.signIn(_email.text, _password.text);
      }
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Service indisponible. Réessayez dans un instant.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(BuildContext context, String value, [String? hint]) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.labelLarge),
        ),
        if (hint != null)
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: civicMuted),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: registration
          ? AppBar(
              leading: BackButton(
                onPressed: _busy ? null : () => context.go('/connexion'),
              ),
              centerTitle: true,
              title: const BrandLogo(),
            )
          : null,
      body: SafeArea(
        child: PageList(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
          children: [
            if (registration) ...[
              Text(
                'Espace Citoyen',
                style: text.labelLarge?.copyWith(color: civicBlue),
              ),
              const SizedBox(height: 6),
              Text('Créer un compte', style: text.headlineMedium),
              const SizedBox(height: 6),
              const Text(
                'Rejoignez votre communauté pour améliorer votre ville au quotidien.',
                style: TextStyle(color: civicMuted),
              ),
            ] else ...[
              const Center(child: BrandLogo(size: 66)),
              const SizedBox(height: 10),
              Text(
                'REPORTINI',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  color: civicBlue,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                'L’application citoyenne pour votre ville',
                textAlign: TextAlign.center,
                style: TextStyle(color: civicMuted),
              ),
              const SizedBox(height: 24),
              CivicCard(
                color: const Color(0xFFF0F2F5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          color: civicBlue,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text('Espace Citoyen', style: text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bienvenue sur votre espace citoyen. Participez activement à l’amélioration de votre cadre de vie.',
                      style: TextStyle(color: civicMuted),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (registration) ...[
                      _label(context, 'Nom complet', 'Requis'),
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Claire Dubois',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            requiredText(value, 'Saisissez votre nom complet.'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _label(
                      context,
                      'Adresse e-mail',
                      registration ? null : 'Identifiant municipal',
                    ),
                    TextFormField(
                      key: const Key('auth-email'),
                      controller: _email,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: registration
                            ? 'claire.dubois@citoyen.fr'
                            : 'exemple@citoyen.fr',
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    _label(context, 'Mot de passe'),
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        registration
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: registration
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: registration ? null : (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: registration
                            ? '8 caractères minimum'
                            : '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: validatePassword,
                    ),
                    if (registration) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _password,
                        builder: (context, value, _) => Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _PasswordRule(
                              'Au moins 8 caractères',
                              valid: value.text.length >= 8,
                            ),
                            _PasswordRule(
                              '1 chiffre inclus',
                              valid: hasPasswordDigit(value.text),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _label(context, 'Confirmer le mot de passe'),
                      TextFormField(
                        enabled: !_busy,
                        obscureText: _hidePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: Icon(Icons.check_circle_outline),
                        ),
                        validator: (value) =>
                            validateConfirmation(value, _password.text),
                      ),
                      const SizedBox(height: 12),
                      FormField<bool>(
                        initialValue: false,
                        validator: (checked) => checked == true
                            ? null
                            : 'Acceptez les conditions pour créer un compte.',
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'J’accepte les conditions d’utilisation et la politique de confidentialité de ma ville.',
                              ),
                              value: field.value,
                              onChanged: _busy ? null : field.didChange,
                            ),
                            TextButton(
                              onPressed: () => showInfo(
                                context,
                                'Conditions et confidentialité',
                                'Reportini permet de signaler les problèmes dans l’espace public. '
                                    'Évitez d’inclure des personnes identifiables sur les photos. '
                                    'Le compte, la photo et la localisation servent au suivi du signalement.',
                              ),
                              child: const Text('Lire les conditions'),
                            ),
                            if (field.errorText case final error?)
                              Text(
                                error,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => showInfo(
                                  context,
                                  'Mot de passe oublié ?',
                                  'La réinitialisation du mot de passe sera disponible prochainement.',
                                ),
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 6),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const Key('auth-submit'),
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: WorkingLabel(
                        registration ? 'Créer mon compte' : 'Se connecter',
                        busy: _busy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    registration
                        ? 'Déjà inscrit ?'
                        : 'Vous n’avez pas de compte ?',
                    style: const TextStyle(color: civicMuted),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.go(
                            registration ? '/connexion' : '/inscription',
                          ),
                    child: Text(
                      registration ? 'Se connecter' : 'Créer un compte',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CivicCard(
              color: const Color(0xFFF0F2F5),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: civicBlue,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      registration
                          ? 'Données civiques · utilisez uniquement les informations nécessaires à votre signalement.'
                          : 'Service de signalement citoyen',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule(this.text, {required this.valid});
  final String text;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final color = valid ? const Color(0xFF047857) : civicMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          valid ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: color,
          size: 15,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
