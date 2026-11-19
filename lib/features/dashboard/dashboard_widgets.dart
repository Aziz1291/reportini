import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/municipality.dart';
import '../../data/repositories/auth_repository.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: child,
    ),
  );
}

class DashboardHeading extends StatelessWidget {
  const DashboardHeading(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ?action,
    ],
  );
}

class DashboardMessage extends StatelessWidget {
  const DashboardMessage(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (retry case final callback?)
            TextButton(onPressed: callback, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

Widget municipalityField({
  Key? key,
  required List<Municipality> municipalities,
  required String? selected,
  required ValueChanged<String?> onChanged,
}) => DropdownButtonFormField<String>(
  key: key,
  initialValue: municipalities.any((item) => item.id == selected)
      ? selected
      : null,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Municipalité'),
  items: [
    for (final item in municipalities)
      DropdownMenuItem(
        value: item.id,
        child: Text(item.name, overflow: TextOverflow.ellipsis),
      ),
  ],
  onChanged: onChanged,
  validator: (id) => id == null ? 'Sélectionnez une municipalité.' : null,
);

String dashboardError(Object error) => error is RepositoryException
    ? error.message
    : 'L’opération a échoué. Réessayez.';

class DashboardFormDialog extends StatefulWidget {
  const DashboardFormDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.child,
  });
  final String title;
  final String submitLabel;
  final Future<void> Function() onSubmit;
  final Widget child;

  @override
  State<DashboardFormDialog> createState() => _DashboardFormDialogState();
}

class _DashboardFormDialogState extends State<DashboardFormDialog> {
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = dashboardError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AbsorbPointer(absorbing: _busy, child: widget.child),
              if (_error case final message?) ...[
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(color: Color(0xFFBA1A1A))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(widget.submitLabel),
        ),
      ],
    ),
  );
}

class DashboardMetric extends StatelessWidget {
  const DashboardMetric(this.label, this.value, {super.key});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => CivicCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: civicBlue),
        ),
        Text(label),
      ],
    ),
  );
}
