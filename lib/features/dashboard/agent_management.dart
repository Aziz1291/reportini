import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui.dart';
import '../../core/validators.dart';
import '../../data/models/account.dart';
import '../../data/models/municipality.dart';
import '../../data/repositories/user_repository.dart';
import 'dashboard_widgets.dart';

class AgentManagement extends StatefulWidget {
  const AgentManagement({super.key, required this.municipalities});
  final List<Municipality> municipalities;

  @override
  State<AgentManagement> createState() => _AgentManagementState();
}

class _AgentManagementState extends State<AgentManagement> {
  late final _repository = context.read<AppState>().users;
  late var _agents = _repository.watchAgents();
  final _updating = <String>{};

  void _edit([Account? account]) {
    showDialog<void>(
      context: context,
      builder: (context) => _AgentEditor(
        repository: _repository,
        municipalities: widget.municipalities,
        agent: account,
      ),
    );
  }

  Future<void> _toggle(Account agent, bool enabled) async {
    setState(() => _updating.add(agent.id));
    try {
      await _repository.setAgentEnabled(agent.id, enabled);
    } catch (error) {
      if (mounted) showMessage(context, dashboardError(error));
    } finally {
      if (mounted) setState(() => _updating.remove(agent.id));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Account>>(
    stream: _agents,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return DashboardMessage(
          'Impossible de charger les comptes agents.',
          retry: () => setState(() => _agents = _repository.watchAgents()),
        );
      }
      final agents = snapshot.data;
      if (agents == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final names = {
        for (final item in widget.municipalities) item.id: item.name,
      };
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: agents.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardHeading(
                  'Comptes agents',
                  action: FilledButton.icon(
                    onPressed: names.isEmpty ? null : _edit,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Créer un compte agent'),
                  ),
                ),
                const SizedBox(height: 16),
                if (names.isEmpty)
                  const Text(
                    'Ajoutez une municipalité pour créer des comptes agents.',
                  ),
                if (agents.isEmpty)
                  const Text('Aucun compte agent enregistré.'),
              ],
            );
          }
          final agent = agents[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CivicCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: AccountAvatar(id: agent.id, name: agent.name),
                    title: Text(agent.name),
                    subtitle: Text(
                      '${agent.email}\n${names[agent.municipalityId] ?? 'Municipalité indisponible'}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Changer la municipalité de ${agent.name}',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: names.isEmpty ? null : () => _edit(agent),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      agent.enabled ? 'Compte actif' : 'Compte désactivé',
                    ),
                    value: agent.enabled,
                    onChanged: _updating.contains(agent.id)
                        ? null
                        : (enabled) => _toggle(agent, enabled),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _AgentEditor extends StatefulWidget {
  const _AgentEditor({
    required this.repository,
    required this.municipalities,
    this.agent,
  });
  final UserRepository repository;
  final List<Municipality> municipalities;
  final Account? agent;

  @override
  State<_AgentEditor> createState() => _AgentEditorState();
}

class _AgentEditorState extends State<_AgentEditor> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late String? _municipalityId = widget.agent?.municipalityId;
  bool _obscure = true;

  Future<void> _save() async {
    if (widget.agent case final agent?) {
      await widget.repository.updateAgent(
        agent.id,
        municipalityId: _municipalityId!,
      );
    } else {
      await widget.repository.createAgent(
        _name.text,
        _email.text,
        _password.text,
        _municipalityId!,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DashboardFormDialog(
    title: widget.agent == null
        ? 'Créer un compte agent'
        : 'Changer de municipalité',
    submitLabel: widget.agent == null ? 'Créer le compte' : 'Enregistrer',
    onSubmit: _save,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.agent == null) ...[
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom complet'),
            validator: (value) =>
                requiredText(value, 'Saisissez le nom complet.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Adresse e-mail'),
            keyboardType: TextInputType.emailAddress,
            validator: validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Mot de passe temporaire',
              helperText: 'Au moins 8 caractères et un chiffre.',
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: validatePassword,
          ),
        ] else
          Text(widget.agent!.name),
        const SizedBox(height: 12),
        municipalityField(
          municipalities: widget.municipalities,
          selected: _municipalityId,
          onChanged: (value) => _municipalityId = value,
        ),
      ],
    ),
  );
}
