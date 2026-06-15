import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/data/form_filter.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final teamSlotsProvider =
    StreamProvider.autoDispose.family<List<TeamSlot>, int>((ref, teamId) {
  return ref.watch(teamSlotRepositoryProvider).watchByTeam(teamId);
});

final teamByIdProvider =
    StreamProvider.autoDispose.family<Team?, int>((ref, teamId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.teams)..where((t) => t.id.equals(teamId)))
      .watchSingleOrNull();
});

final slotItemDetailProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) =>
        ref.read(pokeApiRepositoryProvider).fetchItem(name));

// ── Pokemon Instance providers ────────────────────────────────────────────────

/// All non-deleted slots across every team that contain [pokemonId].
/// Used by the instance picker sheet to find linkable siblings.
final slotsBySpeciesProvider =
    StreamProvider.family<List<TeamSlot>, int>((ref, pokemonId) =>
        ref.watch(teamSlotRepositoryProvider).watchByPokemonId(pokemonId));

/// Named record used as the family key for [linkableSlotsProvider].
///
/// [forwardDirection] controls which end of the evolution chain is shown:
/// - true  → slot acts as ORIGIN, show forward-evolution (child) targets
/// - false → slot acts as CHILD, show backward-evolution (origin/ancestor) targets
typedef LinkableSlotParams = ({
  int originPokemonId,
  int currentSlotId,
  String? originFormName,
  bool forwardDirection,
});

/// Returns all slots that are valid link targets for [params.originPokemonId].
///
/// Rules (issue #102):
/// - Only slots reachable FORWARD in the origin's evolution chain are shown.
/// - Standard-form origins only see standard-form targets.
/// - Regional-form origins see same-region targets OR single-form evolution
///   targets (e.g. Galarian Meowth can still link to Perrserker even though
///   Perrserker has no "galar" form).
///
/// Known limitation: when multiple branches diverge from the same species
/// (e.g. Meowth → Persian vs Meowth → Perrserker) and one branch is
/// form-specific, we cannot determine from PokéAPI's chain data alone which
/// branch a given regional form uses. Standard-form slots for ALL branches are
/// shown; the user should pick the correct one.
final linkableSlotsProvider =
    FutureProvider.autoDispose.family<List<TeamSlot>, LinkableSlotParams>(
        (ref, params) async {
  final pokeApi = ref.read(pokeApiRepositoryProvider);
  final slotRepo = ref.read(teamSlotRepositoryProvider);

  // Resolve the valid species set depending on the picker role.
  final Set<int> validSpeciesIds;
  final int originSpeciesId;
  Set<int> speciesWithSameForm = const {};

  if (params.forwardDirection) {
    // Origin role → show slots of FORWARD (post-evolution) species.
    final info = await pokeApi.fetchForwardEvolutionInfo(params.originPokemonId);
    validSpeciesIds = info.forwardSpeciesIds;
    originSpeciesId = info.originSpeciesId;

    // Pre-compute which forward species also carry the origin's regional form
    // so the standard-form slot for that species is suppressed (the regional
    // form slot appears via the pokemonId > 10000 path instead).
    if (params.originFormName != null) {
      final futures = validSpeciesIds
          .where((id) => id != originSpeciesId)
          .map((id) async {
            final hasForm =
                await pokeApi.fetchSpeciesHasForm(id, params.originFormName!);
            return hasForm ? id : null;
          });
      final resolved = await Future.wait(futures);
      speciesWithSameForm = resolved.whereType<int>().toSet();
    }
  } else {
    // Child role → show slots of BACKWARD (pre-evolution / ancestor) species.
    final info = await pokeApi.fetchBackwardEvolutionInfo(params.originPokemonId);
    validSpeciesIds = info.ancestorSpeciesIds;
    originSpeciesId = info.originSpeciesId;
    // No speciesWithSameForm needed for backward direction.
  }

  // Snapshot valid (non-deleted) team IDs to exclude orphaned slot rows.
  final validTeams = await ref.read(teamRepositoryProvider).getAll();
  final validTeamIds = validTeams.map((t) => t.id).toSet();

  final allSlots = await slotRepo.watchAll().first;

  // Pre-resolve species IDs for all form-variant candidates (cached, cheap).
  // This lets us allow same-species cross-form links (e.g. Aegislash Shield/Sword,
  // Meowstic male/female, Lycanroc forms) without requiring an exact formName match.
  final formVariantIds = allSlots
      .where((s) => s.pokemonId > 10000 && s.id != params.currentSlotId)
      .map((s) => s.pokemonId)
      .toSet();
  final formVariantSpecies = <int, int>{};
  await Future.wait(formVariantIds.map((id) async {
    formVariantSpecies[id] = await pokeApi.getSpeciesId(id);
  }));

  return allSlots.where((s) {
    if (s.id == params.currentSlotId) return false;
    if (!validTeamIds.contains(s.teamId)) return false;

    final candidatePokemonId = s.pokemonId;
    final candidateFormName = s.formName;
    final isMutable = kMutableFormSpeciesIds.contains(originSpeciesId);

    if (candidatePokemonId <= 10000) {
      // Standard-form slot: speciesId == pokemonId.
      if (!validSpeciesIds.contains(candidatePokemonId)) return false;

      if (candidatePokemonId == originSpeciesId) {
        // Same species, base-form candidate.
        // Mutable species (Aegislash, Darmanitan Zen, etc.) → allow any form.
        if (isMutable) return true;
        // Immutable: origin must also be a base-form slot; form-variant origins
        // (originPokemonId > 10000) represent a different, fixed form.
        if (params.originPokemonId != originSpeciesId) return false;
        // Both base-form: require matching formName (same permanent form).
        return candidateFormName == params.originFormName;
      }

      // Different species (cross-evolution):
      if (params.originFormName == null) {
        return candidateFormName == null;
      } else {
        // Regional-form origin: suppress species that also carry this regional
        // form (their form-variant slot appears via the pokemonId > 10000 path).
        if (speciesWithSameForm.contains(candidatePokemonId)) return false;
        return candidateFormName == null;
      }
    } else {
      // Form-variant slot (pokemonId > 10000).
      final candidateSpeciesId = formVariantSpecies[candidatePokemonId];
      if (candidateSpeciesId == null) return false;

      if (candidateSpeciesId == originSpeciesId) {
        // Same species, form-variant candidate.
        // Mutable species → allow any form.
        if (isMutable) return true;
        // Immutable: require the same pokemonId (same form-variant, e.g.
        // meowstic-female slot can only link to another meowstic-female slot).
        return candidatePokemonId == params.originPokemonId;
      }

      // Cross-species form-variant (e.g. Alolan Meowth → Alolan Persian):
      // must be in the valid evolution set and carry the same regional form.
      if (!validSpeciesIds.contains(candidateSpeciesId)) return false;
      if (params.originFormName == null) return false;
      return candidateFormName == params.originFormName;
    }
  }).toList();
});

/// All teams, kept alive for name lookups in the instance chain view.
final allTeamsProvider =
    StreamProvider<List<Team>>((ref) =>
        ref.watch(teamRepositoryProvider).watchAll());

/// Full instance chain (oldest → newest) for [instanceId].
final instanceChainProvider =
    FutureProvider.autoDispose.family<List<PokemonInstance>, int>(
        (ref, instanceId) =>
            ref.read(pokemonInstanceRepositoryProvider).getChain(instanceId));
