import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/validators.dart';
import '../../data/models/report.dart';
import '../../data/repositories/auth_repository.dart';
import '../ai/ai_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final account = state.account;
    if (account == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final reports = state.myReports;
    void editName() => showDialog<void>(
      context: context,
      builder: (_) => _EditNameDialog(name: account.name, state: state),
    );

    return PageList(
      children: [
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: AccountAvatar(
                  id: account.id,
                  name: account.name,
                  radius: 42,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                account.name,
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                account.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: civicMuted),
              ),
              const SizedBox(height: 13),
              FilledButton.tonalIcon(
                onPressed: editName,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier mon profil'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Stat(
                Icons.campaign_outlined,
                reports.length,
                'Signalements faits',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Stat(
                Icons.task_alt,
                reports.where((r) => r.status == ReportStatus.traite).length,
                'Résolus',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Stat(
                Icons.schedule,
                reports.where((r) => r.status == ReportStatus.enCours).length,
                'En cours',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Compte & Préférences', style: text.titleMedium),
        const SizedBox(height: 8),
        CivicCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileItem(
                Icons.manage_accounts_outlined,
                'Modifier mes informations',
                'Nom affiché sur votre profil',
                onTap: editName,
              ),
              const Divider(height: 1),
              _ProfileItem(
                Icons.bookmark_border,
                'Mes adresses favorites',
                'Emplacements fréquents',
                onTap: () => showInfo(
                  context,
                  'Mes adresses favorites',
                  'Vous pouvez indiquer un lieu sur la carte lors de chaque signalement.',
                ),
              ),
              const Divider(height: 1),
              _ProfileItem(
                Icons.notifications_outlined,
                'Alertes de quartier',
                'Suivi des interventions',
                onTap: () => showInfo(
                  context,
                  'Alertes de quartier',
                  'Consultez Mes signalements pour suivre vos dossiers.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Application & Citoyenneté', style: text.titleMedium),
        const SizedBox(height: 8),
        CivicCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileItem(
                Icons.auto_awesome_outlined,
                'Assistant IA',
                'Reconnaissance automatique des photos',
                // Root navigator: full screen, above the tab bar and app bar.
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiSettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ProfileItem(
                Icons.domain_outlined,
                'Services municipaux partenaires',
                'Voirie, éclairage, propreté',
                onTap: () => showInfo(
                  context,
                  'Services municipaux',
                  'Le lieu du constat détermine la municipalité en charge du signalement.',
                ),
              ),
              const Divider(height: 1),
              _ProfileItem(
                Icons.verified_user_outlined,
                'Protection des données',
                'Informations du compte et des signalements',
                onTap: () => showInfo(
                  context,
                  'Protection des données',
                  'Évitez de photographier des personnes identifiables ou de saisir des informations personnelles dans la description.',
                ),
              ),
              const Divider(height: 1),
              _ProfileItem(
                Icons.help_outline,
                'Aide & Foire aux questions',
                'Créer et suivre un dossier',
                onTap: () => showInfo(
                  context,
                  'Aide',
                  'Ajoutez une photo, choisissez une catégorie et confirmez l’emplacement. Retrouvez ensuite la référence et le suivi dans Mes signalements.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const LogoutButton(),
      ],
    );
  }
}

class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key});

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _busy = false;

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().signOut();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Impossible de se déconnecter. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _logout,
    icon: const Icon(Icons.logout, size: 18),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
    label: WorkingLabel('Se déconnecter', busy: _busy),
  );
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem(
    this.icon,
    this.title,
    this.subtitle, {
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      radius: 17,
      foregroundColor: civicBlue,
      backgroundColor: civicTint,
      child: Icon(icon, size: 17),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: civicMuted, fontSize: 12),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: onTap,
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.count, this.label);
  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => CivicCard(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    child: Column(
      children: [
        CircleAvatar(
          radius: 15,
          foregroundColor: civicBlue,
          backgroundColor: civicTint,
          child: Icon(icon, size: 17),
        ),
        const SizedBox(height: 4),
        Text('$count', style: Theme.of(context).textTheme.titleLarge),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.name, required this.state});
  final String name;
  final AppState state;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.updateName(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is RepositoryException
            ? error.message
            : 'Impossible d’enregistrer le profil.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Modifier mon profil'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        enabled: !_busy,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nom complet',
          errorText: _error,
        ),
        validator: (value) =>
            requiredText(value, 'Saisissez votre nom complet.'),
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: WorkingLabel('Enregistrer', busy: _busy),
      ),
    ],
  );
}
