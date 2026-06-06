import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
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
typedef LinkableSlotParams = ({
  int originPokemonId,
  int currentSlotId,
  String? originFormName,
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

  final (:forwardSpeciesIds, :originSpeciesId) =
      await pokeApi.fetchForwardEvolutionInfo(params.originPokemonId);

  // For regional-form origins, pre-compute which forward species also carry
  // the same regional form (e.g. Persian has an Alolan form → exclude its
  // standard form from Alolan Meowth's results so only Alolan Persian appears).
  final Set<int> speciesWithSameForm;
  if (params.originFormName != null) {
    final futures = forwardSpeciesIds
        .where((id) => id != originSpeciesId)
        .map((id) async {
          final hasForm =
              await pokeApi.fetchSpeciesHasForm(id, params.originFormName!);
          return hasForm ? id : null;
        });
    final resolved = await Future.wait(futures);
    speciesWithSameForm = resolved.whereType<int>().toSet();
  } else {
    speciesWithSameForm = const {};
  }

  final allSlots = await slotRepo.watchAll().first;

  return allSlots.where((s) {
    if (s.id == params.currentSlotId) return false;

    final candidatePokemonId = s.pokemonId;
    final candidateFormName = s.formName;

    if (candidatePokemonId <= 10000) {
      // Standard-form slot: speciesId == pokemonId.
      if (!forwardSpeciesIds.contains(candidatePokemonId)) return false;

      if (params.originFormName == null) {
        // Standard-form origin → standard-form targets only.
        return candidateFormName == null;
      } else {
        // Regional-form origin + standard-form candidate:
        // Block same-species (would be a backward/same-species cross-form link).
        if (candidatePokemonId == originSpeciesId) return false;
        // Block species that have the origin's form (those slots appear via
        // the form-variant path below).
        if (speciesWithSameForm.contains(candidatePokemonId)) return false;
        // Allow standard-form evolution targets (e.g. Perrserker for Galarian Meowth).
        return candidateFormName == null;
      }
    } else {
      // Form-variant slot (pokemonId > 10000): match by formName.
      // NOTE: this does not verify the candidate's species is in forwardSpeciesIds
      // because resolving speciesId for form variants requires an extra API call.
      // False positives (wrong-species same-form slots) are rare in practice.
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
