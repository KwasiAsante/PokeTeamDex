
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart'
    show teamRepositoryProvider, teamSlotRepositoryProvider;
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart'
    show teamSlotsProvider;
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/format/format_service.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart'
    show MoveSummary, FormBackendData, VarietyBackendData;
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart'
    show pokemonMovesProvider, pokemonFlavorTextProvider,
         pokemonFormsProvider, pokemonVarietiesProvider;
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/stat_bar.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';

/// Derives a display label from a PokéAPI cosmetic form name.
/// e.g. "red-flower" → "Red Flower", "sandy" → "Sandy", "a" → "A".

class PokemonDetailScreen extends ConsumerStatefulWidget {
  final int pokemonId;
  /// When navigating from an evolution chain node, pre-select this form
  /// (e.g. "zigzagoon-galar"). pokemonId must still be the species ID (≤ 1025).
  final String? initialFormName;
  const PokemonDetailScreen({super.key, required this.pokemonId, this.initialFormName});

  @override
  ConsumerState<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends ConsumerState<PokemonDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _shiny = false;
  String? _selectedFormName; // null = base form
  String? _selectedCosmeticFormName; // null = base form sprite

  void _selectBattleForm(String? formName) {
    setState(() {
      _selectedFormName = formName;
      _selectedCosmeticFormName = null;
    });
  }

  // Narrow layout — horizontal TabBar
  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Stats'),
    Tab(text: 'Abilities'),
    Tab(text: 'Moves'),
    Tab(text: 'Evolutions'),
    Tab(text: 'Forms'),
    Tab(text: 'Locations'),
    Tab(text: 'Teams'),
  ];

  // Wide layout — left rail labels + icons
  static const _railLabels = [
    'Overview', 'Stats', 'Abilities', 'Moves',
    'Evolutions', 'Forms', 'Locations', 'Teams',
  ];
  static const _railIcons = [
    Icons.info_outline,
    Icons.bar_chart_outlined,
    Icons.psychology_outlined,
    Icons.bolt_outlined,
    Icons.account_tree_outlined,
    Icons.style_outlined,
    Icons.location_on_outlined,
    Icons.groups_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    if (widget.initialFormName != null) {
      _selectedFormName = widget.initialFormName;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Widget> _tabChildren(
    PokemonEntry basePokemon,
    PokemonEntry effectivePokemon,
    AsyncValue<PokemonSpeciesEntry> speciesAsync,
  ) => [
    _OverviewTab(pokemon: effectivePokemon, speciesAsync: speciesAsync, pokemonId: effectivePokemon.id),
    _StatsTab(pokemon: effectivePokemon),
    _AbilitiesTab(pokemon: effectivePokemon),
    _MovesTab(pokemon: effectivePokemon, pokemonId: effectivePokemon.id),
    _EvolutionsTab(speciesAsync: speciesAsync, selectedFormName: _selectedFormName),
    _FormsTab(speciesAsync: speciesAsync, selectedFormName: _selectedFormName),
    _LocationsTab(pokemonId: effectivePokemon.id),
    _TeamsTab(pokemonId: widget.pokemonId, pokemon: basePokemon, selectedFormName: _selectedFormName),
  ];

  @override
  Widget build(BuildContext context) {
    final resolvedAsync = ref.watch(resolvedPokemonProvider(widget.pokemonId));
    final formAsync = _selectedFormName != null
        ? ref.watch(pokemonByNameProvider(_selectedFormName!))
        : null;

    // Conditionally fetch full sprite data — same pattern as list tile.
    final resolvedData = resolvedAsync.asData?.value;
    final hasCosmeticForms = resolvedData?.cosmeticForms.isNotEmpty == true;
    final hasCosmeticVarieties = resolvedData != null &&
        resolvedData.species.varieties.any((v) =>
            !v.isDefault &&
            PokemonDataRegistry.instance.cosmeticVarietyNames.contains(v.name));
    final formsData = hasCosmeticForms
        ? ref.watch(pokemonFormsProvider(widget.pokemonId)).asData?.value
        : null;
    final varietiesData = hasCosmeticVarieties
        ? ref.watch(pokemonVarietiesProvider(widget.pokemonId)).asData?.value
        : null;

    final isWide = MediaQuery.sizeOf(context).width > 840;

    return resolvedAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(resolvedPokemonProvider(widget.pokemonId)),
        ),
      ),
      data: (resolved) {
        final basePokemon = resolved.detail;
        // Wrap species so child widgets that accept AsyncValue<PokemonSpeciesEntry>
        // receive it in the data state — the whole resolved provider is already done.
        final speciesAsync = AsyncData<PokemonSpeciesEntry>(resolved.species);
        final effectivePokemon = formAsync?.asData?.value ?? basePokemon;
        final primaryType = effectivePokemon.types.isNotEmpty
            ? effectivePokemon.types[0]
            : 'normal';
        final headerColor =
            PokemonTypeColors.colors[primaryType] ?? Theme.of(context).colorScheme.primary;
        final species = resolved.species;
        final battleForms = battleMeaningfulForms(species.varieties);
        // Derive the correct base form label:
        // • Gender-split species (all forms end in -female) → "Male"
        // • Species with regional forms (any form has a regional suffix) → regional adjective
        // • Non-regional non-gender form variants (Rotom appliances, Lycanroc, Urshifu…) → "Base"
        final baseFormLabel = computeBaseFormLabel(
          basePokemon.name,
          species.generationName,
          battleForms,
        );
        // Cosmetic forms are already fetched, patched, and filtered by
        // resolvedPokemonProvider — no further processing needed here.
        final cosmeticFormsBase = resolved.cosmeticForms;
        const cosmeticFormsLoading = false;

        // Variety-based cosmetic chips are only shown for the BASE form.
        // When a regional battle form is selected (e.g. Hisuian Basculin),
        // Unovan cosmetic variants (Blue-Striped) are not relevant.
        // Uses pokemonVarietiesProvider (already watched above) instead of
        // per-variety pokemonByNameProvider calls.
        final varietyCosmeticForms = <PokemonFormEntry>[];
        if (_selectedFormName == null) {
          for (final variety in species.varieties) {
            if (variety.isDefault) continue;
            if (!PokemonDataRegistry.instance.cosmeticVarietyNames.contains(variety.name)) continue;
            final vd = varietiesData?.where((v) => v.name == variety.name).firstOrNull;
            if (vd == null) continue; // provider still loading; widget rebuilds when it does
            final sn = basePokemon.speciesName ?? basePokemon.name;
            final formName = variety.name.startsWith('$sn-')
                ? variety.name.substring(sn.length + 1)
                : variety.name;
            varietyCosmeticForms.add(PokemonFormEntry(
              id: vd.pokemonId,
              name: variety.name,
              formName: formName,
              isDefault: false,
              spriteUrl: vd.spriteUrls?.gameFront ?? vd.spriteUrls?.home,
              spriteShinyUrl: vd.spriteUrls?.gameFrontShiny ?? vd.spriteUrls?.homeShiny,
              officialArtworkUrl: vd.spriteUrls?.officialArtwork,
              officialArtworkShinyUrl: vd.spriteUrls?.officialArtworkShiny,
            ));
          }
        }

        // cosmeticFormsBase (from resolvedPokemonProvider) already contains the
        // synthetic female entry for cosmeticGenderDiffPokemon species.
        final cosmeticForms = [...cosmeticFormsBase, ...varietyCosmeticForms];

        return isWide
            ? _buildWideLayout(context, basePokemon, effectivePokemon, speciesAsync, headerColor, battleForms, baseFormLabel, cosmeticForms, cosmeticFormsLoading, formsData)
            : _buildNarrowLayout(context, basePokemon, effectivePokemon, speciesAsync, headerColor, battleForms, baseFormLabel, cosmeticForms, cosmeticFormsLoading, formsData);
      },
    );
  }

  // ── Narrow layout (≤ 840dp) ── SliverAppBar + horizontal TabBar ──────────────

  Widget _buildNarrowLayout(
    BuildContext context,
    PokemonEntry basePokemon,
    PokemonEntry effectivePokemon,
    AsyncValue<PokemonSpeciesEntry> speciesAsync,
    Color headerColor,
    List<PokemonVariety> battleForms,
    String baseFormLabel,
    List<PokemonFormEntry> cosmeticForms,
    bool cosmeticFormsLoading,
    List<FormBackendData>? formsData,
  ) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _DetailSliverAppBar(
            basePokemon: basePokemon,
            effectivePokemon: effectivePokemon,
            battleForms: battleForms,
            baseFormLabel: baseFormLabel,
            selectedFormName: _selectedFormName,
            onFormSelect: _selectBattleForm,
            headerColor: headerColor,
            shiny: _shiny,
            onShinyToggle: () => setState(() => _shiny = !_shiny),
            tabController: _tabController,
            tabs: _tabs,
            cosmeticForms: cosmeticForms,
            cosmeticFormsLoading: cosmeticFormsLoading,
            selectedCosmeticFormName: _selectedCosmeticFormName,
            onCosmeticFormSelect: (name) => setState(() => _selectedCosmeticFormName = name),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _tabChildren(basePokemon, effectivePokemon, speciesAsync),
        ),
      ),
    );
  }

  // ── Wide layout (> 840dp) ── AppBar + left rail + content panel ──────────────

  Widget _buildWideLayout(
    BuildContext context,
    PokemonEntry basePokemon,
    PokemonEntry effectivePokemon,
    AsyncValue<PokemonSpeciesEntry> speciesAsync,
    Color headerColor,
    List<PokemonVariety> battleForms,
    String baseFormLabel,
    List<PokemonFormEntry> cosmeticForms,
    bool cosmeticFormsLoading,
    List<FormBackendData>? formsData,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final wideSelectedCosmetic = _selectedCosmeticFormName != null
        ? cosmeticForms.where((f) => f.name == _selectedCosmeticFormName).firstOrNull
        : null;
    String? cosmeticHomeUrlFor(PokemonFormEntry? form) {
      if (form == null) return null;
      // Backend-resolved sprite URLs (highest quality, CORS-safe).
      final fd = formsData?.where((f) => f.name == form.name).firstOrNull;
      final backendUrl = fd?.spriteUrls?.officialArtwork ?? fd?.spriteUrls?.home;
      if (backendUrl != null) return backendUrl;
      // Variety-based forms have official artwork URL from pokemonVarietiesProvider.
      if (form.officialArtworkUrl != null) return form.officialArtworkUrl;
      final override = PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides[form.name];
      if (override != null) return override;
      if (form.formName == 'female') {
        return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/female/${basePokemon.id}.png';
      }
      final baseName = basePokemon.name;
      if (!form.name.startsWith('$baseName-')) return form.spriteUrl;
      final suffix = form.name.substring(baseName.length + 1);
      return cosmeticFormHomeUrl(basePokemon.id, suffix);
    }
    String? cosmeticHomeShinyUrlFor(PokemonFormEntry? form) {
      if (form == null) return null;
      final fd = formsData?.where((f) => f.name == form.name).firstOrNull;
      final backendShinyUrl = fd?.spriteUrls?.officialArtworkShiny ?? fd?.spriteUrls?.homeShiny;
      if (backendShinyUrl != null) return backendShinyUrl;
      if (form.officialArtworkShinyUrl != null) return form.officialArtworkShinyUrl;
      if (form.formName == 'female') {
        return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/female/${basePokemon.id}.png';
      }
      final baseName = basePokemon.name;
      if (!form.name.startsWith('$baseName-')) return form.spriteShinyUrl;
      final suffix = form.name.substring(baseName.length + 1);
      return cosmeticFormHomeShinyUrl(basePokemon.id, suffix);
    }

    final wideHomeUrl = cosmeticHomeUrlFor(wideSelectedCosmetic);
    final wideHomeShiny = cosmeticHomeShinyUrlFor(wideSelectedCosmetic);
    final wideSpriteUrl = wideSelectedCosmetic != null
        ? (_shiny ? (wideSelectedCosmetic.spriteShinyUrl ?? wideSelectedCosmetic.spriteUrl) : wideSelectedCosmetic.spriteUrl)
        : null;
    final wideBaseOverride = wideSelectedCosmetic == null
        ? PokemonDataRegistry.instance.baseFormCosmeticHomeUrls[basePokemon.name]
        : null;
    final wideDisplayUrl = wideHomeUrl
        ?? (_shiny ? null : wideBaseOverride?.homeUrl)
        ?? effectivePokemon.officialArtworkUrl;
    final wideShinyUrl = wideHomeShiny
        ?? (_shiny ? wideBaseOverride?.shinyUrl : null)
        ?? effectivePokemon.officialArtworkShinyUrl;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(
          '${basePokemon.displayId()}  ${basePokemon.displaySpeciesName}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          FavoriteButton(pokemonId: basePokemon.id),
          if (battleForms.isNotEmpty)
            _FormBadge(
              battleForms: battleForms,
              baseFormLabel: baseFormLabel,
              baseSpriteUrl: basePokemon.officialArtworkUrl,
              baseShinyUrl: basePokemon.officialArtworkShinyUrl,
              selectedFormName: _selectedFormName,
              shiny: _shiny,
              onSelect: _selectBattleForm,
            ),
          IconButton(
            tooltip: _shiny ? 'Show default' : 'Show shiny',
            icon: Icon(
              Icons.auto_awesome,
              color: _shiny ? Colors.yellowAccent : Colors.white70,
            ),
            onPressed: () => setState(() => _shiny = !_shiny),
          ),
          const ConnectivityStatusButton(),
          const SettingsButton(),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left rail ────────────────────────────────────────────────────────
          Semantics(
            container: true,
            label: 'Pokémon navigation',
            child: SizedBox(
            width: 220,
            child: Column(
              children: [
                // Sprite + type header
                Container(
                  width: double.infinity,
                  color: headerColor.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'pokemon-sprite-${basePokemon.id}',
                        child: wideSelectedCosmetic != null && wideSpriteUrl != null
                            ? _CosmeticFormHeaderSprite(
                                homeUrl: _shiny ? (wideHomeShiny ?? wideHomeUrl) : wideHomeUrl,
                                fallbackSpriteUrl: wideSpriteUrl,
                                size: 140,
                              )
                            : PokemonSprite(
                                defaultUrl: wideDisplayUrl,
                                shinyUrl: wideShinyUrl,
                                shiny: _shiny,
                                size: 140,
                              ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        basePokemon.displaySpeciesName,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        alignment: WrapAlignment.center,
                        children: effectivePokemon.types
                            .map((t) => TypeBadge(type: t))
                            .toList(),
                      ),
                      if (cosmeticForms.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _CosmeticFormRow(
                          forms: cosmeticForms,
                          selectedFormName: _selectedCosmeticFormName,
                          shiny: _shiny,
                          onSelect: (name) => setState(() => _selectedCosmeticFormName = name),
                          baseHomeUrl: _shiny
                              ? PokemonDataRegistry.instance.baseFormCosmeticHomeUrls[basePokemon.name]?.shinyUrl
                              : PokemonDataRegistry.instance.baseFormCosmeticHomeUrls[basePokemon.name]?.homeUrl,
                          baseLabel: PokemonDataRegistry.instance.baseFormNameOverrides[basePokemon.name],
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // Tab list
                Expanded(
                  child: ListenableBuilder(
                    listenable: _tabController,
                    builder: (context, _) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: List.generate(_railLabels.length, (i) {
                          final selected = _tabController.index == i;
                          return ListTile(
                            selected: selected,
                            selectedTileColor:
                                colorScheme.primaryContainer.withValues(alpha: 0.35),
                            selectedColor: colorScheme.primary,
                            leading: Icon(
                              _railIcons[i],
                              size: 20,
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              _railLabels[i],
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                            onTap: () => _tabController.animateTo(i),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
            ), // closes Semantics 'Pokémon navigation'
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // ── Content panel ─────────────────────────────────────────────────────
          Expanded(
            child: Semantics(
              container: true,
              label: 'Pokémon details',
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: _tabChildren(basePokemon, effectivePokemon, speciesAsync),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sliver AppBar ─────────────────────────────────────────────────────────────

class _DetailSliverAppBar extends StatelessWidget {
  final PokemonEntry basePokemon;
  final PokemonEntry effectivePokemon;
  final List<PokemonVariety> battleForms;
  final String baseFormLabel;
  final String? selectedFormName;
  final void Function(String?) onFormSelect;
  final Color headerColor;
  final bool shiny;
  final VoidCallback onShinyToggle;
  final TabController tabController;
  final List<Tab> tabs;
  final List<PokemonFormEntry> cosmeticForms;
  final bool cosmeticFormsLoading;
  final String? selectedCosmeticFormName;
  final void Function(String?) onCosmeticFormSelect;

  const _DetailSliverAppBar({
    required this.basePokemon,
    required this.effectivePokemon,
    required this.battleForms,
    required this.baseFormLabel,
    required this.selectedFormName,
    required this.onFormSelect,
    required this.headerColor,
    required this.shiny,
    required this.onShinyToggle,
    required this.tabController,
    required this.tabs,
    required this.cosmeticForms,
    required this.cosmeticFormsLoading,
    required this.selectedCosmeticFormName,
    required this.onCosmeticFormSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve the cosmetic form to display (if one is selected).
    final selectedCosmetic = selectedCosmeticFormName != null
        ? cosmeticForms.where((f) => f.name == selectedCosmeticFormName).firstOrNull
        : null;

    // Resolve header display URL for a cosmetic form.
    // Priority: backend-resolved → variety artwork → HOME override → HOME → sprite.
    String? cosmeticUrlFor(PokemonFormEntry? form) {
      if (form == null) return null;
      // Backend-resolved sprite URLs (highest quality, CORS-safe).
      final fd = formsData?.where((f) => f.name == form.name).firstOrNull;
      final backendUrl = fd?.spriteUrls?.officialArtwork ?? fd?.spriteUrls?.home;
      if (backendUrl != null) return backendUrl;
      // Variety-based forms have official artwork from pokemonVarietiesProvider.
      if (form.officialArtworkUrl != null) return form.officialArtworkUrl;
      final override = PokemonDataRegistry.instance.cosmeticFormHomeUrlOverrides[form.name];
      if (override != null) return override;
      if (form.formName == 'female') {
        return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/female/${basePokemon.id}.png';
      }
      final baseName = basePokemon.name;
      if (!form.name.startsWith('$baseName-')) return form.spriteUrl;
      final suffix = form.name.substring(baseName.length + 1);
      return cosmeticFormHomeUrl(basePokemon.id, suffix);
    }
    String? cosmeticShinyUrlFor(PokemonFormEntry? form) {
      if (form == null) return null;
      final fd = formsData?.where((f) => f.name == form.name).firstOrNull;
      final backendShinyUrl = fd?.spriteUrls?.officialArtworkShiny ?? fd?.spriteUrls?.homeShiny;
      if (backendShinyUrl != null) return backendShinyUrl;
      if (form.officialArtworkShinyUrl != null) return form.officialArtworkShinyUrl;
      final shinyOverride = PokemonDataRegistry.instance.cosmeticFormHomeShinyUrlOverrides[form.name];
      if (shinyOverride != null) return shinyOverride;
      if (form.formName == 'female') {
        return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/female/${basePokemon.id}.png';
      }
      final baseName = basePokemon.name;
      if (!form.name.startsWith('$baseName-')) return form.spriteShinyUrl;
      final suffix = form.name.substring(baseName.length + 1);
      return cosmeticFormHomeShinyUrl(basePokemon.id, suffix);
    }

    // When a cosmetic form is selected: try HOME artwork, fall back to the
    // form's pixel sprite (handles forms with no HOME artwork like Pichu Spiky-Eared).
    final cosmeticHomeUrl = cosmeticUrlFor(selectedCosmetic);
    final cosmeticHomeShiny = cosmeticShinyUrlFor(selectedCosmetic);
    final cosmeticSpriteUrl = selectedCosmetic != null
        ? (shiny ? (selectedCosmetic.spriteShinyUrl ?? selectedCosmetic.spriteUrl) : selectedCosmetic.spriteUrl)
        : null;
    // When no cosmetic form is selected and there's a base HOME override
    // (e.g. Unown shows form-A HOME artwork instead of official-artwork form-F).
    final baseHomeOverride = selectedCosmetic == null
        ? PokemonDataRegistry.instance.baseFormCosmeticHomeUrls[basePokemon.name]
        : null;
    final displayDefaultUrl = cosmeticHomeUrl
        ?? (shiny ? null : baseHomeOverride?.homeUrl)
        ?? effectivePokemon.officialArtworkUrl;
    final displayShinyUrl = cosmeticHomeShiny
        ?? (shiny ? baseHomeOverride?.shinyUrl : null)
        ?? effectivePokemon.officialArtworkShinyUrl;

    // Expand header height when cosmetic chips are present.
    final expandedHeight = cosmeticForms.isNotEmpty ? 324.0 : 280.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      leading: BackButton(onPressed: () => context.pop()),
      title: Text(
        '${basePokemon.displayId()}  ${basePokemon.displaySpeciesName}',
        style: const TextStyle(color: Colors.white),
      ),
      actions: [
        FavoriteButton(pokemonId: basePokemon.id),
        if (battleForms.isNotEmpty)
          _FormBadge(
            battleForms: battleForms,
            baseFormLabel: baseFormLabel,
            baseSpriteUrl: basePokemon.officialArtworkUrl,
            baseShinyUrl: basePokemon.officialArtworkShinyUrl,
            selectedFormName: selectedFormName,
            shiny: shiny,
            onSelect: onFormSelect,
          ),
        IconButton(
          tooltip: shiny ? 'Show default' : 'Show shiny',
          icon: Icon(
            Icons.auto_awesome,
            color: shiny ? Colors.yellowAccent : Colors.white70,
          ),
          onPressed: onShinyToggle,
        ),
        const ConnectivityStatusButton(),
        const SettingsButton(),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: headerColor.withValues(alpha: 0.85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'pokemon-sprite-${basePokemon.id}',
                child: selectedCosmetic != null && cosmeticSpriteUrl != null
                    ? _CosmeticFormHeaderSprite(
                        homeUrl: shiny ? (cosmeticHomeShiny ?? cosmeticHomeUrl) : cosmeticHomeUrl,
                        fallbackSpriteUrl: cosmeticSpriteUrl,
                        size: 200,
                      )
                    : PokemonSprite(
                        defaultUrl: displayDefaultUrl,
                        shinyUrl: displayShinyUrl,
                        shiny: shiny,
                        size: 200,
                      ),
              ),
              if (cosmeticFormsLoading) ...[
                const SizedBox(height: 6),
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ),
              ] else if (cosmeticForms.isNotEmpty) ...[
                const SizedBox(height: 6),
                _CosmeticFormRow(
                  forms: cosmeticForms,
                  selectedFormName: selectedCosmeticFormName,
                  shiny: shiny,
                  onSelect: onCosmeticFormSelect,
                  baseHomeUrl: shiny
                      ? PokemonDataRegistry.instance.baseFormCosmeticHomeUrls[basePokemon.name]?.shinyUrl
                      : PokemonDataRegistry.instance.baseFormCosmeticHomeUrls[basePokemon.name]?.homeUrl,
                  baseLabel: PokemonDataRegistry.instance.baseFormNameOverrides[basePokemon.name],
                ),
              ],
              // Bottom spacer keeps content clear of the pinned TabBar (~48 dp).
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      bottom: TabBar(
        controller: tabController,
        tabs: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        dividerColor: Colors.transparent,
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final PokemonEntry pokemon;
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;
  final int pokemonId;

  const _OverviewTab({required this.pokemon, required this.speciesAsync, required this.pokemonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavorAsync = ref.watch(pokemonFlavorTextProvider(pokemonId));
    final flavorEntries = flavorAsync.asData?.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Types
          Row(
            children: [
              ...pokemon.types.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TypeBadge(type: t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Physical info
          _InfoGrid(rows: [
            ('Height', pokemon.displayHeight()),
            ('Weight', pokemon.displayWeight()),
            ('Base Exp', pokemon.baseExperience?.toString() ?? '—'),
          ]),
          const SizedBox(height: 16),

          // Species data
          speciesAsync.when(
            loading: () => const LoadingState(message: 'Loading species data…'),
            error: (e, _) => ErrorState(error: e),
            data: (species) => _SpeciesSection(species: species, flavorEntries: flavorEntries),
          ),
        ],
      ),
    );
  }
}

class _SpeciesSection extends StatelessWidget {
  final PokemonSpeciesEntry species;
  /// Pre-fetched English flavor text entries from [pokemonFlavorTextProvider].
  /// When provided, these replace [species.flavorTextEntries] so that flavor
  /// text is loaded lazily from the backend rather than from the slim resolved
  /// response. When null (still loading), falls back to species entries.
  final List<FlavorTextEntry>? flavorEntries;
  const _SpeciesSection({required this.species, this.flavorEntries});

  @override
  Widget build(BuildContext context) {
    final englishEntries = flavorEntries ??
        species.flavorTextEntries
            .where((f) => f.language == 'en')
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (species.genus != null) ...[
          Text(species.genus!, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
        ],

        _InfoGrid(rows: [
          ('Generation', species.generationLabel),
          ('Capture Rate', species.captureRate?.toString() ?? '—'),
          ('Base Happiness', species.baseHappiness?.toString() ?? '—'),
          ('Growth Rate', _fmtName(species.growthRate)),
          ('Gender', species.genderDisplay()),
          ('Hatch Steps', species.hatchSteps > 0 ? '~${species.hatchSteps}' : '—'),
          ('Egg Groups', species.eggGroups.map(_fmtName).join(', ')),
        ]),
        const SizedBox(height: 16),

        if (species.isBaby || species.isLegendary || species.isMythical)
          Wrap(
            spacing: 6,
            children: [
              if (species.isBaby) const Chip(label: Text('Baby')),
              if (species.isLegendary) const Chip(label: Text('Legendary')),
              if (species.isMythical) const Chip(label: Text('Mythical')),
            ],
          ),

        if (englishEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Pokédex Entries', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...englishEntries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtName(e.version),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(e.text, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

}

// ── Shared helpers ────────────────────────────────────────────────────────────

String _fmtName(String? raw) {
  if (raw == null) return '—';
  return raw
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}

class _InfoGrid extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: rows
          .map(
            (r) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 6),
                  child: Text(
                    r.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(r.$2, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final PokemonEntry pokemon;
  const _StatsTab({required this.pokemon});

  // Canonical stat order and short labels
  static const _statMeta = [
    ('hp', 'HP'),
    ('attack', 'Atk'),
    ('defense', 'Def'),
    ('special-attack', 'SpA'),
    ('special-defense', 'SpD'),
    ('speed', 'Spe'),
  ];

  int _base(String statName) => pokemon.stats[statName] ?? 0;

  @override
  Widget build(BuildContext context) {
    final bases = _statMeta.map((m) => _base(m.$1)).toList();
    final bst = bases.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat bars — staggered fill animation
          ...List.generate(_statMeta.length, (i) {
            return StatBar(
              label: _statMeta[i].$2,
              value: bases[i],
              delay: Duration(milliseconds: i * 70),
            );
          }),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 52,
                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(bst.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const Divider(height: 32),

          // Min / Max table
          Text('Stat Ranges', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Min: IV 0, EV 0, hindering nature  •  Max: IV 31, EV 252, helpful nature',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          _StatRangeTable(bases: bases, statMeta: _statMeta),
        ],
      ),
    );
  }
}

class _StatRangeTable extends StatelessWidget {
  final List<int> bases;
  final List<(String, String)> statMeta;

  const _StatRangeTable({required this.bases, required this.statMeta});

  int _hp(int base, int iv, int ev, int level) =>
      ((2 * base + iv + (ev ~/ 4)) * level ~/ 100) + level + 10;

  int _stat(int base, int iv, int ev, int level, double nature) =>
      (((2 * base + iv + (ev ~/ 4)) * level ~/ 100 + 5) * nature).floor();

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    final cellStyle = Theme.of(context).textTheme.bodySmall;

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          children: [
            _cell('', headerStyle, bottom: 6),
            _cell('Min 50', headerStyle, bottom: 6, align: TextAlign.center),
            _cell('Max 50', headerStyle, bottom: 6, align: TextAlign.center),
            _cell('Min 100', headerStyle, bottom: 6, align: TextAlign.center),
            _cell('Max 100', headerStyle, bottom: 6, align: TextAlign.center),
          ],
        ),
        // Rows
        ...List.generate(statMeta.length, (i) {
          final name = statMeta[i].$1;
          final label = statMeta[i].$2;
          final base = bases[i];
          final isHp = name == 'hp';

          final min50 = isHp ? _hp(base, 0, 0, 50) : _stat(base, 0, 0, 50, 0.9);
          final max50 = isHp ? _hp(base, 31, 252, 50) : _stat(base, 31, 252, 50, 1.1);
          final min100 = isHp ? _hp(base, 0, 0, 100) : _stat(base, 0, 0, 100, 0.9);
          final max100 = isHp ? _hp(base, 31, 252, 100) : _stat(base, 31, 252, 100, 1.1);

          return TableRow(
            children: [
              _cell(label, cellStyle?.copyWith(fontWeight: FontWeight.w600), top: 6, bottom: 6),
              _cell(min50.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
              _cell(max50.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
              _cell(min100.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
              _cell(max100.toString(), cellStyle, top: 6, bottom: 6, align: TextAlign.center),
            ],
          );
        }),
      ],
    );
  }

  static Widget _cell(
    String text,
    TextStyle? style, {
    double top = 0,
    double bottom = 0,
    TextAlign align = TextAlign.start,
  }) =>
      Padding(
        padding: EdgeInsets.only(top: top, bottom: bottom, right: 8),
        child: Text(text, style: style, textAlign: align),
      );
}

// ── Moves Tab ────────────────────────────────────────────────────────────────

/// Groups the raw moves list from PokemonEntry by learn method, with optional
/// version-group filter. Move details are fetched lazily per row.
class _MovesTab extends ConsumerStatefulWidget {
  final PokemonEntry pokemon;
  final int pokemonId;
  const _MovesTab({required this.pokemon, required this.pokemonId});

  @override
  ConsumerState<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends ConsumerState<_MovesTab> {
  String? _selectedVersion;

  static const _methodOrder = ['level-up', 'machine', 'egg', 'tutor', 'event'];
  static const _methodLabels = {
    'level-up': 'Level Up',
    'machine': 'TM / HM',
    'egg': 'Egg Moves',
    'tutor': 'Move Tutor',
    'event': 'Event Moves',
  };

  // Canonical release order for version-group chips.
  static const _vgOrder = [
    'red-blue',
    'yellow',
    'gold-silver',
    'crystal',
    'ruby-sapphire',
    'firered-leafgreen',
    'emerald',
    'diamond-pearl',
    'platinum',
    'heartgold-soulsilver',
    'black-white',
    'black-2-white-2',
    'x-y',
    'omega-ruby-alpha-sapphire',
    'sun-moon',
    'ultra-sun-ultra-moon',
    'lets-go-pikachu-lets-go-eevee',
    'sword-shield',
    'the-isle-of-armor',
    'the-crown-tundra',
    'brilliant-diamond-and-shining-pearl',
    'legends-arceus',
    'scarlet-violet',
    'the-teal-mask',
    'the-indigo-disk',
  ];

  /// All unique version-group names found in the moves list, sorted by release date.
  List<String> _versions(List<MoveSummary> moves) {
    final seen = <String>{};
    for (final m in moves) {
      for (final vgd in m.learnDetails) {
        seen.add(vgd.versionGroup);
      }
    }
    return seen.toList()
      ..sort((a, b) {
        final ai = _vgOrder.indexOf(a);
        final bi = _vgOrder.indexOf(b);
        // Known entries sort by position (descending); unknown entries go to the end.
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return bi.compareTo(ai); // reversed: latest first
      });
  }

  /// Moves grouped by learn method for the selected version group, supplemented
  /// with an "Event Moves" group for genuine event/gift-Pokémon moves the PS
  /// detailed-learnset source knows about that PokéAPI has no
  /// `move_learn_method` category for at all (e.g. Pokémon Crystal's gift
  /// Dratini knowing Extreme Speed from the start). [psIdToName] recovers a
  /// displayable PokéAPI move name + id for those PS-only entries; [gen] and
  /// [formatService] are the generation/service to query — both null when the
  /// service isn't ready yet or the selected version has no known generation.
  Map<String, List<_MoveRow>> _grouped(
    String? version,
    List<MoveSummary> moves, {
    required Map<String, String> psIdToName,
    int? gen,
    FormatService? formatService,
  }) {
    final groups = <String, List<_MoveRow>>{};
    for (final m in moves) {
      final moveName = m.name;
      for (final vgd in m.learnDetails) {
        final vg = vgd.versionGroup;
        if (version != null && vg != version) continue;
        final method = vgd.method;
        final level = vgd.level;
        groups.putIfAbsent(method, () => []);
        // Avoid duplicates within same method
        if (!groups[method]!.any((r) => r.moveName == moveName)) {
          groups[method]!.add(_MoveRow(moveName: moveName, level: level));
        }
      }
    }
    // Sort level-up by level
    groups['level-up']?.sort((a, b) => a.level.compareTo(b.level));

    if (gen != null && formatService != null && formatService.isInitialized) {
      final alreadyShown = {
        for (final rows in groups.values) for (final r in rows) r.moveName,
      };
      final eventRows = <_MoveRow>[];
      for (final id in formatService.eventMovesForGen(widget.pokemon.name, gen)) {
        final name = _resolveEventMoveName(id, psIdToName, formatService);
        if (name == null || alreadyShown.contains(name)) continue;
        eventRows.add(_MoveRow(moveName: name, level: 0));
      }
      if (eventRows.isNotEmpty) {
        eventRows.sort((a, b) => a.moveName.compareTo(b.moveName));
        groups['event'] = eventRows;
      }
    }
    return groups;
  }

  /// Maps PS move id (e.g. "extremespeed") → PokéAPI move name (e.g.
  /// "extreme-speed") for every move PokéAPI lists for [current] or any
  /// [ancestorSets] member, across all generations. Needed to recover a
  /// displayable name + `moveProvider`-fetchable id for moves that
  /// [FormatService.eventMovesForGen] surfaces by PS id — those moves do
  /// appear in PokéAPI's data (just attributed to a different generation or
  /// method there), so this reverse-lookup virtually always resolves.
  static Map<String, String> _psIdToNameMap(
    List<MoveSummary> current,
    List<({String speciesName, List<MoveSummary> moves})> ancestorSets,
  ) {
    final map = <String, String>{};
    for (final m in current) {
      map.putIfAbsent(_toPsId(m.name), () => m.name);
    }
    for (final ancestor in ancestorSets) {
      for (final m in ancestor.moves) {
        map.putIfAbsent(_toPsId(m.name), () => m.name);
      }
    }
    return map;
  }

  /// Resolves a PS move id surfaced by [FormatService.eventMovesForGen] to a
  /// displayable PokéAPI-style move name. Tries [psIdToName] first (the move
  /// appears in PokéAPI's data for the species or an ancestor — just under a
  /// different generation/method); falls back to PS's own move database for
  /// moves PokéAPI has zero record of for the line at all — e.g. Eevee's
  /// Gen-2 event-exclusive Growth (a Stadium-2/gift encounter, unlike
  /// Dratini's Extreme Speed which PokéAPI at least lists via a later-gen
  /// egg/tutor method). PS names preserve official punctuation/hyphenation
  /// ("King's Shield", "U-turn"), so lower-casing, hyphenating whitespace and
  /// dropping apostrophes reliably reproduces the PokéAPI slug.
  static String? _resolveEventMoveName(
    String psId,
    Map<String, String> psIdToName,
    FormatService? formatService,
  ) {
    final known = psIdToName[psId];
    if (known != null) return known;
    final entry = formatService?.moveDetail(psId);
    if (entry == null) return null;
    return entry.name.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
  }

  /// For each ancestor, returns exclusive move rows learnable in [selectedVg]
  /// that the current Pokémon cannot learn in [selectedVg] — including
  /// genuine event/gift-exclusive moves from [FormatService.eventMovesForGen]
  /// (e.g. Dragonair/Dragonite's "Prior Evolution Exclusive ▸ Dratini" group
  /// surfacing Extreme Speed from Pokémon Crystal's gift Dratini, which
  /// PokéAPI's `move_learn_method` data has no category for at all).
  /// [psIdToName], [gen] and [formatService] mirror [_grouped]'s parameters.
  List<({String speciesName, List<_MoveRow> rows})> _buildPriorEvoGroups(
    String? selectedVg,
    List<MoveSummary> moves,
    List<({String speciesName, List<MoveSummary> moves})> ancestorSets, {
    required Map<String, String> psIdToName,
    int? gen,
    FormatService? formatService,
  }) {
    final canQueryEvents =
        gen != null && formatService != null && formatService.isInitialized;

    // Moves the current Pokémon can learn in the selected version group —
    // plus its own genuine event moves, which shouldn't be flagged as
    // "exclusive to an ancestor" just because PokéAPI's version-group data
    // doesn't carry them either.
    final currentInVg = <String>{};
    for (final m in moves) {
      final moveName = m.name;
      for (final vgd in m.learnDetails) {
        final vg = vgd.versionGroup;
        if (selectedVg == null || vg == selectedVg) {
          currentInVg.add(moveName);
          break;
        }
      }
    }
    if (canQueryEvents) {
      for (final id in formatService.eventMovesForGen(widget.pokemon.name, gen)) {
        final name = _resolveEventMoveName(id, psIdToName, formatService);
        if (name != null) currentInVg.add(name);
      }
    }

    final groups = <({String speciesName, List<_MoveRow> rows})>[];
    for (final ancestor in ancestorSets) {
      final rows = <_MoveRow>[];
      for (final m in ancestor.moves) {
        final moveName = m.name;
        if (currentInVg.contains(moveName)) continue;
        for (final vgd in m.learnDetails) {
          final vg = vgd.versionGroup;
          if (selectedVg != null && vg != selectedVg) continue;
          final level = vgd.level;
          if (!rows.any((r) => r.moveName == moveName)) {
            rows.add(_MoveRow(moveName: moveName, level: level));
          }
          break;
        }
      }
      if (canQueryEvents) {
        for (final id in formatService.eventMovesForGen(ancestor.speciesName, gen)) {
          final name = _resolveEventMoveName(id, psIdToName, formatService);
          if (name == null || currentInVg.contains(name)) continue;
          if (!rows.any((r) => r.moveName == name)) {
            rows.add(_MoveRow(moveName: name, level: 0));
          }
        }
      }
      rows.sort((a, b) => a.moveName.compareTo(b.moveName));
      if (rows.isNotEmpty) {
        groups.add((speciesName: ancestor.speciesName, rows: rows));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Watch the lazy-loaded moves from the backend provider; fall back to the
    // moves already embedded in the resolved PokemonEntry while loading.
    final movesAsync = ref.watch(pokemonMovesProvider(widget.pokemonId));
    final moves = movesAsync.asData?.value ?? widget.pokemon.moves;

    final versions = _versions(moves);
    _selectedVersion ??= versions.isNotEmpty ? versions.first : null;

    // FormatService gates on `initialize()` resolving — `allFormatsProvider`
    // is the readiness signal (mirrors the gating pattern used elsewhere).
    // Until it resolves, `formatService`/`gen` stay null and the event-move
    // supplementary lookups in `_grouped`/`_buildPriorEvoGroups` are skipped.
    final formatsReady = ref.watch(allFormatsProvider).hasValue;
    final formatService = formatsReady ? ref.read(formatServiceProvider) : null;
    final gen = _selectedVersion != null
        ? genForVersionGroup(_selectedVersion!)
        : null;

    final priorEvoAsync = ref.watch(priorEvoMoveSetsProvider(widget.pokemon.id));
    final ancestorSets = priorEvoAsync.whenOrNull(data: (sets) => sets) ?? const [];
    final psIdToName = _psIdToNameMap(moves, ancestorSets);

    final grouped = _grouped(
      _selectedVersion,
      moves,
      psIdToName: psIdToName,
      gen: gen,
      formatService: formatService,
    );

    final priorEvoGroups = priorEvoAsync.whenOrNull(
      data: (sets) => _buildPriorEvoGroups(
        _selectedVersion, moves, sets,
        psIdToName: psIdToName,
        gen: gen,
        formatService: formatService,
      ),
    ) ?? const [];
    final priorEvoLoading = priorEvoAsync.isLoading;

    return Column(
      children: [
        // Version filter
        if (versions.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: versions.map((v) {
                final label = v.split('-').map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _selectedVersion == v,
                    onSelected: (_) => setState(() => _selectedVersion = v),
                  ),
                );
              }).toList(),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: (grouped.isEmpty && priorEvoGroups.isEmpty)
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No moves found',
                  subtitle: 'Try selecting a different game version.',
                )
              : ListView(
                  children: [
                    ..._methodOrder
                        .where((m) => grouped.containsKey(m))
                        .map((method) => _MoveGroup(
                              label: _methodLabels[method] ?? method,
                              rows: grouped[method]!,
                              showLevel: method == 'level-up',
                            )),
                    // FormatService backs the "Event Moves" group — while it's
                    // still initializing, `formatsReady` is false and the group
                    // is simply absent from `grouped`, which looks identical to
                    // "this Pokémon has no event moves". Show a spinner so it's
                    // clear the table is still loading, not empty.
                    if (!formatsReady)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading event moves…',
                              style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    if (priorEvoLoading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading prior evolution moves…',
                              style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    if (priorEvoGroups.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                        child: Row(
                          children: [
                            Icon(Icons.history_edu_outlined,
                                size: 16, color: colorScheme.tertiary),
                            const SizedBox(width: 6),
                            Text(
                              'Prior Evolution Exclusive',
                              style: textTheme.titleSmall?.copyWith(
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '— must be learned before evolving',
                                style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      for (final g in priorEvoGroups)
                        _MoveGroup(
                          label: _fmtSpeciesName(g.speciesName),
                          rows: g.rows,
                          showLevel: false,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static String _fmtSpeciesName(String name) => name
      .split('-')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// PokéAPI uses hyphenated names ("extreme-speed"); PS ids strip hyphens
  /// ("extremespeed") — mirrors `_toPsId` in slot_validator.dart.
  static String _toPsId(String pokeApiName) =>
      pokeApiName.replaceAll('-', '').toLowerCase();
}

class _MoveRow {
  final String moveName;
  final int level;
  const _MoveRow({required this.moveName, required this.level});
}

class _MoveGroup extends StatelessWidget {
  final String label;
  final List<_MoveRow> rows;
  final bool showLevel;

  const _MoveGroup({
    required this.label,
    required this.rows,
    required this.showLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '$label (${rows.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              if (showLevel) const SizedBox(width: 36, child: Text('Lv', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              const Expanded(child: Text('Move', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 52, child: Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 24, child: Text('Cat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              const SizedBox(width: 32, child: Text('Pwr', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              const SizedBox(width: 32, child: Text('Acc', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1, indent: 16),
        ...rows.map((r) => _MoveTile(row: r, showLevel: showLevel)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MoveTile extends ConsumerWidget {
  final _MoveRow row;
  final bool showLevel;
  const _MoveTile({required this.row, required this.showLevel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moveAsync = ref.watch(moveProvider(row.moveName));
    final typeColor = moveAsync.whenOrNull(
          data: (m) => PokemonTypeColors.colors[m.typeName] ?? Colors.grey,
        ) ??
        Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          if (showLevel)
            SizedBox(
              width: 36,
              child: Text(
                row.level == 0 ? '—' : '${row.level}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: Text(
              row.moveName
                  .split('-')
                  .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
                  .join(' '),
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 52,
            child: moveAsync.whenOrNull(
                  data: (m) => m.typeName != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${m.typeName![0].toUpperCase()}${m.typeName!.substring(1)}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
          ),
          SizedBox(
            width: 24,
            child: Text(
              moveAsync.whenOrNull(data: (m) => m.categoryIcon) ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              moveAsync.whenOrNull(data: (m) => m.power?.toString() ?? '—') ?? '…',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              moveAsync.whenOrNull(data: (m) => m.accuracy != null ? '${m.accuracy}%' : '—') ?? '…',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Abilities Tab ─────────────────────────────────────────────────────────────

class _AbilitiesTab extends ConsumerWidget {
  final PokemonEntry pokemon;
  const _AbilitiesTab({required this.pokemon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilities = pokemon.abilities;
    if (abilities.isEmpty) {
      return const EmptyState(icon: Icons.info_outline, title: 'No ability data');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: abilities.length,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, i) {
        final ability = abilities[i];
        final name = ability.name;
        final isHidden = ability.isHidden;
        return _AbilityCard(name: name, isHidden: isHidden, ref: ref);
      },
    );
  }
}

class _AbilityCard extends ConsumerWidget {
  final String name;
  final bool isHidden;
  final WidgetRef ref;

  const _AbilityCard({
    required this.name,
    required this.isHidden,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityProvider(name));

    return abilityAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load $name', style: const TextStyle(color: Colors.red)),
      data: (ability) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ability.displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              if (isHidden)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Hidden',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                  ),
                ),
              if (ability.generationLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  ability.generationLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
          if (ability.shortEffect != null) ...[
            const SizedBox(height: 4),
            Text(ability.shortEffect!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (ability.longEffect != null && ability.longEffect != ability.shortEffect) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Full description',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    ability.longEffect!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Evolutions Tab ────────────────────────────────────────────────────────────

class _EvolutionsTab extends ConsumerWidget {
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;
  final String? selectedFormName;
  const _EvolutionsTab({required this.speciesAsync, this.selectedFormName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return speciesAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (species) {
        final chainId = species.evolutionChainId;
        if (chainId == null) {
          return const EmptyState(icon: Icons.device_unknown, title: 'No evolution data');
        }
        final chainAsync = ref.watch(evolutionChainProvider(chainId));
        return chainAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e),
          data: (root) {
            // Step 1: suffix from the form switcher.
            String? suffix = selectedFormName != null
                ? regionalSuffixOf(selectedFormName!)
                : null;
            // Step 2: auto-detect for Pokémon like Obstagoon and Mr. Rime that
            // have no regional varieties of their own but are form-exclusive evolutions.
            suffix ??= chainHasFormDetails(root)
                ? formSuffixForSpecies(root, species.id)
                : null;

            // Pre-resolve form IDs for terminal nodes and region branches.
            final allNames = collectSpeciesNames(root);
            const regionalSuffixes = ['galar', 'alola', 'hisui', 'paldea'];
            final formIds = <String, int>{};
            for (final name in allNames) {
              for (final s in regionalSuffixes) {
                final exactAsync = ref.watch(pokemonByNameProvider('$name-$s'));
                final exactId = exactAsync.asData?.value.id;
                if (exactId != null) {
                  formIds['$name-$s'] = exactId;
                } else {
                  // Try "{name}-{suffix}-standard" for species whose Galarian/regional
                  // form uses a compound name (e.g. darmanitan-galar-standard rather
                  // than darmanitan-galar which doesn't exist in PokéAPI).
                  // Try "{name}-{suffix}-standard" fallback (darmanitan-galar-standard).
                  final stdAsync = ref.watch(pokemonByNameProvider('$name-$s-standard'));
                  final stdId = stdAsync.asData?.value.id;
                  if (stdId != null) {
                    formIds['$name-$s'] = stdId;
                    formIds['$name-$s-standard'] = stdId;
                  } else {
                    // Try regionalFormLookup for forms with non-standard naming
                    // (e.g. basculin-hisui → basculin-white-striped).
                    final lookupName = PokemonDataRegistry.instance.regionalFormLookup['$name-$s'];
                    if (lookupName != null) {
                      final lookupAsync = ref.watch(pokemonByNameProvider(lookupName));
                      final lookupId = lookupAsync.asData?.value.id;
                      if (lookupId != null) {
                        formIds['$name-$s'] = lookupId;
                        formIds[lookupName] = lookupId;
                      }
                    }
                  }
                }
              }
            }

            // Root display ID: regional form of the chain root when applicable.
            final rootDisplayId = suffix != null
                ? (formIds['${root.speciesName}-$suffix'] ?? root.speciesId)
                : root.speciesId;

            // Suffixes already in the form switcher — omit their region-keyed
            // branches from the default chain (e.g. Raichu's base chain should
            // not show the Alolan branch; the user switches via the badge).
            final switcherSuffixes = battleMeaningfulForms(species.varieties)
                .map((v) => regionalSuffixOf(v.name))
                .whereType<String>()
                .toSet();

            final displayRoot = buildFormChain(
              root, suffix, rootDisplayId,
              formIds: formIds,
              excludeRegionSuffixes: suffix == null ? switcherSuffixes : const {},
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _EvolutionTree(displayNode: displayRoot),
            );
          },
        );
      },
    );
  }
}

/// Recursively renders the evolution chain.
/// Linear chains stay vertical; branching chains (e.g. Eevee) spread
/// horizontally in a Wrap so they don't all stack into a single tall column.
class _EvolutionTree extends StatelessWidget {
  final DisplayNode displayNode;
  const _EvolutionTree({required this.displayNode});

  @override
  Widget build(BuildContext context) {
    final node = displayNode;
    if (node.evolvesTo.isEmpty) return _EvolutionNodeCard(displayNode: node);

    if (node.evolvesTo.length == 1) {
      final child = node.evolvesTo.first;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EvolutionNodeCard(displayNode: node),
          const SizedBox(height: 6),
          _EvolutionArrow(details: child.matchedDetails ?? child.source.details),
          const SizedBox(height: 6),
          _EvolutionTree(displayNode: child),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EvolutionNodeCard(displayNode: node),
        const SizedBox(height: 6),
        const Icon(Icons.call_split_rounded, size: 22, color: Colors.grey),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: node.evolvesTo.map((child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConditionChip(details: child.matchedDetails ?? child.source.details),
              const SizedBox(height: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.shade400),
              const SizedBox(height: 4),
              _EvolutionTree(displayNode: child),
            ],
          )).toList(),
        ),
      ],
    );
  }
}

/// Arrow + condition chip between two evolution stages.
class _EvolutionArrow extends StatelessWidget {
  final List<EvolutionDetail> details;
  const _EvolutionArrow({required this.details});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ConditionChip(details: details),
        if (details.isNotEmpty) const SizedBox(height: 4),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 28,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }
}

class _EvolutionNodeCard extends StatelessWidget {
  final DisplayNode displayNode;
  const _EvolutionNodeCard({required this.displayNode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spriteUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${displayNode.displayId}.png';
    return GestureDetector(
      onTap: () {
        final formName = displayNode.formName;
        if (formName != null) {
          context.push('/pokedex/${displayNode.source.speciesId}?form=${Uri.encodeComponent(formName)}');
        } else {
          context.push('/pokedex/${displayNode.source.speciesId}');
        }
      },
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: spriteUrl,
              width: 72, height: 72,
              placeholder: (_, _) => const SizedBox(width: 72, height: 72,
                  child: Icon(Icons.catching_pokemon, color: Colors.grey)),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
            ),
            const SizedBox(height: 4),
            Text(displayNode.source.displayName,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            Text('#${displayNode.source.speciesId.toString().padLeft(3, '0')}',
                style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final List<EvolutionDetail> details;
  const _ConditionChip({required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    final label = details.map((d) => d.conditionLabel).join(' / ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

// ── Forms & Variants Tab ──────────────────────────────────────────────────────

class _FormsTab extends ConsumerWidget {
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;
  final String? selectedFormName;
  const _FormsTab({required this.speciesAsync, this.selectedFormName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return speciesAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (species) {
        // Battle-meaningful forms live in the app bar switcher — exclude them here.
        final switcherFormNames = battleMeaningfulForms(species.varieties)
            .map((v) => v.name)
            .toSet();
        // When a regional form is selected, also hide mega/gmax forms: they
        // belong to the base form and aren't accessible from a regional variant.
        const megaSuffixes = {'-mega', '-mega-x', '-mega-y', '-mega-z', '-gmax', '-eternamax'};
        final nonDefault = species.varieties.where((v) {
          if (v.isDefault) return false;
          if (switcherFormNames.contains(v.name)) return false;
          // Also exclude variety-based cosmetic forms — they appear as header chips.
          if (PokemonDataRegistry.instance.cosmeticVarietyNames.contains(v.name)) return false;
          if (selectedFormName != null && megaSuffixes.any((s) => v.name.endsWith(s))) return false;
          return true;
        }).toList();
        if (nonDefault.isEmpty) {
          return const EmptyState(
            icon: Icons.style_outlined,
            title: 'No alternate forms',
            subtitle: 'Regional and battle forms are accessible via the form switcher above.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: nonDefault.length,
          separatorBuilder: (_, _) => const Divider(height: 24),
          itemBuilder: (_, i) => _FormCard(variety: nonDefault[i]),
        );
      },
    );
  }
}

class _FormCard extends ConsumerWidget {
  final PokemonVariety variety;
  const _FormCard({required this.variety});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemonAsync = ref.watch(pokemonByNameProvider(variety.name));

    return pokemonAsync.when(
      loading: () => ListTile(
        leading: const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(variety.displayName),
      ),
      error: (e, _) => ListTile(
        title: Text(variety.displayName),
        subtitle: const Text('Failed to load form data'),
      ),
      data: (pokemon) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PokemonSprite(
                  defaultUrl: pokemon.officialArtworkUrl ??
                      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                  size: 80,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variety.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: pokemon.types
                            .map((t) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: TypeBadge(type: t),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pokemon.stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...pokemon.stats.entries.indexed.map((entry) {
                final i = entry.$1;
                final e = entry.$2;
                final statName = e.key;
                final value = e.value;
                final label = _shortStatLabel(statName);
                return StatBar(
                  label: label,
                  value: value,
                  delay: Duration(milliseconds: i * 70),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  static String _shortStatLabel(String name) {
    const map = {
      'hp': 'HP',
      'attack': 'Atk',
      'defense': 'Def',
      'special-attack': 'SpA',
      'special-defense': 'SpD',
      'speed': 'Spe',
    };
    return map[name] ?? name;
  }
}

// ── Locations Tab ─────────────────────────────────────────────────────────────

class _LocationsTab extends ConsumerStatefulWidget {
  final int pokemonId;
  const _LocationsTab({required this.pokemonId});

  @override
  ConsumerState<_LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends ConsumerState<_LocationsTab> {
  String? _selectedVersion;

  @override
  Widget build(BuildContext context) {
    final encountersAsync = ref.watch(pokemonEncountersProvider(widget.pokemonId));

    return encountersAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (encounters) {
        if (encounters.isEmpty) {
          return const EmptyState(
            icon: Icons.map_outlined,
            title: 'No location data',
            subtitle: 'This Pokémon is not encountered in the wild.',
          );
        }

        // Collect all versions from encounter data
        final versions = encounters
            .expand((e) => e.versionDetails.map((v) => v.version))
            .toSet()
            .toList()
          ..sort();

        _selectedVersion ??= versions.first;

        // Filter encounters for the selected version
        final filtered = encounters
            .map((e) {
              final vd = e.versionDetails
                  .where((v) => v.version == _selectedVersion)
                  .toList();
              return vd.isEmpty ? null : (entry: e, vd: vd.first);
            })
            .whereType<({EncounterEntry entry, VersionEncounter vd})>()
            .toList();

        return Column(
          children: [
            _VersionFilterBar(
              versions: versions,
              selected: _selectedVersion!,
              onSelected: (v) => setState(() => _selectedVersion = v),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.map_outlined,
                      title: 'Not available',
                      subtitle: 'This Pokémon is not encountered in this version.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 8),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return _LocationTile(
                          entry: item.entry,
                          versionEncounter: item.vd,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VersionFilterBar extends StatelessWidget {
  final List<String> versions;
  final String selected;
  final ValueChanged<String> onSelected;

  const _VersionFilterBar({
    required this.versions,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: versions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final v = versions[i];
          final isSelected = v == selected;
          return FilterChip(
            label: Text(_versionLabel(v)),
            selected: isSelected,
            onSelected: (_) => onSelected(v),
          );
        },
      ),
    );
  }

  static String _versionLabel(String v) {
    return v
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

class _LocationTile extends StatelessWidget {
  final EncounterEntry entry;
  final VersionEncounter versionEncounter;

  const _LocationTile({
    required this.entry,
    required this.versionEncounter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.displayName,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${versionEncounter.maxChance}%',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                ),
              ],
            ),
            if (versionEncounter.methods.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: versionEncounter.methods.map((m) {
                  return Chip(
                    label: Text(
                      '${m.methodLabel} · ${m.levelRange} · ${m.chance}%',
                      style: textTheme.labelSmall,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Teams Tab ─────────────────────────────────────────────────────────────────

class _TeamsTab extends ConsumerWidget {
  final int pokemonId;
  final PokemonEntry pokemon;
  final String? selectedFormName;
  const _TeamsTab({required this.pokemonId, required this.pokemon, this.selectedFormName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairsAsync = ref.watch(teamsForPokemonProvider(pokemonId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return pairsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (allPairs) {
        // Show only slots matching the selected form.
        // null selectedFormName = base form = slots where formName is null.
        final pairs = allPairs
            .where((pair) => pair.$2.formName == selectedFormName)
            .toList();
        return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'On your teams',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (pairs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pairs.length}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (pairs.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Icon(
                      Icons.catching_pokemon_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Not on any team yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList.separated(
                itemCount: pairs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final (team, slot) = pairs[i];
                  return _OnTeamTile(
                    team: team,
                    slot: slot,
                    pokemon: pokemon,
                  );
                },
              ),
            ),
          // Add to a team
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Add to a team',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverToBoxAdapter(
              child: FilledButton.icon(
                onPressed: () => _showAddSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add to a team'),
              ),
            ),
          ),
        ],
      );
    },
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddToTeamSheet(
        pokemon: pokemon,
        ref: ref,
      ),
    );
  }
}

/// Tile showing a team that already contains this Pokémon.
class _OnTeamTile extends StatelessWidget {
  final Team team;
  final TeamSlot slot;
  final PokemonEntry pokemon;
  const _OnTeamTile(
      {required this.team, required this.slot, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            '${slot.slot}',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(team.name, style: textTheme.bodyLarge),
        subtitle: Text(
          [
            'Slot ${slot.slot}',
            if (slot.nickname != null && slot.nickname!.isNotEmpty)
              '· "${slot.nickname}"',
            if (team.formatLabel != null) '· ${team.formatLabel}',
          ].join(' '),
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/teams/${team.id}'),
      ),
    );
  }
}

/// Bottom sheet: pick a team → pick a slot → add.
class _AddToTeamSheet extends StatefulWidget {
  final PokemonEntry pokemon;
  final WidgetRef ref;
  const _AddToTeamSheet({required this.pokemon, required this.ref});

  @override
  State<_AddToTeamSheet> createState() => _AddToTeamSheetState();
}

class _AddToTeamSheetState extends State<_AddToTeamSheet> {
  Team? _selectedTeam;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                if (_selectedTeam != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedTeam = null),
                  ),
                Expanded(
                  child: Text(
                    _selectedTeam == null
                        ? 'Select a team'
                        : 'Select a slot — ${_selectedTeam!.name}',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedTeam == null
                ? _TeamPicker(
                    ref: widget.ref,
                    scrollController: controller,
                    onTeamSelected: (t) =>
                        setState(() => _selectedTeam = t),
                  )
                : _SlotPicker(
                    team: _selectedTeam!,
                    pokemon: widget.pokemon,
                    ref: widget.ref,
                    loading: _loading,
                    onSlotSelected: (slot) => _addToSlot(context, slot),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToSlot(BuildContext context, int slot) async {
    final existing = await widget.ref
        .read(teamSlotRepositoryProvider)
        .getByTeamAndSlot(_selectedTeam!.id, slot);

    if (existing != null && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Replace slot?'),
          content: Text(
            'Slot $slot already has a Pokémon. Replace it with '
            '${widget.pokemon.displaySpeciesName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _loading = true);
    try {
      await addPokemonToSlot(
        widget.ref,
        teamId: _selectedTeam!.id,
        slot: slot,
        pokemonId: widget.pokemon.id,
      );
      if (context.mounted) {
        // Capture router and messenger BEFORE popping — the sheet's context
        // is deactivated after Navigator.pop and cannot be used for routing.
        final router = GoRouter.of(context);
        // final messenger = ScaffoldMessenger.of(context);
        final teamId = _selectedTeam!.id;
        final teamName = _selectedTeam!.name;

        Navigator.pop(context); // close sheet

        showAppSnackBar(
          context,
          '${widget.pokemon.displaySpeciesName} added to $teamName · Slot $slot',
          action: SnackBarAction(
            label: 'View team',
            onPressed: () => router.push('/teams/$teamId'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Step 1 of the add sheet: choose a team, or create a new one inline.
class _TeamPicker extends ConsumerWidget {
  final WidgetRef ref;
  final ScrollController scrollController;
  final ValueChanged<Team> onTeamSelected;
  const _TeamPicker({
    required this.ref,
    required this.scrollController,
    required this.onTeamSelected,
  });

  Future<void> _createAndSelect(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New team'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Team name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty) return;

    // createTeam returns the local ID; fetch the full Team record to pass back
    final localId = await createTeam(ref, name);
    final team = await ref.read(teamRepositoryProvider).getById(localId);
    onTeamSelected(team);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // "New team" tile — always shown at the top
    final newTeamTile = Card(
      margin: EdgeInsets.zero,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: ListTile(
        leading: Icon(Icons.add, color: colorScheme.secondary),
        title: Text(
          'New team',
          style: textTheme.bodyLarge
              ?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.w600),
        ),
        onTap: () => _createAndSelect(context, ref),
      ),
    );

    return teamsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (teams) {
        final active = teams.where((t) => !t.isDeleted).toList();

        if (active.isEmpty) {
          // No teams yet — show create prompt
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              newTeamTile,
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'No teams yet — create one above.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        }

        // Existing teams + new-team option at top
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: active.length + 1, // +1 for the new-team tile
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == 0) return newTeamTile;
            final team = active[i - 1];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(team.name, style: textTheme.bodyLarge),
                subtitle: team.formatLabel != null
                    ? Text(team.formatLabel!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant))
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTeamSelected(team),
              ),
            );
          },
        );
      },
    );
  }
}

/// Step 2 of the add sheet: choose a slot within [team].
class _SlotPicker extends ConsumerWidget {
  final Team team;
  final PokemonEntry pokemon;
  final WidgetRef ref;
  final bool loading;
  final ValueChanged<int> onSlotSelected;
  const _SlotPicker({
    required this.team,
    required this.pokemon,
    required this.ref,
    required this.loading,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final slotsAsync = widgetRef.watch(teamSlotsProvider(team.id));
    final colorScheme = Theme.of(context).colorScheme;
    final primaryType = pokemon.types.isNotEmpty ? pokemon.types[0] : 'normal';
    final typeColor =
        PokemonTypeColors.colors[primaryType] ?? colorScheme.primary;

    return slotsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(error: e),
      data: (slots) {
        final slotMap = {for (final s in slots) s.slot: s};

        return Stack(
          children: [
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: 6,
              itemBuilder: (_, i) {
                final slotNum = i + 1;
                final occupied = slotMap[slotNum];
                return _SlotCard(
                  slotNum: slotNum,
                  occupied: occupied,
                  typeColor: typeColor,
                  onTap: loading ? null : () => onSlotSelected(slotNum),
                );
              },
            ),
            if (loading)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  final int slotNum;
  final TeamSlot? occupied;
  final Color typeColor;
  final VoidCallback? onTap;
  const _SlotCard({
    required this.slotNum,
    required this.occupied,
    required this.typeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isOccupied = occupied != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isOccupied
              ? colorScheme.surfaceContainerHighest
              : typeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOccupied
                ? colorScheme.outlineVariant
                : typeColor.withValues(alpha: 0.6),
            width: isOccupied ? 1 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isOccupied)
              CachedNetworkImage(
                imageUrl:
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${occupied!.pokemonId}.png',
                width: 52,
                height: 52,
                placeholder: (_, _) => Icon(Icons.catching_pokemon,
                    size: 40, color: colorScheme.onSurfaceVariant),
                errorWidget: (_, _, _) => Icon(Icons.catching_pokemon,
                    size: 40, color: colorScheme.onSurfaceVariant),
              )
            else
              Icon(
                Icons.add_circle_outline,
                size: 32,
                color: typeColor.withValues(alpha: 0.7),
              ),
            const SizedBox(height: 4),
            Text(
              isOccupied
                  ? (occupied!.nickname?.isNotEmpty == true
                      ? occupied!.nickname!
                      : 'Slot $slotNum')
                  : 'Slot $slotNum',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isOccupied
                    ? colorScheme.onSurface
                    : typeColor,
              ),
            ),
            if (isOccupied)
              Text(
                'Tap to replace',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Old Add to Team Tab (replaced) ───────────────────────────────────────────

class _AddToTeamTab extends StatefulWidget {
  final PokemonEntry pokemon;
  const _AddToTeamTab({required this.pokemon});

  @override
  State<_AddToTeamTab> createState() => _AddToTeamTabState();
}

class _AddToTeamTabState extends State<_AddToTeamTab> {
  int? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pokemon = widget.pokemon;
    final primaryType = pokemon.types.isNotEmpty ? pokemon.types[0] : 'normal';
    final typeColor = PokemonTypeColors.colors[primaryType] ?? colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pokémon summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PokemonSprite(
                    defaultUrl: pokemon.officialArtworkUrl ??
                        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                    size: 80,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pokemon.displaySpeciesName,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '#${pokemon.displayId()}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: pokemon.types
                              .map((t) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: TypeBadge(type: t),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Select a team slot',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 6-slot grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: 6,
            itemBuilder: (_, i) {
              final slot = i + 1;
              final isSelected = _selectedSlot == slot;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlot = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? typeColor : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? typeColor.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.catching_pokemon,
                        size: 28,
                        color: isSelected
                            ? typeColor
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slot $slot',
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? typeColor
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: _selectedSlot == null
                ? null
                : () {
                    showAppSnackBar(
                      context,
                      'Team Builder coming soon — ${pokemon.displaySpeciesName} queued for slot $_selectedSlot!',
                    );
                  },
            icon: const Icon(Icons.add),
            label: Text(
              _selectedSlot == null
                  ? 'Select a slot first'
                  : 'Add to Slot $_selectedSlot',
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Full Team Builder with folder management and sync is coming in a future update.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Form Badge ────────────────────────────────────────────────────────────────

class _FormBadge extends StatelessWidget {
  final List<PokemonVariety> battleForms;
  final String baseFormLabel;
  final String? baseSpriteUrl;
  final String? baseShinyUrl;
  final String? selectedFormName;
  final bool shiny;
  final void Function(String?) onSelect;

  const _FormBadge({
    required this.battleForms,
    required this.baseFormLabel,
    this.baseSpriteUrl,
    this.baseShinyUrl,
    required this.selectedFormName,
    required this.shiny,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedFormName != null
        ? shortFormLabel(selectedFormName!)
        : baseFormLabel;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => FormPickerSheet(
          allForms: [
            (null, baseFormLabel, null as String?),
            ...battleForms.map((v) => (v.name, shortFormLabel(v.name), null as String?)),
          ],
          baseSpriteUrl: baseSpriteUrl,
          baseShinyUrl: baseShinyUrl,
          selectedFormName: selectedFormName,
          shiny: shiny,
          onSelect: (name) {
            onSelect(name);
            Navigator.pop(ctx);
          },
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Cosmetic Form Chips ───────────────────────────────────────────────────────

/// Horizontal strip of cosmetic form chips (≤ 6 forms) or a single count
/// chip that opens a picker sheet (> 6 forms).
class _CosmeticFormRow extends StatelessWidget {
  final List<PokemonFormEntry> forms;
  final String? selectedFormName;
  final bool shiny;
  final void Function(String?) onSelect;
  /// HOME URL for the base form to show as first tile in the picker sheet
  /// (e.g. Unown-A). Only used when forms.length > 6.
  final String? baseHomeUrl;
  final String? baseLabel;

  const _CosmeticFormRow({
    required this.forms,
    required this.selectedFormName,
    required this.shiny,
    required this.onSelect,
    this.baseHomeUrl,
    this.baseLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) return const SizedBox.shrink();
    if (forms.length <= 6) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: forms.map((f) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _CosmeticFormChip(
              form: f,
              isSelected: f.name == selectedFormName,
              shiny: shiny,
              onTap: () => onSelect(f.name == selectedFormName ? null : f.name),
            ),
          )).toList(),
        ),
      );
    }
    // > 6 forms: single count chip opens picker sheet.
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _CosmeticFormPickerSheet(
          forms: forms,
          selectedFormName: selectedFormName,
          shiny: shiny,
          onSelect: (name) {
            onSelect(name == selectedFormName ? null : name);
            Navigator.pop(ctx);
          },
          baseHomeUrl: baseHomeUrl,
          baseLabel: baseLabel,
          onSelectBase: selectedFormName != null
              ? () {
                  onSelect(null);
                  Navigator.pop(ctx);
                }
              : null,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          '${forms.length} forms ▾',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CosmeticFormChip extends StatelessWidget {
  final PokemonFormEntry form;
  final bool isSelected;
  final bool shiny;
  final VoidCallback onTap;

  const _CosmeticFormChip({
    required this.form,
    required this.isSelected,
    required this.shiny,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spriteUrl = (shiny ? form.spriteShinyUrl : null) ?? form.spriteUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white38,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spriteUrl != null)
              CachedNetworkImage(
                imageUrl: spriteUrl,
                width: 28, height: 28,
                placeholder: (_, _) => const SizedBox(
                  width: 28, height: 28,
                  child: Center(
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.catching_pokemon, color: Colors.white54, size: 20),
              )
            else
              const SizedBox(width: 28, height: 28),
            const SizedBox(width: 4),
            Text(
              PokemonDataRegistry.instance.cosmeticFormLabels[form.name] ?? cosmeticFormLabel(form.formName),
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmeticFormPickerSheet extends StatelessWidget {
  final List<PokemonFormEntry> forms;
  final String? selectedFormName;
  final bool shiny;
  final void Function(String) onSelect;
  /// HOME artwork URL for the base form (e.g. Unown-A), shown as the first
  /// tile so the canonical default form is always selectable in the picker.
  final String? baseHomeUrl;
  final String? baseLabel;
  /// Called when the base tile is tapped (deselects the current cosmetic form).
  final VoidCallback? onSelectBase;

  const _CosmeticFormPickerSheet({
    required this.forms,
    required this.selectedFormName,
    required this.shiny,
    required this.onSelect,
    this.baseHomeUrl,
    this.baseLabel,
    this.onSelectBase,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Padding(
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
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Base form tile (e.g. Unown-A) when a specific HOME URL is provided.
              if (baseHomeUrl != null && onSelectBase != null) ...[
                _buildPickerTile(
                  context: context,
                  isSelected: selectedFormName == null,
                  spriteUrl: baseHomeUrl!,
                  label: baseLabel ?? 'Base',
                  onTap: onSelectBase!,
                ),
              ],
              ...forms.map((f) {
              final isSelected = f.name == selectedFormName;
              final spriteUrl =
                  (shiny ? f.spriteShinyUrl : null) ?? f.spriteUrl;
              return GestureDetector(
                onTap: () => onSelect(f.name),
                child: Container(
                  width: 80,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (spriteUrl != null)
                        CachedNetworkImage(
                          imageUrl: spriteUrl,
                          height: 52, width: 52,
                          placeholder: (_, _) => const SizedBox(height: 52, width: 52),
                          errorWidget: (_, _, _) => const SizedBox(
                            height: 52, width: 52,
                            child: Icon(Icons.catching_pokemon, color: Colors.grey),
                          ),
                        )
                      else
                        const SizedBox(height: 52, width: 52,
                            child: Icon(Icons.catching_pokemon,
                                color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        PokemonDataRegistry.instance.cosmeticFormLabels[f.name] ?? cosmeticFormLabel(f.formName),
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color:
                                      isSelected ? colorScheme.primary : null,
                                ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerTile({
    required BuildContext context,
    required bool isSelected,
    required String spriteUrl,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: spriteUrl,
              height: 52, width: 52,
              fit: BoxFit.contain,
              placeholder: (_, _) => const SizedBox(
                height: 52, width: 52,
                child: Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              ),
              errorWidget: (_, _, _) => const SizedBox(height: 52, width: 52,
                  child: Icon(Icons.catching_pokemon, color: Colors.grey)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cosmetic Form Header Sprite ───────────────────────────────────────────────

/// Tries to display the cosmetic form's HOME artwork; falls back to the pixel
/// sprite when the HOME URL doesn't exist (e.g. Pichu Spiky-eared).
class _CosmeticFormHeaderSprite extends StatelessWidget {
  final String? homeUrl;
  final String? fallbackSpriteUrl;
  final double size;

  const _CosmeticFormHeaderSprite({
    required this.homeUrl,
    required this.fallbackSpriteUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final sprite = fallbackSpriteUrl;
    if (homeUrl == null) {
      return sprite != null
          ? CachedNetworkImage(
              imageUrl: sprite,
              width: size, height: size, fit: BoxFit.contain,
              placeholder: (_, _) => SizedBox(width: size, height: size),
              errorWidget: (_, _, _) => SizedBox(width: size, height: size,
                  child: Icon(Icons.catching_pokemon, color: Colors.white54)),
            )
          : SizedBox(width: size, height: size,
              child: Icon(Icons.catching_pokemon, color: Colors.white54, size: size * 0.5));
    }
    return CachedNetworkImage(
      imageUrl: homeUrl!,
      width: size, height: size, fit: BoxFit.contain,
      placeholder: (_, _) => SizedBox(width: size, height: size),
      errorWidget: (_, _, _) => sprite != null
          ? CachedNetworkImage(
              imageUrl: sprite,
              width: size, height: size, fit: BoxFit.contain,
              placeholder: (_, _) => SizedBox(width: size, height: size),
              errorWidget: (_, _, _) => SizedBox(width: size, height: size,
                  child: Icon(Icons.catching_pokemon, color: Colors.white54)),
            )
          : SizedBox(width: size, height: size,
              child: Icon(Icons.catching_pokemon, color: Colors.white54, size: size * 0.5)),
    );
  }
}
