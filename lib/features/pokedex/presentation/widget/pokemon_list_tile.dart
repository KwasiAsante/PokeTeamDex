import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/pokemon_grid_card.dart'
    show PokedexImageType;
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_list_provider.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

const _kVgToSubpath = <String, String?>{
  'red-blue':                        'versions/generation-i/red-blue',
  'yellow':                          'versions/generation-i/yellow',
  'gold-silver':                     'versions/generation-ii/gold',
  'crystal':                         'versions/generation-ii/crystal',
  'ruby-sapphire':                   'versions/generation-iii/ruby-sapphire',
  'emerald':                         'versions/generation-iii/emerald',
  'firered-leafgreen':               'versions/generation-iii/firered-leafgreen',
  'diamond-pearl':                   'versions/generation-iv/diamond-pearl',
  'platinum':                        'versions/generation-iv/platinum',
  'heartgold-soulsilver':            'versions/generation-iv/heartgold-soulsilver',
  'black-white':                     'versions/generation-v/black-white',
  'black-2-white-2':                 'versions/generation-v/black-white',
  'x-y':                             null,
  'omega-ruby-alpha-sapphire':       null,
  'sun-moon':                        null,
  'ultra-sun-ultra-moon':            null,
  'lets-go-pikachu-lets-go-eevee':   null,
  'sword-shield':                    null,
  'brilliant-diamond-and-shining-pearl': null,
  'legends-arceus':                  null,
  'scarlet-violet':                  null,
};

const _kGenToLastVg = <int, String>{
  1: 'yellow',   2: 'crystal',
  3: 'emerald',  4: 'heartgold-soulsilver',
  5: 'black-white',         6: 'omega-ruby-alpha-sapphire',
  7: 'ultra-sun-ultra-moon', 8: 'sword-shield',
  9: 'scarlet-violet',
};

String _compactIconUrl(int pokemonId, PokedexFilter filter) {
  String? vg;
  if (filter.game != null) {
    vg = kFormatToVersionGroup[filter.game];
  } else if (filter.generation != null) {
    vg = _kGenToLastVg[filter.generation];
  }
  final subpath = vg != null ? _kVgToSubpath[vg] : null;
  if (subpath == null) return '$_kBase$pokemonId.png';
  return '$_kBase$subpath/$pokemonId.png';
}

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

    final detailAsync = ref.watch(pokemonDetailProvider(widget.pokemon.id));
    final speciesAsync = ref.watch(pokemonSpeciesProvider(widget.pokemon.id));
    final formAsync = _selectedFormName != null
        ? ref.watch(pokemonByNameProvider(_selectedFormName!))
        : null;

    // Form list — computed once species resolves
    final species = speciesAsync.asData?.value;
    final battleForms =
        species != null ? battleMeaningfulForms(species.varieties) : <PokemonVariety>[];
    final cosmeticVarietyForms = species != null
        ? species.varieties
            .where((v) => kCosmeticVarietyNames.contains(v.name))
            .toList()
        : <PokemonVariety>[];
    final baseFormLabel = species != null
        ? computeBaseFormLabel(
            widget.pokemon.name, species.generationName, battleForms)
        : 'Base';

    final allForms = <(String?, String)>[
      (null, baseFormLabel),
      ...battleForms.map((v) => (v.name, shortFormLabel(v.name))),
      ...cosmeticVarietyForms.map((v) {
        final baseName = widget.pokemon.name;
        final suffix = v.name.startsWith('$baseName-')
            ? v.name.substring(baseName.length + 1)
            : v.name;
        return (v.name, kCosmeticFormLabels[v.name] ?? cosmeticFormLabel(suffix));
      }),
    ];
    final hasFormChip = allForms.length > 1;

    // Effective type/color: use form types when available
    final basePokemon = detailAsync.asData?.value;
    final formEntry = formAsync?.asData?.value;
    final isFormLoading = formAsync != null && formAsync.isLoading;

    final effectiveTypes = formEntry?.types ??
        detailAsync.whenOrNull(data: (p) => p.types);
    final primaryType =
        effectiveTypes?[1] ?? effectiveTypes?.values.firstOrNull;
    final types = effectiveTypes?.values.toList() ?? const <String>[];

    final typeColor = primaryType != null
        ? (PokemonTypeColors.colors[primaryType] ?? colorScheme.primary)
        : colorScheme.surfaceContainerLow;

    // Image URL — form sprite when selected, else base sprite
    final imageUrl = _buildImageUrl(formEntry, filter);
    final fallbackUrl = '$_kBase${widget.pokemon.id}.png';

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
              orElse: () => (_selectedFormName, shortFormLabel(_selectedFormName!)),
            )
            .$2
        : null;
    final displayName = selectedLabel != null
        ? '$baseDisplayName - $selectedLabel'
        : baseDisplayName;

    // Image dimensions (unchanged from original)
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

    // Form chip widget (null when no forms available)
    Widget? formChip;
    if (hasFormChip) {
      final chipLabel = selectedLabel ?? baseFormLabel;
      formChip = GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => FormPickerSheet(
            allForms: allForms,
            baseSpriteUrl:
                basePokemon?.sprites?['front_default'] as String?,
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
            if (_selectedFormName != null) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Image
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

                // Info column
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
                      // Type badges + inline chip (medium+) or just badges
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
                      // Compact: chip on its own row
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

  String _buildImageUrl(PokemonEntry? formEntry, PokedexFilter filter) {
    if (_selectedFormName != null && formEntry != null) {
      if (widget.imageType == PokedexImageType.artwork) {
        return formEntry.officialArtworkUrl ??
            '${_kBase}other/official-artwork/${widget.pokemon.id}.png';
      }
      return (formEntry.sprites?['front_default'] as String?) ??
          '$_kBase${widget.pokemon.id}.png';
    }
    return switch (widget.imageType) {
      PokedexImageType.artwork =>
        '${_kBase}other/official-artwork/${widget.pokemon.id}.png',
      PokedexImageType.sprite => _compactIconUrl(widget.pokemon.id, filter),
      null =>
        '${_kBase}versions/generation-viii/icons/${widget.pokemon.id}.png',
    };
  }
}
