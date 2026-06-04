import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/teams/data/dynamax_data.dart';
import 'package:poke_team_dex/features/teams/data/mega_forms_data.dart';
import 'package:poke_team_dex/features/teams/presentation/format_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/presentation/slot_config_screen.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/format/sprite_resolver.dart';
import 'package:poke_team_dex/features/teams/providers/teams_provider.dart';
import 'package:poke_team_dex/features/teams/services/showdown_export.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/async_value_states.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/settings_button.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

// ── Stat calculator (Gen III+ formula) ───────────────────────────────────────

const _kNatureModifiers = <String, (String?, String?)>{
  'hardy': (null, null), 'docile': (null, null), 'serious': (null, null),
  'bashful': (null, null), 'quirky': (null, null),
  'lonely': ('attack', 'defense'), 'brave': ('attack', 'speed'),
  'adamant': ('attack', 'special-attack'), 'naughty': ('attack', 'special-defense'),
  'bold': ('defense', 'attack'), 'relaxed': ('defense', 'speed'),
  'impish': ('defense', 'special-attack'), 'lax': ('defense', 'special-defense'),
  'timid': ('speed', 'attack'), 'hasty': ('speed', 'defense'),
  'jolly': ('speed', 'special-attack'), 'naive': ('speed', 'special-defense'),
  'modest': ('special-attack', 'attack'), 'mild': ('special-attack', 'defense'),
  'quiet': ('special-attack', 'speed'), 'rash': ('special-attack', 'special-defense'),
  'calm': ('special-defense', 'attack'), 'gentle': ('special-defense', 'defense'),
  'sassy': ('special-defense', 'speed'), 'careful': ('special-defense', 'special-attack'),
};

int _calcHP(int base, int iv, int ev, int level) =>
    ((2 * base + iv + ev ~/ 4) * level) ~/ 100 + level + 10;

int _calcStat(int base, int iv, int ev, int level, double mod) {
  return (((2 * base + iv + ev ~/ 4) * level) ~/ 100 + 5) * mod ~/ 1;
}

double _natureMod(String? nature, String key) {
  if (nature == null) return 1.0;
  final m = _kNatureModifiers[nature.toLowerCase()];
  if (m == null) return 1.0;
  if (m.$1 == key) return 1.1;
  if (m.$2 == key) return 0.9;
  return 1.0;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TeamDetailScreen extends ConsumerStatefulWidget {
  final int teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  int? _selectedSlot;
  final _canCloseNotifier = ValueNotifier<Future<bool> Function()?>(null);

  @override
  void dispose() {
    _canCloseNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 840;
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId));
    final slotsAsync = ref.watch(teamSlotsProvider(widget.teamId));
    final maxBoxSize = ref.watch(maxBoxSizeProvider).asData?.value ?? 60;

    // Reset selected slot when switching to narrow layout
    if (!isWide && _selectedSlot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSlot = null);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canClose = _canCloseNotifier.value;
        if (canClose == null) {
          // No embedded slot config open — allow back normally.
          if (mounted) context.pop();
          return;
        }
        final ok = await canClose();
        if (ok && mounted) context.pop();
      },
      child: teamAsync.when(
        loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
        error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(error: e)),
        data: (team) {
          if (team == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.canPop()) context.pop();
            });
            return const Scaffold(body: LoadingState());
          }

          final slots = slotsAsync.asData?.value ?? [];

          return Scaffold(
            appBar: AppBar(
              title: _TeamAppBarTitle(team: team),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Rename',
                  onPressed: () => _renameTeam(context, team),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_outlined),
                  tooltip: 'Change format',
                  onPressed: () => _editFormat(context, team),
                ),
                if (slots.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.upload_outlined),
                    tooltip: 'Export to Showdown',
                    onPressed: () => _exportShowdown(context, slots, team),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete team',
                  onPressed: () => _deleteTeam(context, team),
                ),
                const ConnectivityStatusButton(),
                const SettingsButton(),
              ],
            ),
            body: slotsAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(error: e),
              data: (slots) {
                final maxSlots = (team.isBox) ? maxBoxSize : 6;
                return isWide
                    ? _buildWideLayout(slots, team, maxSlots)
                    : _SlotList(
                        teamId: widget.teamId,
                        slots: slots,
                        formatId: team.formatLabel,
                        maxSlots: maxSlots,
                      );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(List<TeamSlot> slots, Team team, int maxSlots) {
    return Row(
      children: [
        Semantics(
          container: true,
          label: 'Team slots',
          child: SizedBox(
            width: 380,
            child: _SlotList(
              teamId: widget.teamId,
              slots: slots,
              formatId: team.formatLabel,
              selectedSlot: _selectedSlot,
              maxSlots: maxSlots,
              onSlotTap: (slotNumber) {
                _canCloseNotifier.value = null;
                setState(() => _selectedSlot = slotNumber);
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: Semantics(
            container: true,
            label: 'Slot configuration',
            child: _selectedSlot == null
                ? const EmptyState(
                    icon: Icons.tune_outlined,
                    title: 'Select a slot to configure',
                    subtitle:
                        'Tap a Pokémon in your team to edit its details here.',
                  )
                : SlotConfigScreen(
                    key: ValueKey(_selectedSlot),
                    teamId: widget.teamId,
                    slotNumber: _selectedSlot!,
                    embedded: true,
                    onClose: () {
                      _canCloseNotifier.value = null;
                      setState(() => _selectedSlot = null);
                    },
                    canCloseNotifier: _canCloseNotifier,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportShowdown(
      BuildContext context, List<TeamSlot> slots, Team team) async {
    final pokeApi = ref.read(pokeApiRepositoryProvider);
    try {
      final text = await buildShowdownExport(
        slots, pokeApi,
        teamName: team.name,
        formatLabel: team.formatLabel, // raw format id → PS format lookup
      );
      await Clipboard.setData(ClipboardData(text: text));
      HapticFeedback.lightImpact();
      if (context.mounted) {
        showAppSnackBar(context, 'Showdown export copied to clipboard');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'Export failed — try again', isError: true);
      }
    }
  }

  Future<void> _editFormat(BuildContext context, Team team) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormatPickerSheet(current: team.formatLabel),
    );
    if (result == null) return;
    final newLabel = isFormatCleared(result) ? null : (result as GameFormat).id;
    await updateTeamFormat(ref, team.id, newLabel);
  }

  Future<void> _renameTeam(BuildContext context, Team team) async {
    final controller = TextEditingController(text: team.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Team'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await renameTeam(ref, team.id, name);
  }

  Future<void> _deleteTeam(BuildContext context, Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Delete "${team.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteTeam(ref, team.id);
      if (context.mounted) context.pop();
    }
  }
}

// ── AppBar title with format name resolved from ID ───────────────────────────

class _TeamAppBarTitle extends ConsumerWidget {
  final Team team;
  const _TeamAppBarTitle({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? formatName;
    if (team.formatLabel != null) {
      final fmtAsync = ref.watch(allFormatsProvider);
      fmtAsync.whenData((formats) {}); // ensure loaded
      final service = ref.watch(formatServiceProvider);
      formatName = service.formatById(team.formatLabel!)?.name ?? team.formatLabel;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(team.name),
        if (formatName != null)
          Text(
            formatName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
      ],
    );
  }
}

// ── Slot list (reorderable) ───────────────────────────────────────────────────

class _SlotList extends ConsumerWidget {
  final int teamId;
  final List<TeamSlot> slots;
  final String? formatId;
  final int? selectedSlot;
  final int maxSlots;
  final void Function(int slotNumber)? onSlotTap;

  const _SlotList({
    required this.teamId,
    required this.slots,
    this.formatId,
    this.selectedSlot,
    this.maxSlots = 6,
    this.onSlotTap,
  });

  // Build a maxSlots-element growable list keyed by position (0-based); null = empty slot.
  List<TeamSlot?> _positions() {
    final pos = List<TeamSlot?>.filled(maxSlots, null, growable: true);
    for (final s in slots) {
      if (s.slot >= 1 && s.slot <= maxSlots) pos[s.slot - 1] = s;
    }
    return pos;
  }

  Future<void> _onReorder(WidgetRef ref, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final pos = _positions();
    final moved = pos.removeAt(oldIndex);
    pos.insert(newIndex, moved);

    final repo = ref.read(teamSlotRepositoryProvider);
    for (int i = 0; i < maxSlots; i++) {
      final s = pos[i];
      if (s != null && s.slot != i + 1) {
        await repo.updateSlotPosition(s.id, i + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = _positions();

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      buildDefaultDragHandles: false, // explicit handles inside each card
      onReorder: (o, n) => _onReorder(ref, o, n),
      itemCount: maxSlots,
      itemBuilder: (_, i) {
        final slot = pos[i];
        return Padding(
          key: ValueKey(i),
          padding: const EdgeInsets.only(bottom: 10),
          child: slot != null
              ? _FilledSlotCard(
                  slot: slot,
                  teamId: teamId,
                  dragIndex: i,
                  formatId: formatId,
                  selected: selectedSlot == slot.slot,
                  onTap: onSlotTap != null
                      ? () => onSlotTap!(slot.slot)
                      : null,
                )
              : _EmptySlotCard(teamId: teamId, slotNumber: i + 1, dragIndex: i),
        );
      },
    );
  }
}

// ── Filled slot card ──────────────────────────────────────────────────────────

class _FilledSlotCard extends ConsumerWidget {
  final TeamSlot slot;
  final int teamId;
  final int dragIndex;
  final String? formatId;
  final bool selected;
  final VoidCallback? onTap;

  const _FilledSlotCard({
    required this.slot,
    required this.teamId,
    required this.dragIndex,
    this.formatId,
    this.selected = false,
    this.onTap,
  });

  static const _statLabels = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'];
  static const _statKeys = [
    'hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemonAsync = ref.watch(pokemonDetailProvider(slot.pokemonId));
    final itemAsync = slot.heldItemName != null
        ? ref.watch(slotItemDetailProvider(slot.heldItemName!))
        : null;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return pokemonAsync.when(
      loading: () => Card(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) =>
          Card(child: Center(child: Text('Error', style: textTheme.bodySmall))),
      data: (pokemon) {
        final speciesName = pokemon.name.toCapitalCase();
        final nickname = slot.nickname?.trim();
        final hasNickname =
            nickname != null && nickname.isNotEmpty && nickname != speciesName;
        final displayName = hasNickname ? nickname : speciesName;

        // effectiveTypes/effectiveTypeColor are computed after formChangePokemon
        // is resolved below and drive all type display in the slot card.

        // Base stats map
        final baseStats = <String, int>{
          for (final s in pokemon.stats)
            s['stat']['name'] as String: s['base_stat'] as int,
        };

        // ── Mega Evolution support (must come before calcStats) ────────────
        final megaEntry = slot.heldItemName != null
            ? kMegaStoneMap[slot.heldItemName]
            : null;
        final isMegaApplicable = slot.isMegaEvolved &&
            megaEntry != null &&
            pokemon.name == megaEntry.baseSpecies;

        final megaPokemon = isMegaApplicable
            ? ref
                .watch(pokemonByNameProvider(megaEntry.megaForm))
                .asData
                ?.value
            : null;

        // Override base stats: form > mega > base.
        // formEffectiveStats is computed below after formChangePokemon resolves.
        // We use a late override pattern: compute tentative stats from mega/base
        // first, then override with form stats in calcStats below.
        final effectiveBaseStats = megaPokemon != null
            ? <String, int>{
                for (final s in megaPokemon.stats)
                  s['stat']['name'] as String: s['base_stat'] as int,
              }
            : baseStats;
        // Prefer HOME artwork; fall back to official artwork.
        final megaHomeUrl = megaPokemon != null
            ? pokemonHomeUrl(megaPokemon.id)
            : null;
        final megaOfficialUrl = megaPokemon?.officialArtworkUrl;

        // ── Form change sprite ──────────────────────────────────────────────
        final isFormActive = slot.formName != null &&
            slot.formName!.isNotEmpty;
        final formChangePokemon = isFormActive
            ? ref
                .watch(pokemonByNameProvider(slot.formName!))
                .asData
                ?.value
            : null;
        // Effective types and stats for the active form (used for type badges
        // and stat bars — regional forms have different types/stats).
        final effectiveTypes = (formChangePokemon != null &&
                formChangePokemon.types.isNotEmpty)
            ? formChangePokemon.types
            : pokemon.types;
        final effectivePrimaryType =
            effectiveTypes[1] ?? effectiveTypes.values.firstOrNull ?? 'normal';
        final effectiveTypeColor =
            PokemonTypeColors.colors[effectivePrimaryType] ?? colorScheme.primary;

        // Form-specific base stats (overrides mega stats too if both active).
        final formEffectiveStats = formChangePokemon != null
            ? <String, int>{
                for (final s in formChangePokemon.stats)
                  s['stat']['name'] as String: s['base_stat'] as int,
              }
            : null;

        // Use shiny form artwork when the slot is shiny.
        final formHomeUrl = formChangePokemon != null
            ? (slot.isShiny
                ? pokemonHomeShinyUrl(formChangePokemon.id)
                : pokemonHomeUrl(formChangePokemon.id))
            : null;
        final formOfficialUrl = formChangePokemon != null
            ? (slot.isShiny
                ? (formChangePokemon.officialArtworkShinyUrl ??
                    formChangePokemon.officialArtworkUrl)
                : formChangePokemon.officialArtworkUrl)
            : null;

        // ── Gigantamax sprite ───────────────────────────────────────────────
        final isGMaxActive = slot.hasGigantamax && slot.gigantamaxEnabled &&
            gmaxMoveForSpecies(pokemon.name) != null;
        final gmaxPokemon = isGMaxActive
            ? ref
                .watch(pokemonByNameProvider('${pokemon.name}-gmax'))
                .asData
                ?.value
            : null;
        final gmaxHomeUrl =
            gmaxPokemon != null ? pokemonHomeUrl(gmaxPokemon.id) : null;

        // Sprite priority: G-Max > Mega > Form change > default.
        final megaArtworkUrl = gmaxHomeUrl ?? megaHomeUrl ?? formHomeUrl;
        final megaArtworkFallback = gmaxHomeUrl != null
            ? gmaxPokemon?.officialArtworkUrl
            : megaHomeUrl != null
                ? megaOfficialUrl
                : formOfficialUrl;

        // Calculate final stats (uses mega base stats when applicable)
        final level = slot.level ?? 50;
        final evs = [
          slot.evHp ?? 0, slot.evAtk ?? 0, slot.evDef ?? 0,
          slot.evSpa ?? 0, slot.evSpd ?? 0, slot.evSpe ?? 0,
        ];
        final ivs = [
          slot.ivHp ?? 31, slot.ivAtk ?? 31, slot.ivDef ?? 31,
          slot.ivSpa ?? 31, slot.ivSpd ?? 31, slot.ivSpe ?? 31,
        ];
        // Form stats take priority over mega stats.
        final resolvedStats = formEffectiveStats ?? effectiveBaseStats;
        final calcStats = <int>[
          for (int i = 0; i < _statKeys.length; i++)
            _statKeys[i] == 'hp'
                ? _calcHP(resolvedStats['hp'] ?? 45, ivs[0], evs[0], level)
                : _calcStat(
                    resolvedStats[_statKeys[i]] ?? 50,
                    ivs[i], evs[i], level,
                    _natureMod(slot.natureName, _statKeys[i]),
                  ),
        ];

        // Item detail (for sprite)
        final itemEntry = itemAsync?.whenOrNull(data: (e) => e);

        // Sprite resolution — use format-aware sprites when setting is on
        final useFormatSprites = ref
            .watch(useFormatSpritesProvider)
            .asData?.value ?? true;
        final format = formatId != null
            ? ref.watch(formatServiceProvider).formatById(formatId!)
            : null;
        final spriteUrls = resolveSprite(
          sprites: pokemon.sprites,
          pokemonId: slot.pokemonId,
          pokemonName: pokemon.name,
          format: format,
          useFormatSprites: useFormatSprites,
        );

        // Slot validation against format (Layer 1)
        final validation = formatId != null
            ? ref
                .watch(slotValidationProvider((
                  slot: slot,
                  formatId: formatId!,
                )))
                .asData
                ?.value
            : null;
        final hasViolations = validation != null && !validation.isValid;

        final moves = [slot.move1, slot.move2, slot.move3, slot.move4]
            .where((m) => m != null)
            .cast<String>()
            .toList();

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: selected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: InkWell(
            onTap: onTap ?? () => context.push('/teams/$teamId/config/${slot.slot}'),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showSlotMenu(context, ref);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Coloured accent strip ──
                Container(
                  width: double.infinity,
                  color: effectiveTypeColor.withValues(alpha: 0.15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Text(
                        displayName,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (hasNickname) ...[
                        const SizedBox(width: 6),
                        Text(
                          speciesName,
                          style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                      const Spacer(),
                      if (hasViolations)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Tooltip(
                            message: validation.violations.values.join('\n'),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      FavoriteButton(
                          pokemonId: slot.pokemonId, iconSize: 18),
                      ReorderableDragStartListener(
                        index: dragIndex,
                        child: Icon(
                          Icons.drag_handle,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Main body ──
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Col 1 — Sprite + item icon + species
                      SizedBox(
                        width: 100,
                        child: Column(
                          children: [
                            Builder(builder: (ctx) {
                              final isFemale = slot.gender == 'female';
                              final genderUrl = isFemale
                                  ? (slot.isShiny
                                      ? pokemonHomeShinyFemaleUrl(pokemon.id)
                                      : pokemonHomeFemaleUrl(pokemon.id))
                                  : null;
                              final genderFallback = isFemale
                                  ? (slot.isShiny
                                      ? pokemonHomeShinyUrl(pokemon.id)
                                      : pokemonHomeUrl(pokemon.id))
                                  : null;
                              return PokemonSprite(
                                defaultUrl: megaArtworkUrl ??
                                    genderUrl ??
                                    spriteUrls.defaultUrl,
                                fallbackUrl: megaArtworkUrl != null
                                    ? megaArtworkFallback
                                    : genderUrl != null
                                        ? genderFallback
                                        : null,
                                shinyUrl: (megaArtworkUrl == null && genderUrl == null)
                                    ? spriteUrls.shinyUrl
                                    : null,
                                shiny: megaArtworkUrl == null &&
                                    genderUrl == null &&
                                    slot.isShiny,
                                size: 96,
                              );
                            }),
                            if (itemEntry?.spriteUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: CachedNetworkImage(
                                  imageUrl: itemEntry!.spriteUrl!,
                                  width: 36,
                                  height: 36,
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Col 2 — Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Types
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: effectiveTypes.values
                                  .map((t) => TypeBadge(type: t))
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                            // Level · gender · shiny
                            Row(
                              children: [
                                Text('Lv $level',
                                    style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                if (slot.gender != null) ...[
                                  Text(
                                    ' · ${_genderSymbol(slot.gender!)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: slot.gender == 'male'
                                          ? Colors.blue
                                          : slot.gender == 'female'
                                              ? Colors.pink
                                              : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (slot.isShiny) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.auto_awesome,
                                      size: 12, color: Colors.amber),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Item
                            if (slot.heldItemName != null)
                              Text(
                                slot.heldItemName!.toCapitalCase(),
                                style: textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            // Ability — show mega form ability when evolved
                            Builder(builder: (_) {
                              final abilityName = (isMegaApplicable &&
                                      megaPokemon != null &&
                                      megaPokemon.abilities.isNotEmpty)
                                  ? (megaPokemon.abilities.first['ability']
                                          as Map)['name'] as String
                                  : slot.abilityName;
                              if (abilityName == null) return const SizedBox.shrink();
                              return Text(
                                abilityName.toCapitalCase(),
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                            // Nature
                            if (slot.natureName != null)
                              Text(
                                slot.natureName!,
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Col 3 — Compact stat bars
                      SizedBox(
                        width: 88,
                        child: Column(
                          children: [
                            for (int i = 0; i < _statLabels.length; i++)
                              _CompactStatBar(
                                label: _statLabels[i],
                                value: calcStats[i],
                                ev: evs[i],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Moves strip ──
                if (moves.isNotEmpty) ...[
                  Divider(
                      height: 1,
                      color: colorScheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: moves
                          .map((m) => Text(
                                '• ${m.toCapitalCase()}',
                                style: textTheme.bodySmall,
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _genderSymbol(String gender) {
    switch (gender) {
      case 'male': return '♂';
      case 'female': return '♀';
      default: return '⚲';
    }
  }

  Future<void> _showSlotMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Configure slot'),
              onTap: () => Navigator.pop(ctx, 'config'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace Pokémon'),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remove from team'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == 'config') {
      if (onTap != null) {
        onTap!();
      } else {
        context.push('/teams/$teamId/config/${slot.slot}');
      }
    } else if (action == 'replace') {
      context.push('/teams/$teamId/pick/${slot.slot}');
    } else if (action == 'remove') {
      await ref
          .read(teamSlotRepositoryProvider)
          .deleteSlot(slot.teamId, slot.slot);
    }
  }
}

// ── Compact stat bar (for slot summary card) ──────────────────────────────────

class _CompactStatBar extends StatelessWidget {
  final String label;
  final int value;
  final int ev;

  const _CompactStatBar({
    required this.label,
    required this.value,
    required this.ev,
  });

  Color _barColor(ColorScheme cs, int ev) {
    if (ev >= 252) return Colors.green.shade600;
    if (ev > 0) return Colors.amber.shade700;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const maxStat = 700.0;
    final fraction = (value / maxStat).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _barColor(colorScheme, ev)),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              ev > 0 ? '$ev' : '',
              textAlign: TextAlign.right,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: ev >= 252
                    ? Colors.green.shade600
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty slot card ───────────────────────────────────────────────────────────

class _EmptySlotCard extends StatelessWidget {
  final int teamId;
  final int slotNumber;
  final int dragIndex;

  const _EmptySlotCard({
    required this.teamId,
    required this.slotNumber,
    required this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: () => context.push('/teams/$teamId/pick/$slotNumber'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 28,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Slot $slotNumber — tap to add Pokémon',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: dragIndex,
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
