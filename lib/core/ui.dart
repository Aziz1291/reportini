import 'package:flutter/material.dart';

import 'constants.dart';
import 'theme.dart';

class PageList extends StatelessWidget {
  const PageList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.controller,
  });
  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: ListView(
        controller: controller,
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    ),
  );
}

class CivicCard extends StatelessWidget {
  const CivicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: civicLine),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .23),
    child: Image.asset(
      logoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: civicBlue,
        child: Icon(Icons.location_on, color: Colors.white, size: size * .67),
      ),
    ),
  );
}

class BrandTitle extends StatelessWidget {
  const BrandTitle(this.subtitle, {super.key});
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const BrandLogo(),
      const SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPORTINI',
            style: TextStyle(
              fontSize: 15,
              color: civicBlue,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: civicMuted),
          ),
        ],
      ),
    ],
  );
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.id,
    required this.name,
    this.radius = 16,
  });
  final String id;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: civicTint,
    foregroundColor: civicBlue,
    backgroundImage: id == 'citoyen' ? const AssetImage(avatarAsset) : null,
    child: id == 'citoyen' ? null : Text(name.characters.first.toUpperCase()),
  );
}

class WorkingLabel extends StatelessWidget {
  const WorkingLabel(this.label, {super.key, required this.busy});
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) => busy
      ? SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
            semanticsLabel: label,
          ),
        )
      : Text(label);
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showInfo(BuildContext context, String title, String content) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
