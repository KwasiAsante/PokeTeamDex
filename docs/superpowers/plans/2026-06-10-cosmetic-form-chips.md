# Cosmetic Form Chips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add form-selection chips to the Pokédex detail screen header for Pokémon with cosmetic variants (Burmy, Shellos, Unown, Vivillon, Flabébé, etc.); tapping a chip updates the header artwork/sprite to that form's HOME artwork (pixel sprite fallback).

**Architecture:** Add `_selectedCosmeticFormName: String?` state to `_PokemonDetailScreenState`, watch `cosmeticFormsProvider(basePokemon.name)` in `build()`, thread the list + selection through both layout methods to `_DetailSliverAppBar` (narrow) and the wide-layout left rail. Chips show pixel sprites; header shows HOME artwork. ≤ 6 forms → inline horizontal chip strip; > 6 forms → single count chip opening a bottom sheet. No tab data changes — cosmetic forms share identical stats/moves/abilities.

**Tech Stack:** Flutter/Dart, Riverpod, `cached_network_image`, `flutter_test`.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `lib/features/pokedex/presentation/pokemon_detail_screen.dart` | Modify | All changes — state, layout wiring, new widgets, sprite URL logic |
| `test/unit/cosmetic_form_label_test.dart` | **Create** | Unit tests for `cosmeticFormLabel` helper |

All changes are in one file (following the existing pattern — `_FormBadge`, `_FormPickerSheet` etc. all live in `pokemon_detail_screen.dart`).

---

## Task 1: State wiring + data flow

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart` (lines ~44–190)

- [ ] **Add `_selectedCosmeticFormName` field**

  After `String? _selectedFormName;` (line ~47) add:
  ```dart
  String? _selectedCosmeticFormName; // null = base form sprite
  ```

- [ ] **Add `_selectBattleForm` helper to reset cosmetic form on battle form switch**

  In `_PokemonDetailScreenState`, add this method after the field declarations:
  ```dart
  void _selectBattleForm(String? formName) {
    setState(() {
      _selectedFormName = formName;
      _selectedCosmeticFormName = null; // cosmetic selection belongs to base species
    });
  }
  ```

- [ ] **Replace all inline `setState(() => _selectedFormName = name)` calls with `_selectBattleForm(name)`**

  There are several call sites. Search for `_selectedFormName = name` and replace each:
  - In `_buildNarrowLayout`: `onFormSelect: (name) => _selectBattleForm(name),`
  - In `_buildWideLayout` (AppBar actions): `onSelect: (name) => _selectBattleForm(name),`
  - In `_FormPickerSheet`'s onSelect call site in `_FormBadge.build()`: already closes via a passed callback — the callback itself is the one above, so no change needed in the widget.
  - Any remaining `setState(() => _selectedFormName = ...)` — replace similarly.

- [ ] **Watch `cosmeticFormsProvider` in `build()`**

  `cosmeticFormsProvider` is keyed by the pokemon name string, which requires `basePokemon.name`. Since `pokemonAsync` is already watched, derive the name from it synchronously:

  Add these two lines right after `final formAsync = ...` (around line ~111):
  ```dart
  final cosmPokemonName = pokemonAsync.asData?.value.name;
  final cosmeticFormsAsync = cosmPokemonName != null
      ? ref.watch(cosmeticFormsProvider(cosmPokemonName))
      : null;
  ```

- [ ] **Compute `cosmeticForms` inside `data: (basePokemon)`**

  Inside `data: (basePokemon)` (around line ~128), after the existing computed values, add:
  ```dart
  final cosmeticForms = cosmeticFormsAsync?.asData?.value ?? const <PokemonFormEntry>[];
  ```

- [ ] **Thread `cosmeticForms` through layout method signatures and calls**

  Update both `_buildNarrowLayout` and `_buildWideLayout` signatures to add:
  ```dart
  List<PokemonFormEntry> cosmeticForms,
  ```

  Update the `return isWide ? ...` call to pass `cosmeticForms`:
  ```dart
  return isWide
      ? _buildWideLayout(context, basePokemon, effectivePokemon, speciesAsync,
            headerColor, battleForms, baseFormLabel, cosmeticForms)
      : _buildNarrowLayout(context, basePokemon, effectivePokemon, speciesAsync,
            headerColor, battleForms, baseFormLabel, cosmeticForms);
  ```

- [ ] **Update `_DetailSliverAppBar` to accept cosmetic form params**

  Add these fields to `_DetailSliverAppBar`:
  ```dart
  final List<PokemonFormEntry> cosmeticForms;
  final String? selectedCosmeticFormName;
  final void Function(String?) onCosmeticFormSelect;
  ```
  Add corresponding required constructor params. For now just store them — rendering comes in Task 4.

- [ ] **Pass cosmetic form params in `_buildNarrowLayout`**

  In the `_DetailSliverAppBar(...)` call inside `_buildNarrowLayout`, add:
  ```dart
  cosmeticForms: cosmeticForms,
  selectedCosmeticFormName: _selectedCosmeticFormName,
  onCosmeticFormSelect: (name) => setState(() => _selectedCosmeticFormName = name),
  ```

- [ ] **Verify**

  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Expected: `No issues found!`

- [ ] **Commit**

  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: add _selectedCosmeticFormName state and cosmetic forms data flow"
  ```

---

## Task 2: `cosmeticFormLabel` helper + unit test

**Files:**
- Create: `test/unit/cosmetic_form_label_test.dart`
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart` (add helper function)

- [ ] **Write failing tests**

  Create `test/unit/cosmetic_form_label_test.dart`:
  ```dart
  // ignore_for_file: depend_on_referenced_packages
  import 'package:flutter_test/flutter_test.dart';
  import 'package:poke_team_dex/features/pokedex/presentation/pokemon_detail_screen.dart';

  void main() {
    group('cosmeticFormLabel', () {
      test('single word → capitalised', () {
        expect(cosmeticFormLabel('sandy'), 'Sandy');
      });
      test('hyphenated → title case words', () {
        expect(cosmeticFormLabel('red-flower'), 'Red Flower');
      });
      test('single letter (Unown) → capitalised', () {
        expect(cosmeticFormLabel('a'), 'A');
      });
      test('multi-segment Vivillon', () {
        expect(cosmeticFormLabel('icy-snow'), 'Icy Snow');
      });
      test('empty string → Default', () {
        expect(cosmeticFormLabel(''), 'Default');
      });
    });
  }
  ```

- [ ] **Run tests to confirm they fail**

  ```bash
  flutter test test/unit/cosmetic_form_label_test.dart
  ```
  Expected: compilation error — `cosmeticFormLabel` is not defined yet.

- [ ] **Add `cosmeticFormLabel` as a package-visible function in `pokemon_detail_screen.dart`**

  Note: the function must be top-level (not private) so the test can import it.
  Add this function near the top of the file, after the imports:

  ```dart
  /// Derives a display label from a PokéAPI cosmetic form name.
  /// e.g. "red-flower" → "Red Flower", "sandy" → "Sandy", "a" → "A".
  String cosmeticFormLabel(String formName) {
    if (formName.isEmpty) return 'Default';
    return formName.split('-')
        .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }
  ```

- [ ] **Run tests**

  ```bash
  flutter test test/unit/cosmetic_form_label_test.dart
  ```
  Expected: all 5 tests pass.

- [ ] **Commit**

  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart \
          test/unit/cosmetic_form_label_test.dart
  git commit -m "feat: add cosmeticFormLabel helper with unit tests"
  ```

---

## Task 3: `_CosmeticFormChip`, `_CosmeticFormCountChip`, and `_CosmeticFormPickerSheet` widgets

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart` (add widgets at bottom)

- [ ] **Add the three new widgets at the bottom of `pokemon_detail_screen.dart`** (before the final `}`):

  ```dart
  // ── Cosmetic Form Chips ───────────────────────────────────────────────────────

  /// Horizontal strip of cosmetic form chips (≤ 6 forms) or a single count
  /// chip that opens a picker sheet (> 6 forms).
  class _CosmeticFormRow extends StatelessWidget {
    final List<PokemonFormEntry> forms;
    final String? selectedFormName;
    final bool shiny;
    final void Function(String?) onSelect;

    const _CosmeticFormRow({
      required this.forms,
      required this.selectedFormName,
      required this.shiny,
      required this.onSelect,
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
                  placeholder: (_, _) =>
                      const SizedBox(width: 28, height: 28),
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.catching_pokemon, color: Colors.white54, size: 20),
                )
              else
                const SizedBox(width: 28, height: 28),
              const SizedBox(width: 4),
              Text(
                cosmeticFormLabel(form.formName),
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

    const _CosmeticFormPickerSheet({
      required this.forms,
      required this.selectedFormName,
      required this.shiny,
      required this.onSelect,
    });

    @override
    Widget build(BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
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
              spacing: 10,
              runSpacing: 10,
              children: forms.map((f) {
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
                          )
                        else
                          const SizedBox(height: 52, width: 52,
                              child: Icon(Icons.catching_pokemon,
                                  color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          cosmeticFormLabel(f.formName),
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
              }).toList(),
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Verify**

  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Expected: `No issues found!`

- [ ] **Commit**

  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: add _CosmeticFormRow, _CosmeticFormChip, _CosmeticFormPickerSheet widgets"
  ```

---

## Task 4: Update `_DetailSliverAppBar` — sprite switching + narrow chip row

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart` (lines ~357–460)

- [ ] **Update `_DetailSliverAppBar.build()` to compute the cosmetic-form sprite URLs and dynamic `expandedHeight`**

  In `_DetailSliverAppBar.build()`, add these computations before the `return SliverAppBar(`:

  ```dart
  // Resolve the cosmetic form to display (if one is selected).
  final selectedCosmetic = selectedCosmeticFormName != null
      ? cosmeticForms.where((f) => f.name == selectedCosmeticFormName).firstOrNull
      : null;

  // HOME artwork for the selected cosmetic form; falls back to form sprite.
  final displayDefaultUrl = selectedCosmetic != null
      ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/${selectedCosmetic.id}.png'
      : effectivePokemon.officialArtworkUrl;
  final displayShinyUrl = selectedCosmetic != null
      ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/${selectedCosmetic.id}.png'
      : effectivePokemon.officialArtworkShinyUrl;

  // Expand header when cosmetic chips are present (44 dp for chip row).
  final expandedHeight = cosmeticForms.isNotEmpty ? 324.0 : 280.0;
  ```

- [ ] **Update `expandedHeight` and sprite URLs in the `SliverAppBar`**

  Change `expandedHeight: 280,` to `expandedHeight: expandedHeight,`

  Change the `PokemonSprite(...)` inside `FlexibleSpaceBar` from the existing hardcoded urls to:
  ```dart
  PokemonSprite(
    defaultUrl: displayDefaultUrl,
    shinyUrl: displayShinyUrl,
    shiny: shiny,
    size: 200,
  )
  ```

- [ ] **Update `FlexibleSpaceBar` background to show chips below the sprite**

  Replace the current `FlexibleSpaceBar.background` with a version that puts the sprite + chips in a Column:

  ```dart
  flexibleSpace: FlexibleSpaceBar(
    background: Container(
      color: headerColor.withValues(alpha: 0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 56), // clear the collapsed app bar
          Hero(
            tag: 'pokemon-sprite-${basePokemon.id}',
            child: PokemonSprite(
              defaultUrl: displayDefaultUrl,
              shinyUrl: displayShinyUrl,
              shiny: shiny,
              size: 200,
            ),
          ),
          if (cosmeticForms.isNotEmpty) ...[
            const SizedBox(height: 6),
            _CosmeticFormRow(
              forms: cosmeticForms,
              selectedFormName: selectedCosmeticFormName,
              shiny: shiny,
              onSelect: onCosmeticFormSelect,
            ),
          ],
        ],
      ),
    ),
  ),
  ```

- [ ] **Verify**

  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Expected: `No issues found!`

- [ ] **Commit**

  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: update narrow header for cosmetic form sprite switching and chip row"
  ```

---

## Task 5: Update wide layout left rail

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart` (lines ~200–300)

The wide layout has a left rail with a `PokemonSprite` and type badges. Update it to:
1. Use cosmetic form HOME artwork when a form is selected
2. Show chips below the type badges

- [ ] **Compute cosmetic form sprite URLs in `_buildWideLayout`**

  At the top of `_buildWideLayout`, after `final textTheme = ...`, add:
  ```dart
  final wideSelectedCosmetic = _selectedCosmeticFormName != null
      ? cosmeticForms.where((f) => f.name == _selectedCosmeticFormName).firstOrNull
      : null;
  final wideDisplayUrl = wideSelectedCosmetic != null
      ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/${wideSelectedCosmetic.id}.png'
      : effectivePokemon.officialArtworkUrl;
  final wideShinyUrl = wideSelectedCosmetic != null
      ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/${wideSelectedCosmetic.id}.png'
      : effectivePokemon.officialArtworkShinyUrl;
  ```

- [ ] **Update the wide-layout sprite to use `wideDisplayUrl` / `wideShinyUrl`**

  Find the `PokemonSprite` in the left rail (uses `effectivePokemon.officialArtworkUrl`). Change it to:
  ```dart
  PokemonSprite(
    defaultUrl: wideDisplayUrl,
    shinyUrl: wideShinyUrl,
    shiny: _shiny,
    size: 140,
  ),
  ```

- [ ] **Add cosmetic chip row below the type badges in the left rail**

  In the left rail column, after the type badges section (look for `TypeBadges` or the row of type chips), add:
  ```dart
  if (cosmeticForms.isNotEmpty) ...[
    const SizedBox(height: 8),
    _CosmeticFormRow(
      forms: cosmeticForms,
      selectedFormName: _selectedCosmeticFormName,
      shiny: _shiny,
      onSelect: (name) => setState(() => _selectedCosmeticFormName = name),
    ),
  ],
  ```

- [ ] **Verify**

  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Expected: `No issues found!`

- [ ] **Run all tests**

  ```bash
  flutter test test/unit/
  ```
  Expected: all pass (including the 5 `cosmeticFormLabel` tests).

- [ ] **Commit**

  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: cosmetic form chip row and sprite switching in wide layout left rail"
  ```

---

## Task 6: Branch, push, open PR

- [ ] **Create branch and push**

  ```bash
  git checkout -b feat/cosmetic-form-chips
  git push origin feat/cosmetic-form-chips
  ```

- [ ] **Open PR**

  ```bash
  gh pr create \
    --title "feat: cosmetic form chips in Pokédex detail header" \
    --body "$(cat <<'EOF'
  ## Summary

  - Adds form-selection chips to the Pokédex detail screen header for cosmetic-variant species (Burmy cloaks, Shellos seas, Unown letters, Vivillon patterns, Flabébé flowers, etc.)
  - ≤ 6 forms → inline horizontal chip strip below the sprite in the header; > 6 forms → single count chip (e.g. \"18 forms ▾\") that opens a bottom sheet picker
  - Tapping a chip switches the header artwork to that form's HOME artwork (pixel sprite fallback via CachedNetworkImage error handler)
  - Shiny toggle applies to the selected cosmetic form
  - Tapping the already-selected chip deselects it (returns to base form)
  - Switching battle form (via the app bar badge) resets the cosmetic form selection
  - No tab data changes — all tabs remain identical (cosmetic forms share stats/moves/abilities)

  ## Test plan

  - [ ] Burmy (#412) → 2 cosmetic forms → inline chips visible in header; tapping \"Sandy\" shows sandy cloak artwork
  - [ ] Shellos (#422) → 1 cosmetic form → single chip; tapping switches to east sea form
  - [ ] Vivillon (#666) → 18 forms → \"18 forms ▾\" chip → picker sheet
  - [ ] Unown (#201) → 27 forms → picker sheet
  - [ ] Flabébé (#669) → 4 cosmetic forms → inline chips
  - [ ] Pikachu (#025) → 0 cosmetic forms → no chips, `expandedHeight` stays 280
  - [ ] Shiny toggle while cosmetic form selected → shows shiny sprite/artwork
  - [ ] Switch battle form → cosmetic form selection resets

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  EOF
  )"
  ```
