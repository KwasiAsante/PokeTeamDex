import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';

/// Bottom-sheet form picker.
///
/// [allForms] is a pre-computed list of (pokéApiName, displayLabel) pairs.
/// The base/default form always has `name == null` and must be the first entry.
class FormPickerSheet extends StatelessWidget {
  final List<(String?, String)> allForms;
  final String? baseSpriteUrl;
  final String? baseShinyUrl;
  final String? selectedFormName;
  final bool shiny;
  final void Function(String?) onSelect;

  const FormPickerSheet({
    super.key,
    required this.allForms,
    this.baseSpriteUrl,
    this.baseShinyUrl,
    required this.selectedFormName,
    required this.shiny,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Form',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allForms.map((opt) {
              final (name, label) = opt;
              return FormOptionTile(
                formName: name,
                label: label,
                isSelected: name == selectedFormName,
                shiny: shiny,
                overrideSpriteUrl: name == null
                    ? (shiny ? (baseShinyUrl ?? baseSpriteUrl) : baseSpriteUrl)
                    : null,
                onTap: () => onSelect(name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Single tile inside [FormPickerSheet]. Fetches artwork via
/// [pokemonByNameProvider] when [formName] is non-null.
class FormOptionTile extends ConsumerWidget {
  final String? formName;
  final String label;
  final bool isSelected;
  final bool shiny;
  final String? overrideSpriteUrl;
  final void Function() onTap;

  const FormOptionTile({
    super.key,
    required this.formName,
    required this.label,
    required this.isSelected,
    required this.shiny,
    this.overrideSpriteUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final pokemonAsync =
        formName != null ? ref.watch(pokemonByNameProvider(formName!)) : null;
    final formPokemon = pokemonAsync?.asData?.value;
    final spriteUrl = overrideSpriteUrl ??
        (shiny
            ? (formPokemon?.officialArtworkShinyUrl ??
                formPokemon?.officialArtworkUrl)
            : formPokemon?.officialArtworkUrl);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spriteUrl != null)
              CachedNetworkImage(imageUrl: spriteUrl, height: 56, width: 56)
            else
              const SizedBox(
                height: 56,
                width: 56,
                child: Icon(Icons.catching_pokemon, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
