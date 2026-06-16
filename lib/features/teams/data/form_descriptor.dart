import 'package:poke_team_dex/data/pokemon_data_registry.dart';

/// Wraps all form-state columns from [TeamSlotsData] into a single value object.
/// No I/O — constructed from a DB row, passed to widgets and resolvers.
class FormDescriptor {
  final String? formName;
  final bool isShiny;
  final bool isMegaEvolved;
  final bool hasGigantamax;
  final bool gigantamaxEnabled;
  final bool isAlpha;
  final String? gender;

  const FormDescriptor({
    this.formName,
    this.isShiny = false,
    this.isMegaEvolved = false,
    this.hasGigantamax = false,
    this.gigantamaxEnabled = false,
    this.isAlpha = false,
    this.gender,
  });

  factory FormDescriptor.empty() => const FormDescriptor();

  /// Reads form-state columns from a generated Drift data class.
  /// Import the generated data class at the call site — FormDescriptor itself
  /// has no Drift dependency.
  static FormDescriptor from({
    required String? formName,
    required bool isShiny,
    required bool isMegaEvolved,
    required bool hasGigantamax,
    required bool gigantamaxEnabled,
    required bool isAlpha,
    required String? gender,
  }) => FormDescriptor(
    formName: formName,
    isShiny: isShiny,
    isMegaEvolved: isMegaEvolved,
    hasGigantamax: hasGigantamax,
    gigantamaxEnabled: gigantamaxEnabled,
    isAlpha: isAlpha,
    gender: gender,
  );

  static const _sentinel = Object();

  /// Returns a copy with optionally updated fields.
  /// Pass [clearFormName: true] to set formName to null (selecting default form).
  FormDescriptor copyWith({
    Object? formName = _sentinel,
    bool? isShiny,
    bool? isMegaEvolved,
    bool? hasGigantamax,
    bool? gigantamaxEnabled,
    bool? isAlpha,
    Object? gender = _sentinel,
    bool clearFormName = false,
    bool clearGender = false,
  }) => FormDescriptor(
    formName: clearFormName
        ? null
        : (formName == _sentinel ? this.formName : formName as String?),
    isShiny: isShiny ?? this.isShiny,
    isMegaEvolved: isMegaEvolved ?? this.isMegaEvolved,
    hasGigantamax: hasGigantamax ?? this.hasGigantamax,
    gigantamaxEnabled: gigantamaxEnabled ?? this.gigantamaxEnabled,
    isAlpha: isAlpha ?? this.isAlpha,
    gender: clearGender
        ? null
        : (gender == _sentinel ? this.gender : gender as String?),
  );

  /// True when no form variation is active.
  bool get isDefault =>
      formName == null && !isMegaEvolved && !gigantamaxEnabled;

  /// The PokeAPI /pokemon/{name} endpoint to fetch for this form's
  /// stats, abilities, types, and moves.
  ///
  /// Pass [heldItem] to resolve the mega form name when [isMegaEvolved] is true.
  String effectiveApiName(String baseSpecies, String? heldItem) {
    if (isMegaEvolved && heldItem != null) {
      final entry = PokemonDataRegistry.instance.megaStoneMap[heldItem];
      if (entry != null) return entry.megaForm;
    }
    if (formName != null) return formName!;
    return baseSpecies;
  }

}
