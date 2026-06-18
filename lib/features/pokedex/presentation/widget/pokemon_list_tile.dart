import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

class PokemonListTile extends ConsumerStatefulWidget {
  final PokemonListEntry pokemon;
  final PokedexImageType? imageType;

  const PokemonListTile({
    super.key,
    required this.pokemon,
    this.imageType,
  });

  @override
  ConsumerState<PokemonListTile> createState() => _PokemonListTileState();
}

class _PokemonListTileState extends ConsumerState<PokemonListTile> {
  String? _selectedFormName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(pokedexFilterProvider);
    final isCompact = widget.imageType == null;

    final resolvedAsync = ref.watch(resolvedPokemonProvider(widget.pokemon.id));
    final resolved = resolvedAsync.asData?.value;
    final basePokemon = resolved?.detail;
    final cosmeticFormEntries = resolved?.cosmeticForms ?? const <PokemonFormEntry>[];

    // Check if the currently selected form is a cosmetic form entry.
    // Cosmetic form entries share the base Pokémon's types — no provider call
    // needed. Variety forms (Giratina Origin, Alolan Raticate, etc.) need
    // pokemonByNameProvider to get updated types and artwork.
    final selectedCosmeticEntry = _selectedFormName != null
        ? cosmeticFormEntries
            .where((f) => f.name == _selectedFormName)
            .firstOrNull
        : null;
    final formAsync = (_selectedFormName != null && selectedCosmeticEntry == null)
        ? ref.watch(pokemonByNameProvider(_selectedFormName!))
        : null;

    // Form list — computed once species resolves
    final species = resolved?.species;
    final battleForms =
        species != null ? battleMeaningfulForms(species.varieties) : <PokemonVariety>[];
    final cosmeticVarietyForms = species != null
        ? species.varieties
            .where((v) => PokemonDataRegistry.instance.cosmeticVarietyNames.contains(v.name))
            .toList()
        : <PokemonVariety>[];
    final baseFormLabel = species != null
        ? computeBaseFormLabel(
            widget.pokemon.name, species.generationName, battleForms)
        : 'Base';

    final allForms = <(String?, String, String?)>[
      (null, baseFormLabel, null),
      ...battleForms.map((v) => (v.name, shortFormLabel(v.name), null as String?)),
      ...cosmeticVarietyForms.map((v) {
        final sn = basePokemon?.speciesName ?? widget.pokemon.name;
        final suffix = v.name.startsWith('$sn-')
            ? v.name.substring(sn.length + 1)
            : v.name;
        // Use HOME artwork override when available (e.g. mimikyu-busted has no
        // officialArtworkUrl in PokéAPI so pokemonByNameProvider returns null artwork).
        return (v.name, PokemonDataRegistry.instance.cosmeticFormLabels[v.name] ?? cosmeticFormLabel(suffix),
            PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides[v.name]);
      }),
      // Form-entry cosmetics: carry sprite so FormOptionTile doesn't call
      // pokemonByNameProvider with a form name that has no /pokemon endpoint.
      // PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides takes priority (e.g. xerneas-active shows
      // the neutral pose image, not the active-pose sprite).
      ...cosmeticFormEntries.map((f) => (
        f.name,
        PokemonDataRegistry.instance.cosmeticFormLabels[f.name] ?? cosmeticFormLabel(f.formName),
        PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides[f.name] ??
            (f.formName == 'female' ? '${_kBase}female/${widget.pokemon.id}.png' : f.spriteUrl),
      )),
    ];
    final hasFormChip = allForms.length > 1;

    // Effective type/color — cosmetic form entries keep base types unchanged.
    final formEntry = formAsync?.asData?.value;
    final isFormLoading = formAsync != null && formAsync.isLoading;

    final effectiveTypes = formEntry?.types ?? basePokemon?.types;
    final primaryType = effectiveTypes != null && effectiveTypes.isNotEmpty
        ? effectiveTypes[0]
        : null;
    final types = effectiveTypes ?? const <String>[];

    final typeColor = primaryType != null
        ? (PokemonTypeColors.colors[primaryType] ?? colorScheme.primary)
        : colorScheme.surfaceContainerLow;

    // Image URL
    final imageUrl = PokemonDataResolver.resolvePokedexImageUrl(
      pokemonId: widget.pokemon.id,
      baseSpecies: basePokemon?.speciesName ?? widget.pokemon.name,
      selectedFormName: _selectedFormName,
      imageType: widget.imageType,
      formEntry: formEntry,
      cosmeticEntry: selectedCosmeticEntry,
      filter: filter,
    );
    final fallbackUrl = PokemonDataResolver.resolvePokedexFallbackUrl(
      pokemonId: widget.pokemon.id,
      imageType: widget.imageType,
      selectedFormName: _selectedFormName,
      formEntry: formEntry,
      cosmeticEntry: selectedCosmeticEntry,
    );

    // Display name
    final baseDisplayName = basePokemon?.displaySpeciesName ??
        widget.pokemon.name
            .split('-')
            .map((w) =>
                w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    final selectedLabel = _selectedFormName != null
        ? allForms
            .firstWhere(
              (f) => f.$1 == _selectedFormName,
              orElse: () => (_selectedFormName, shortFormLabel(_selectedFormName!), null),
            )
            .$2
        : null;
    final displayName = selectedLabel != null
        ? '$baseDisplayName - $selectedLabel'
        : baseDisplayName;

    // Image dimensions
    final imageSize = switch (widget.imageType) {
      PokedexImageType.artwork => 180.0,
      PokedexImageType.sprite  => 64.0,
      null                     => 60.0,
    };
    final imageHeight = switch (widget.imageType) {
      PokedexImageType.artwork => 180.0,
      PokedexImageType.sprite  => 64.0,
      null                     => 50.0,
    };

    Widget? formChip;
    if (hasFormChip) {
      final chipLabel = selectedLabel ?? baseFormLabel;
      formChip = GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => FormPickerSheet(
            allForms: allForms,
            baseSpriteUrl: basePokemon?.officialArtworkUrl
                ?? resolved?.spriteUrls.home,
            selectedFormName: _selectedFormName,
            shiny: false,
            onSelect: (name) {
              setState(() => _selectedFormName = name);
              Navigator.pop(ctx);
            },
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(chipLabel,
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurface)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down,
                  size: 14, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            // Only pass ?form= for battle-meaningful variety forms (Giratina-Origin,
            // Alolan Raticate, etc.). Cosmetic varieties (mimikyu-busted, etc.) and
            // form-entry cosmetics (shellos-east-sea, etc.) are not handled by the
            // detail screen's initialFormName — navigate to the base screen instead.
            final isBattleForm = _selectedFormName != null &&
                battleForms.any((v) => v.name == _selectedFormName);
            if (isBattleForm) {
              context.push(
                  '/pokedex/${widget.pokemon.id}?form=$_selectedFormName');
            } else {
              context.push('/pokedex/${widget.pokemon.id}');
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  typeColor.withValues(alpha: 0.35),
                  typeColor.withValues(alpha: 0.06),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Hero(
                  tag:
                      'pokemon-sprite-${widget.pokemon.id}${_selectedFormName != null ? '-$_selectedFormName' : ''}',
                  child: SizedBox(
                    width: imageSize,
                    height: imageHeight,
                    child: isFormLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: CachedNetworkImage(
                              key: ValueKey(imageUrl),
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => widget.imageType == null
                                  ? CachedNetworkImage(
                                      imageUrl: fallbackUrl,
                                      width: imageSize,
                                      height: imageSize,
                                      fit: BoxFit.contain,
                                      errorWidget: (_, _, _) => Icon(
                                        Icons.catching_pokemon,
                                        size: imageSize,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                    )
                                  : Icon(
                                      Icons.catching_pokemon,
                                      size: imageSize,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${widget.pokemon.displayId()}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        displayName,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (types.isNotEmpty || (hasFormChip && !isCompact))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              ...types.map((t) => TypeBadge(type: t)),
                              if (!isCompact && formChip != null) formChip,
                            ],
                          ),
                        ),
                      if (isCompact && formChip != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: formChip,
                        ),
                    ],
                  ),
                ),

                FavoriteButton(pokemonId: widget.pokemon.id, iconSize: 20),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
