import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart' show cosmeticFormHomeUrl;
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

const _kBase = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

enum PokedexImageType { artwork, sprite }

class PokemonGridCard extends ConsumerStatefulWidget {
  final PokemonListEntry pokemon;
  final PokedexImageType imageType;

  const PokemonGridCard({
    super.key,
    required this.pokemon,
    required this.imageType,
  });

  @override
  ConsumerState<PokemonGridCard> createState() => _PokemonGridCardState();
}

class _PokemonGridCardState extends ConsumerState<PokemonGridCard> {
  String? _selectedFormName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final detailAsync = ref.watch(pokemonDetailProvider(widget.pokemon.id));
    final speciesAsync = ref.watch(pokemonSpeciesProvider(widget.pokemon.id));

    final basePokemon = detailAsync.asData?.value;

    // Form-based cosmetics — gated on formNames.length > 1
    final shouldFetchCosmetic = basePokemon != null &&
        basePokemon.formNames.length > 1 &&
        !kNoCosmeticFormsPokemon.contains(basePokemon.name);
    final cosmeticFormsAsync = shouldFetchCosmetic
        ? ref.watch(cosmeticFormsProvider(basePokemon.name))
        : null;

    final rawEntries =
        cosmeticFormsAsync?.asData?.value ?? const <PokemonFormEntry>[];
    final cosmeticFormEntries = <PokemonFormEntry>[
      ...rawEntries.map((f) {
        if (f.spriteUrl == null && f.formName == 'female' && basePokemon != null) {
          return PokemonFormEntry(
            id: f.id,
            name: f.name,
            formName: f.formName,
            isDefault: f.isDefault,
            spriteUrl: '${_kBase}female/${basePokemon.id}.png',
            spriteShinyUrl: '${_kBase}shiny/female/${basePokemon.id}.png',
          );
        }
        return f;
      }),
      if (basePokemon != null &&
          kCosmeticGenderDiffPokemon.contains(basePokemon.name))
        PokemonFormEntry(
          id: basePokemon.id,
          name: '${basePokemon.name}-female',
          formName: 'female',
          isDefault: false,
          spriteUrl: '${_kBase}female/${basePokemon.id}.png',
          spriteShinyUrl: '${_kBase}shiny/female/${basePokemon.id}.png',
        ),
    ];

    final selectedCosmeticEntry = _selectedFormName != null
        ? cosmeticFormEntries
            .where((f) => f.name == _selectedFormName)
            .firstOrNull
        : null;
    final formAsync = (_selectedFormName != null && selectedCosmeticEntry == null)
        ? ref.watch(pokemonByNameProvider(_selectedFormName!))
        : null;

    // Form list
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

    final allForms = <(String?, String, String?)>[
      (null, baseFormLabel, null),
      ...battleForms.map((v) => (v.name, shortFormLabel(v.name), null as String?)),
      ...cosmeticVarietyForms.map((v) {
        final sn = basePokemon?.speciesName ?? widget.pokemon.name;
        final suffix = v.name.startsWith('$sn-')
            ? v.name.substring(sn.length + 1)
            : v.name;
        return (v.name, kCosmeticFormLabels[v.name] ?? cosmeticFormLabel(suffix),
            kCosmeticFormHomeUrlOverrides[v.name] as String?);
      }),
      ...cosmeticFormEntries.map((f) => (
        f.name,
        kCosmeticFormLabels[f.name] ?? cosmeticFormLabel(f.formName),
        kCosmeticFormHomeUrlOverrides[f.name] ??
            (f.formName == 'female' ? '${_kBase}female/${widget.pokemon.id}.png' : f.spriteUrl),
      )),
    ];
    final hasFormChip = allForms.length > 1;

    // Cosmetic form entries keep base types — no gradient change needed.
    final formEntry = formAsync?.asData?.value;
    final isFormLoading = formAsync != null && formAsync.isLoading;

    final effectiveTypes = formEntry?.types ??
        detailAsync.whenOrNull(data: (p) => p.types);
    final primaryType =
        effectiveTypes?[1] ?? effectiveTypes?.values.firstOrNull;
    final types = effectiveTypes?.values.toList() ?? const <String>[];

    final typeColor = primaryType != null
        ? (PokemonTypeColors.colors[primaryType] ?? colorScheme.primary)
        : colorScheme.surfaceContainerHighest;

    final imageUrl = _buildImageUrl(formEntry, selectedCosmeticEntry, basePokemon);

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
              orElse: () =>
                  (_selectedFormName, shortFormLabel(_selectedFormName!), null),
            )
            .$2
        : null;
    final displayName = selectedLabel != null
        ? '$baseDisplayName - $selectedLabel'
        : baseDisplayName;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final isBattleForm = _selectedFormName != null &&
              battleForms.any((v) => v.name == _selectedFormName);
          if (isBattleForm) {
            context
                .push('/pokedex/${widget.pokemon.id}?form=$_selectedFormName');
          } else {
            context.push('/pokedex/${widget.pokemon.id}');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          typeColor.withValues(alpha: 0.35),
                          typeColor.withValues(alpha: 0.10),
                        ],
                      ),
                    ),
                    child: Hero(
                      tag:
                          'pokemon-sprite-${widget.pokemon.id}${_selectedFormName != null ? '-$_selectedFormName' : ''}',
                      child: isFormLoading
                          ? const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: CachedNetworkImage(
                                key: ValueKey(imageUrl),
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (_, _) => const Center(
                                  child: Icon(Icons.catching_pokemon,
                                      size: 48, color: Colors.white30),
                                ),
                                errorWidget: (_, _, _) => const Center(
                                  child: Icon(Icons.catching_pokemon,
                                      size: 48, color: Colors.white30),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (hasFormChip)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (ctx) => FormPickerSheet(
                            allForms: allForms,
                            baseSpriteUrl: basePokemon
                                ?.sprites?['front_default'] as String?,
                            selectedFormName: _selectedFormName,
                            shiny: false,
                            onSelect: (name) {
                              setState(() => _selectedFormName = name);
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedLabel ?? baseFormLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white, size: 13),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${widget.pokemon.displayId()}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    displayName,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (types.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children:
                            types.map((t) => TypeBadge(type: t)).toList(),
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

  String _buildImageUrl(PokemonEntry? formEntry, PokemonFormEntry? cosmeticEntry, PokemonEntry? base) {
    if (_selectedFormName != null) {
      if (cosmeticEntry != null) {
        if (widget.imageType == PokedexImageType.artwork) {
          final override = kCosmeticFormHomeUrlOverrides[cosmeticEntry.name];
          if (override != null) return override;
          if (cosmeticEntry.formName == 'female') {
            return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/female/${widget.pokemon.id}.png';
          }
          final sn = base?.speciesName ?? widget.pokemon.name;
          if (cosmeticEntry.name.startsWith('$sn-')) {
            final suffix = cosmeticEntry.name.substring(sn.length + 1);
            return cosmeticFormHomeUrl(widget.pokemon.id, suffix);
          }
        }
        if (cosmeticEntry.formName == 'female') {
          return '${_kBase}female/${widget.pokemon.id}.png';
        }
        return cosmeticEntry.spriteUrl ?? '${_kBase}${widget.pokemon.id}.png';
      }
      if (formEntry != null) {
        if (widget.imageType == PokedexImageType.artwork) {
          final homeOverride = _selectedFormName != null
              ? kCosmeticFormHomeUrlOverrides[_selectedFormName!]
              : null;
          return homeOverride ??
              formEntry.officialArtworkUrl ??
              '${_kBase}other/official-artwork/${widget.pokemon.id}.png';
        }
        return (formEntry.sprites?['front_default'] as String?) ??
            '${_kBase}${widget.pokemon.id}.png';
      }
    }
    return switch (widget.imageType) {
      PokedexImageType.artwork =>
        '${_kBase}other/official-artwork/${widget.pokemon.id}.png',
      PokedexImageType.sprite => '${_kBase}${widget.pokemon.id}.png',
    };
  }
}
