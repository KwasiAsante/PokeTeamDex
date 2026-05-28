import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReferenceHubScreen extends StatelessWidget {
  const ReferenceHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reference')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubTile(
            icon: Icons.auto_awesome,
            title: 'Abilities',
            subtitle: 'Browse all Pokémon abilities and their effects',
            onTap: () => context.go('/reference/abilities'),
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.category,
            title: 'Types',
            subtitle: 'Explore type effectiveness and damage relations',
            onTap: () => context.go('/reference/types'),
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.tune,
            title: 'Natures',
            subtitle: 'View stat modifiers for all 25 natures',
            onTap: () => context.go('/reference/natures'),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(icon, color: colorScheme.onPrimaryContainer),
        ),
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

