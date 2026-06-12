# Pokédex List Screen Form Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a form chip to each Pokédex list card (tile and grid) so users can switch Pokémon forms inline without navigating to the detail screen.

**Architecture:** Convert `PokemonListTile` and `PokemonGridCard` from `ConsumerWidget` to `ConsumerStatefulWidget`, each holding ephemeral `String? _selectedFormName` state. Each card watches `pokemonSpeciesProvider` for varieties, computes battle + cosmetic form lists, and renders a chip that opens an extracted `FormPickerSheet`. Selecting a form updates the card's sprite, gradient, and display name in place.

**Tech Stack:** Flutter, Riverpod (`ConsumerStatefulWidget`, `FutureProvider.autoDispose.family`), `cached_network_image`, `go_router`.

**Spec:** `docs/superpowers/specs/2026-06-11-pokedex-form-switching-design.md`

---

## File Map

| Action | File |
|---|---|
| **Modify** | `lib/features/pokedex/logic/form_filter.dart` — add `kCosmeticVarietyNames`, `cosmeticFormLabel` |
| **Modify** | `lib/features/pokedex/logic/evolution_chain_builder.dart` — add `computeBaseFormLabel` |
| **Create** | `lib/features/pokedex/presentation/widget/form_picker_sheet.dart` |
| **Modify** | `lib/features/pokedex/presentation/pokemon_detail_screen.dart` — use shared picker, use `computeBaseFormLabel`, remove private classes |
| **Modify** | `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` — convert to stateful + form chip |
| **Modify** | `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart` — convert to stateful + form chip overlay |
| **Modify** | `test/unit/cosmetic_form_label_test.dart` — update import |
| **Modify** | `test/unit/evolution_chain_builder_test.dart` — add `computeBaseFormLabel` tests |

---

## Task 1: Move `kCosmeticVarietyNames` and `cosmeticFormLabel` to `form_filter.dart`

`kCosmeticVarietyNames` and `cosmeticFormLabel` are defined in `pokemon_detail_screen.dart` but needed by list card widgets too. Moving them to `form_filter.dart` removes the cross-feature import.

**Files:**
- Modify: `lib/features/pokedex/logic/form_filter.dart`
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`
- Modify: `test/unit/cosmetic_form_label_test.dart`

- [ ] **Step 1: Append to `form_filter.dart`**

Add this block at the end of `lib/features/pokedex/logic/form_filter.dart` (after `battleMeaningfulForms`):

```dart
/// Variety names that are purely cosmetic (same stats as base) and should
/// appear as cosmetic chips rather than in the Forms tab.
const kCosmeticVarietyNames = <String>{
  'wormadam-sandy', 'wormadam-trash',
  'squawkabilly-blue-plumage', 'squawkabilly-yellow-plumage', 'squawkabilly-white-plumage',
  'tatsugiri-droopy', 'tatsugiri-stretchy',
  'dudunsparce-three-segment',
  'basculin-blue-striped',
  'morpeko-hangry',
  'mimikyu-busted',
  'minior-red', 'minior-orange', 'minior-yellow', 'minior-green',
  'minior-blue', 'minior-indigo', 'minior-violet',
  'magearna-original',
  'eiscue-noice',
  'zarude-dada',
  'maushold-family-of-three',
  'keldeo-resolute',
};

/// Derives a display label from a PokéAPI cosmetic form suffix.
/// e.g. "red-flower" → "Red Flower", "sandy" → "Sandy", "a" → "A".
String cosmeticFormLabel(String formName) {
  if (formName.isEmpty) return 'Default';
  return formName
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
```

- [ ] **Step 2: Remove the definitions from `pokemon_detail_screen.dart`**

In `lib/features/pokedex/presentation/pokemon_detail_screen.dart`, delete lines 45–75 (the `kCosmeticVarietyNames` constant and `cosmeticFormLabel` function). The `form_filter.dart` import already exists on line 31 (`import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';`), so no new import is needed.

- [ ] **Step 3: Update the test import**

In `test/unit/cosmetic_form_label_test.dart`, replace:
```dart
import 'package:poke_team_dex/features/pokedex/presentation/pokemon_detail_screen.dart';
```
with:
```dart
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
```

- [ ] **Step 4: Verify tests still pass**

```bash
flutter test test/unit/cosmetic_form_label_test.dart
```

Expected: all tests pass (behaviour unchanged, only import moved).

- [ ] **Step 5: Commit**

```bash
git add lib/features/pokedex/logic/form_filter.dart \
        lib/features/pokedex/presentation/pokemon_detail_screen.dart \
        test/unit/cosmetic_form_label_test.dart
git commit -m "refactor: move kCosmeticVarietyNames and cosmeticFormLabel to form_filter.dart"
```

---

## Task 2: Add `computeBaseFormLabel` to `evolution_chain_builder.dart`

The detail screen has 10-line inline logic to compute the base-form chip label. Extract it into a testable public function so list cards can reuse it.

**Files:**
- Modify: `lib/features/pokedex/logic/evolution_chain_builder.dart`
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`
- Modify: `test/unit/evolution_chain_builder_test.dart`

- [ ] **Step 1: Write failing tests**

Append this group to `test/unit/evolution_chain_builder_test.dart`:

```dart
group('computeBaseFormLabel', () {
  PokemonVariety v(String name) => PokemonVariety(isDefault: false, name: name);

  test('all-female battle forms → Male', () {
    expect(
      computeBaseFormLabel('meowstic', null, [v('meowstic-female')]),
      'Male',
    );
  });

  test('regional form → generation adjective', () {
    expect(
      computeBaseFormLabel('zigzagoon', 'generation-iii', [v('zigzagoon-galar')]),
      'Hoennian',
    );
  });

  test('kBaseFormNameOverrides hit → override label', () {
    expect(
      computeBaseFormLabel('giratina-altered', null, [v('giratina-origin')]),
      'Altered',
    );
  });

  test('non-regional battle forms with no override → Base', () {
    expect(
      computeBaseFormLabel('rotom', null, [v('rotom-heat')]),
      'Base',
    );
  });

  test('no battle forms with generation → generation adjective', () {
    expect(
      computeBaseFormLabel('bulbasaur', 'generation-i', []),
      'Kantonian',
    );
  });

  test('no battle forms and no generation → Original', () {
    expect(
      computeBaseFormLabel('bulbasaur', null, []),
      'Original',
    );
  });

  test('Ogerpon override → Teal Mask', () {
    expect(
      computeBaseFormLabel('ogerpon', 'generation-ix', [
        v('ogerpon-wellspring-mask'),
        v('ogerpon-hearthflame-mask'),
        v('ogerpon-cornerstone-mask'),
      ]),
      'Teal Mask',
    );
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
flutter test test/unit/evolution_chain_builder_test.dart --name "computeBaseFormLabel"
```

Expected: FAIL — `computeBaseFormLabel` is not defined.

- [ ] **Step 3: Add function to `evolution_chain_builder.dart`**

Append after the `shortFormLabel` function in `lib/features/pokedex/logic/evolution_chain_builder.dart`:

```dart
/// Computes the label for the base/default form entry in the form picker.
///
/// Rules (in priority order):
/// 1. All non-default forms end in `-female` → base is male → "Male"
/// 2. At least one non-default form is regional → return regional adjective
///    for [generationName] (e.g. "Hoennian", "Galarian")
/// 3. [pokemonName] has a [kBaseFormNameOverrides] entry → return that label
/// 4. There are non-default battle forms but no regional or override → "Base"
/// 5. No non-default battle forms → return generation adjective or "Original"
String computeBaseFormLabel(
  String pokemonName,
  String? generationName,
  List<PokemonVariety> battleForms,
) {
  final allFemale = battleForms.isNotEmpty &&
      battleForms.every((v) => v.name.endsWith('-female'));
  final hasRegionalForm = battleForms.any((v) => regionalSuffixOf(v.name) != null);
  return allFemale
      ? 'Male'
      : hasRegionalForm
          ? shortBaseFormLabel(generationName)
          : kBaseFormNameOverrides[pokemonName] ??
            (battleForms.isNotEmpty
                ? 'Base'
                : shortBaseFormLabel(generationName));
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
flutter test test/unit/evolution_chain_builder_test.dart --name "computeBaseFormLabel"
```

Expected: all 7 tests pass.

- [ ] **Step 5: Replace inline logic in `pokemon_detail_screen.dart`**

In `lib/features/pokedex/presentation/pokemon_detail_screen.dart`, find the block inside `data: (basePokemon) {` that reads:

```dart
        final allFemale = battleForms.isNotEmpty &&
            battleForms.every((v) => v.name.endsWith('-female'));
        final hasRegionalForm =
            battleForms.any((v) => regionalSuffixOf(v.name) != null);
        final baseFormLabel = allFemale
            ? 'Male'
            : hasRegionalForm
                ? shortBaseFormLabel(species?.generationName)
                : kBaseFormNameOverrides[basePokemon.name] ??
                  (battleForms.isNotEmpty
                      ? 'Base'
                      : shortBaseFormLabel(species?.generationName));
```

Replace it with:

```dart
        final baseFormLabel = computeBaseFormLabel(
          basePokemon.name,
          species?.generationName,
          battleForms,
        );
```

- [ ] **Step 6: Run all unit tests to confirm no regressions**

```bash
flutter test test/unit/
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/pokedex/logic/evolution_chain_builder.dart \
        lib/features/pokedex/presentation/pokemon_detail_screen.dart \
        test/unit/evolution_chain_builder_test.dart
git commit -m "refactor: extract computeBaseFormLabel from detail screen to evolution_chain_builder"
```

---

## Task 3: Extract `FormPickerSheet` and `FormOptionTile` to shared widget

`_FormPickerSheet` and `_FormOptionTile` are private to `pokemon_detail_screen.dart`. Extract them as public widgets so list cards can use them without importing the detail screen.

**Files:**
- Create: `lib/features/pokedex/presentation/widget/form_picker_sheet.dart`
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`

- [ ] **Step 1: Create `form_picker_sheet.dart`**

Create `lib/features/pokedex/presentation/widget/form_picker_sheet.dart` with:

```dart
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
```

- [ ] **Step 2: Update `_FormBadge` in `pokemon_detail_screen.dart` to use `FormPickerSheet`**

Add this import near the top of `pokemon_detail_screen.dart` (after the other widget imports):

```dart
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
```

Then in `_FormBadge.build`, replace the `builder` argument of `showModalBottomSheet`:

Old:
```dart
        builder: (ctx) => _FormPickerSheet(
          battleForms: battleForms,
          baseFormLabel: baseFormLabel,
          baseSpriteUrl: baseSpriteUrl,
          baseShinyUrl: baseShinyUrl,
          selectedFormName: selectedFormName,
          shiny: shiny,
          onSelect: (name) {
            onSelect(name);
            Navigator.pop(ctx);
          },
        ),
```

New:
```dart
        builder: (ctx) => FormPickerSheet(
          allForms: [
            (null, baseFormLabel),
            ...battleForms.map((v) => (v.name, shortFormLabel(v.name))),
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
```

- [ ] **Step 3: Delete the private `_FormPickerSheet` and `_FormOptionTile` classes from `pokemon_detail_screen.dart`**

Find and delete the two class blocks (search for `// ── Form Picker Sheet` and `// ── Form Option Tile` comment headers and remove each block through its closing `}`). The `// ── Cosmetic Form Chips` section that follows must be left untouched.

- [ ] **Step 4: Verify detail screen tests still pass**

```bash
flutter test test/widget/pokemon_detail_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pokedex/presentation/widget/form_picker_sheet.dart \
        lib/features/pokedex/presentation/pokemon_detail_screen.dart
git commit -m "refactor: extract FormPickerSheet and FormOptionTile to shared widget"
```

---

## Task 4: Add form chip to `PokemonListTile`

Convert `PokemonListTile` to `ConsumerStatefulWidget`, add a `pokemonSpeciesProvider` watch, compute the form list, render the chip, update the sprite/gradient/name on form selection, and pass `?form=` on navigation when a non-default form is selected.

**Files:**
- Modify: `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart`

- [ ] **Step 1: Replace the file contents**

Replace the entire contents of `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` with:

```dart
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

  String _buildImageUrl(dynamic formEntry, PokedexFilter filter) {
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
```

> **Note:** `PokedexImageType` is defined in `pokemon_grid_card.dart`. The import `show PokedexImageType` re-exports only the enum — this is fine. If the project later wants to decouple them, move `PokedexImageType` to a shared file; for now this avoids duplication.

- [ ] **Step 2: Confirm the app compiles**

```bash
flutter analyze lib/features/pokedex/presentation/widget/pokemon_list_tile.dart
```

Expected: no errors (warnings for unused imports are fine to fix).

- [ ] **Step 3: Manual smoke test**

Run the app on a device or emulator:
```bash
flutter run
```

Navigate to the Pokédex list. Confirm:
1. Most cards show no chip (base-form Pokémon — Bulbasaur, Charmander, etc.)
2. Giratina (#487) shows a chip labeled "Altered"
3. Tapping the Giratina chip opens a bottom sheet with "Altered" and "Origin" tiles
4. Selecting "Origin" closes the sheet, updates the sprite/gradient, shows "Giratina - Origin" as the name
5. A `CircularProgressIndicator` briefly appears while the Origin artwork loads
6. Tapping the name when "Origin" is selected navigates to the Giratina detail screen with Origin pre-selected
7. Ogerpon (#1017) shows a chip for its mask forms; Meowstic (#678) shows a chip for Female; Squawkabilly (#931) shows a chip with plumage cosmetic forms
8. In compact layout (narrow window / phone) the chip appears on its own row below the type badges
9. In medium/expanded layout the chip appears inline with the type badges

- [ ] **Step 4: Commit**

```bash
git add lib/features/pokedex/presentation/widget/pokemon_list_tile.dart
git commit -m "feat: add form switching chip to PokemonListTile (#192)"
```

---

## Task 5: Add form chip to `PokemonGridCard`

Convert `PokemonGridCard` to `ConsumerStatefulWidget`, wrap the image area with a `Stack`, and overlay the form chip bottom-left over the artwork.

**Files:**
- Modify: `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart`

- [ ] **Step 1: Replace the file contents**

Replace the entire contents of `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart` with:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

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
    final formAsync = _selectedFormName != null
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

    // Effective types
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
        : colorScheme.surfaceContainerHighest;

    // Image URL
    final imageUrl = _buildImageUrl(formEntry);

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
              orElse: () =>
                  (_selectedFormName, shortFormLabel(_selectedFormName!)),
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
          if (_selectedFormName != null) {
            context
                .push('/pokedex/${widget.pokemon.id}?form=$_selectedFormName');
          } else {
            context.push('/pokedex/${widget.pokemon.id}');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with optional form-chip overlay
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
                  // Form chip overlay — bottom-left over artwork
                  if (hasFormChip)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
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

            // Info strip
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

  String _buildImageUrl(dynamic formEntry) {
    if (_selectedFormName != null && formEntry != null) {
      if (widget.imageType == PokedexImageType.artwork) {
        return formEntry.officialArtworkUrl ??
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
                'sprites/pokemon/other/official-artwork/${widget.pokemon.id}.png';
      }
      return (formEntry.sprites?['front_default'] as String?) ??
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
              'sprites/pokemon/${widget.pokemon.id}.png';
    }
    return switch (widget.imageType) {
      PokedexImageType.artwork =>
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
            'sprites/pokemon/other/official-artwork/${widget.pokemon.id}.png',
      PokedexImageType.sprite =>
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
            'sprites/pokemon/${widget.pokemon.id}.png',
    };
  }
}
```

- [ ] **Step 2: Confirm the app compiles**

```bash
flutter analyze lib/features/pokedex/presentation/widget/pokemon_grid_card.dart
```

Expected: no errors.

- [ ] **Step 3: Manual smoke test**

Switch the Pokédex to grid mode. Confirm:
1. Grid cards for base-form Pokémon show no chip
2. Giratina shows a dark semi-transparent chip labeled "Altered" overlaid bottom-left on the artwork
3. Tapping the chip opens the form picker sheet
4. Selecting "Origin" updates the artwork, gradient, and name ("Giratina - Origin") with a loading spinner while the artwork fetches
5. Tapping the card navigates to Giratina detail with Origin pre-selected
6. Hero animation works correctly for base-form navigation

- [ ] **Step 4: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pokedex/presentation/widget/pokemon_grid_card.dart
git commit -m "feat: add form switching chip to PokemonGridCard (#192)"
```

---

## Final: Open the PR

```bash
git push origin HEAD
gh pr create \
  --title "feat: form switching on Pokédex list screen (#192)" \
  --body "$(cat <<'EOF'
## Summary
- Adds a form-switching chip to `PokemonListTile` and `PokemonGridCard`
- Chip opens a bottom sheet picker; selecting a form updates sprite, gradient, and display name in place
- Tapping a card with a non-default form selected navigates to the detail screen with that form pre-selected
- Chip placement: inline with type badges on medium+ list tiles, own row on compact, overlaid on artwork for grid cards
- Extracts `FormPickerSheet`/`FormOptionTile` from the detail screen into a shared widget
- Moves `kCosmeticVarietyNames`/`cosmeticFormLabel` to `form_filter.dart`
- Adds `computeBaseFormLabel` pure function with unit tests

## Test plan
- [ ] Pokémon with no alternate forms (Bulbasaur, Charizard) show no chip
- [ ] Giratina shows chip; Origin form updates sprite, gradient (grey→ghost), name "Giratina - Origin"
- [ ] Ogerpon shows chip with 4 mask forms; each changes typing correctly
- [ ] Meowstic shows chip with Female form
- [ ] Squawkabilly shows chip with cosmetic plumage forms
- [ ] CircularProgressIndicator visible while form artwork loads
- [ ] Compact (< 600dp): chip appears on own row below type badges
- [ ] Medium+ list (≥ 600dp): chip appears inline with type badges
- [ ] Grid: chip overlaid bottom-left on artwork
- [ ] Tapping name with form selected navigates to detail with form pre-selected
- [ ] `flutter test` passes

Closes #192

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
