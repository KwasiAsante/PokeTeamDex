import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_filter.dart';
import 'package:poke_team_dex/features/pokedex/models/pokedex_image_type.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart'
    show FormBackendData, VarietyBackendData;
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart'
    show pokemonFormsProvider, pokemonVarietiesProvider;
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart' show PokemonEntry;
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';


List<(String?, String, String?)> _buildAllFormsGrid({
  required List<PokemonFormEntry> cosmeticFormEntries,
  required List<PokemonVariety> battleForms,
  required List<PokemonVariety> cosmeticVarietyForms,
  required PokemonEntry? basePokemon,
  required String baseFormLabel,
  required List<FormBackendData>? formsData,
  required List<VarietyBackendData>? varietiesData,
  required String? homeFemale,
}) {
  return <(String?, String, String?)>[
    (null, baseFormLabel, null),
    ...battleForms.map((v) {
      final full = varietiesData?.where((vd) => vd.name == v.name).firstOrNull;
      final spriteUrl = full?.spriteUrls?.officialArtwork ?? full?.spriteUrls?.home;
      return (v.name, shortFormLabel(v.name), spriteUrl);
    }),
    ...cosmeticVarietyForms.map((v) {
      final sn = basePokemon?.speciesName ?? v.name;
      final suffix = v.name.startsWith('$sn-')
          ? v.name.substring(sn.length + 1)
          : v.name;
      final full = varietiesData?.where((vd) => vd.name == v.name).firstOrNull;
      final spriteUrl =
          PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides[v.name] ??
          full?.spriteUrls?.officialArtwork ??
          full?.spriteUrls?.home;
      return (
        v.name,
        PokemonDataRegistry.instance.cosmeticFormLabels[v.name] ?? cosmeticFormLabel(suffix),
        spriteUrl,
      );
    }),
    ...cosmeticFormEntries.map((f) => (
      f.name,
      PokemonDataRegistry.instance.cosmeticFormLabels[f.name] ?? cosmeticFormLabel(f.formName),
      PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides[f.name] ??
          (() {
            final full = formsData?.where((fd) => fd.name == f.name).firstOrNull;
            return full?.spriteUrls?.officialArtwork ?? full?.spriteUrls?.home;
          })() ??
          (f.formName == 'female' ? homeFemale : null) ??
          f.spriteUrl,
    )),
  ];
}

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

    final resolvedAsync = ref.watch(resolvedPokemonProvider(widget.pokemon.id));
    final resolved = resolvedAsync.asData?.value;
    final basePokemon = resolved?.detail;
    final cosmeticFormEntries = resolved?.cosmeticForms ?? const <PokemonFormEntry>[];
    final formsData = ref.watch(pokemonFormsProvider(widget.pokemon.id)).asData?.value;
    final varietiesData = ref.watch(pokemonVarietiesProvider(widget.pokemon.id)).asData?.value;

    final selectedCosmeticEntry = _selectedFormName != null
        ? cosmeticFormEntries
            .where((f) => f.name == _selectedFormName)
            .firstOrNull
        : null;
    final formAsync = (_selectedFormName != null && selectedCosmeticEntry == null)
        ? ref.watch(pokemonByNameProvider(_selectedFormName!))
        : null;

    // Form list
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

    final allForms = _buildAllFormsGrid(
      cosmeticFormEntries: cosmeticFormEntries,
      battleForms: battleForms,
      cosmeticVarietyForms: cosmeticVarietyForms,
      basePokemon: basePokemon,
      baseFormLabel: baseFormLabel,
      formsData: formsData,
      varietiesData: varietiesData,
      homeFemale: resolved?.spriteUrls.homeFemale,
    );
    final hasFormChip = allForms.length > 1;

    // Cosmetic form entries keep base types — no gradient change needed.
    final formEntry = formAsync?.asData?.value;
    final isFormLoading = formAsync != null && formAsync.isLoading;

    final effectiveTypes = formEntry?.types ?? basePokemon?.types;
    final primaryType = effectiveTypes != null && effectiveTypes.isNotEmpty
        ? effectiveTypes[0]
        : null;
    final types = effectiveTypes ?? const <String>[];

    final typeColor = primaryType != null
        ? (PokemonTypeColors.colors[primaryType] ?? colorScheme.primary)
        : colorScheme.surfaceContainerHighest;

    final selectedFormSpriteUrls = selectedCosmeticEntry != null
        ? formsData?.where((fd) => fd.name == selectedCosmeticEntry.name).firstOrNull?.spriteUrls
        : null;
    final imageUrl = PokemonDataResolver.resolvePokedexImageUrl(
      pokemonId: widget.pokemon.id,
      baseSpecies: basePokemon?.speciesName ?? widget.pokemon.name,
      selectedFormName: _selectedFormName,
      imageType: widget.imageType,
      formEntry: formEntry,
      cosmeticEntry: selectedCosmeticEntry,
      filter: const PokedexFilter(),
      spriteUrls: resolved?.spriteUrls,
      formSpriteUrls: selectedFormSpriteUrls,
    );

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
                          builder: (ctx) => Consumer(
                            builder: (ctx, liveRef, _) {
                              final liveFormsData = liveRef.watch(pokemonFormsProvider(widget.pokemon.id)).asData?.value;
                              final liveVarietiesData = liveRef.watch(pokemonVarietiesProvider(widget.pokemon.id)).asData?.value;
                              final liveAllForms = _buildAllFormsGrid(
                                cosmeticFormEntries: cosmeticFormEntries,
                                battleForms: battleForms,
                                cosmeticVarietyForms: cosmeticVarietyForms,
                                basePokemon: basePokemon,
                                baseFormLabel: baseFormLabel,
                                formsData: liveFormsData,
                                varietiesData: liveVarietiesData,
                                homeFemale: resolved?.spriteUrls.homeFemale,
                              );
                              return FormPickerSheet(
                                allForms: liveAllForms,
                                baseSpriteUrl: basePokemon?.officialArtworkUrl
                                    ?? resolved?.spriteUrls.home,
                                selectedFormName: _selectedFormName,
                                shiny: false,
                                onSelect: (name) {
                                  setState(() => _selectedFormName = name);
                                  Navigator.pop(ctx);
                                },
                              );
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

}
