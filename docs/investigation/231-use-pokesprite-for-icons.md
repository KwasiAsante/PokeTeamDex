# Investigation: Use PokeSprite as a Resource for Icons

**Issue:** [#231](https://github.com/KwasiAsante/PokeTeamDex/issues/231)  
**Branch:** `investigation/use-pokesprite-for-icons`  
**Status:** Investigation complete — ready for implementation

---

## 0. Summary

Box icons from PokéAPI are badly sized relative to each other. The cause is that our icon chain mixes **three canvas sizes plus one set that isn't box icons at all**. [PokeSprite](https://github.com/msikma/pokesprite) fixes this for Gen 1–8: every Pokémon, Mega, G-Max and cosmetic form is on one 68×56 canvas at a consistent pixel scale. It has **no Gen 9 icons** and is effectively unmaintained.

**Recommendation:** use this source chain, hotlinked from `raw.githubusercontent.com` and pinned to a commit SHA:

1. **PokeSprite** for Gen 1–8, including Megas, G-Max, Hisui and cosmetic forms
2. **[bamq/pokemon-sprites](https://github.com/bamq/pokemon-sprites)** for Gen 9 and Paldean forms. These are PokeSprite-compatible 68×56 icons.
3. **The existing PokéAPI chain from #328** for real gaps only, mainly the Legends Z-A Megas. Its images are scale-corrected so they don't break calibration.

The work splits into 5 tasks (§5).

---

## 1. Background

| Date | Event |
|---|---|
| 2026-06-15 | #231 filed: PokéAPI icon sizes "not well calibrated". |
| 2026-10-16 | [PokeAPI/sprites#295](https://github.com/PokeAPI/sprites/pull/295) deleted `sprites/pokemon/versions/generation-viii/icons/`. The `/pokemon/{id}` response dropped `versions.generation-viii.icons`. Every icon URL we built started returning 404. |
| 2026-11-27 | #327 / PR #328 repointed icons to a chain of PokéAPI folders (`kIconFolders`: Sword/Shield → Gen VII → Scarlet/Violet), walked on 404 by the new `FallbackNetworkImage`. |

PR #328 fixed the 404s but not the calibration. For Gen 9 it made calibration worse (§2.1).

---

## 2. Research Findings

### 2.1 Measured canvases and subject fill

I downloaded the same Pokémon from each source and measured the canvas and the non-transparent bounding box of the Pokémon itself. Samples: Pikachu, Charizard, Snorlax, Rayquaza, Shellos-East, Eternatus, plus Sprigatito, Miraidon and Pecharunt for Gen 9.

| Source | Canvas | Pikachu subject | Eternatus/Rayquaza subject | Behaviour |
|---|---|---|---|---|
| PokeSprite `pokemon-gen8/regular` | **68×56, uniform** | 21×20 (11% fill) | 58×49 (74%) | ✅ Relative scale: small Pokémon look small |
| PokéAPI `generation-viii/sword-shield/icons` | 68×68, uniform | 21×20 (9%) | 58×49 (61%) | Same art as PokeSprite plus 12px of padding, so it renders ~18% smaller in the slot |
| PokéAPI `generation-vii/icons` (Megas in #328 chain) | 40×30 | 21×20 (35%) | 31×27 (69%) | Relative, but low-res. `BoxFit.contain` in the 60×50 team slot upscales it 1.5×, so **Megas show at ≈2× the scale of their base form** |
| PokéAPI `generation-ix/scarlet-violet/icons` (Gen 9 in #328 chain) | **Varies, tightly cropped** (Pikachu 119×131, Rayquaza 203×219) | 100% fill | 100% fill | ❌ HD menu renders, not box icons. **Every Gen 9 Pokémon fills the slot.** |
| PokéAPI `generation-ix/champions/icons` | 128×128 | 120×120 (87%) | 126×126 (96%) | ❌ Near-fill, not relative |

With `BoxFit.contain` in the 60×50 team slot, a team containing a Sword/Shield icon, a Gen VII Mega and a Scarlet/Violet Gen 9 Pokémon shows three different scales. That is the "not well calibrated" symptom.

> The `kIconFolders` doc comment in `sprite_url_builder.dart` says "All three use the small pixel 'box icon' style". That is inaccurate for Scarlet/Violet.

### 2.2 PokeSprite (msikma/pokesprite)

| Property | Finding |
|---|---|
| License | MIT for the code. Sprite art is © Nintendo / Game Freak, as with every other source we use. |
| Hosting | `raw.githubusercontent.com` returns `Access-Control-Allow-Origin: *`, so web works. We already hotlink its ribbons (`lib/features/teams/data/ribbon_catalog.dart`). |
| Maintenance | Last push 2024-05-07. The rewrite announced in [#136](https://github.com/msikma/pokesprite/issues/136) (Jan 2023) never shipped. Gen 9 has been requested since 2022 ([#135](https://github.com/msikma/pokesprite/issues/135), [#141](https://github.com/msikma/pokesprite/issues/141)). Treat it as frozen. |
| Coverage | `pokemon-gen8/regular` 1,332, `shiny` 1,333, `regular/female` 20. Dex **1–905**, including 48 Mega forms, 34 G-Max forms, Hisui forms, and cosmetic forms (Alcremie, Vivillon, Shellos, Unown, Pikachu caps). |
| Gaps | All of Gen 9 (906–1025), Paldean forms (Tauros-Paldea, Wooper-Paldea), and the 2025 Legends Z-A Megas (Raichu-Mega-X/Y, Garchomp-Mega-Z, …). |
| Keying | **Name-based** (`calyrex-ice-rider.png`, `pikachu-original-cap.png`), not ID-based like PokéAPI. `data/pokemon.json` maps dex number → English slug plus a `gen-8.forms` table with `is_alias_of`. For example, Toxtricity `low-key-gmax` is an alias of `gmax`, and Urshifu `single-strike-gmax` is an alias of `gmax`. |
| Size | `regular` ≈ 0.85 MB, `shiny` ≈ 0.9 MB. |

### 2.3 bamq/pokemon-sprites (Gen 9 companion)

| Property | Finding |
|---|---|
| Purpose | "Pokémon icons meant to work with the ones from @msikma/pokesprite": Gen 9 icons resized to **68×56** in the same slug style. |
| Coverage | 163 regular plus 163 shiny, with `female/` directories. Covers Gen 9 base species and Paldean/Hisuian forms. |
| Gaps | Squawkabilly colours, Maushold-Four, Gimmighoul-Roaming, some Ogerpon/Poltchageist/Sinistcha naming differences, and all Legends Z-A Megas. |
| License | **No license file.** The art comes from the DeviantArt "National Pokédex Version Delta" project, credited in its README. This is a hotlinking/attribution risk, not a blocker; see §4. |
| Maintenance | Last push 2024-09-24. |

### 2.4 Alternatives considered

| Option | Verdict |
|---|---|
| Stay on the PokéAPI folder chain from #328 | Calibration stays broken (§2.1), and it just broke once from an upstream restructure. |
| PokéAPI Champions / Legends Z-A icons | Has Z-A Megas and shinies, but uses near-fill HD renders (not relative), and covers only 453/561 species. |
| Showdown `pokemonicons-sheet.png` | One 40×30 sprite sheet covering everything, but low-res, needs sheet-offset math, and the Showdown CDN is blocked by CORS on web (already noted in `sprite_url_builder.dart`). |
| Bundle icons as app assets | Survives upstream changes and works offline, but adds ~1–2 MB. **Rejected by decision**: hotlink, but pin to a commit SHA (§3). |

### 2.5 Codebase trace (after #328)

| Layer | File | Role |
|---|---|---|
| Backend URL builder | `backend/app/services/pokemon_resolver.py` | `_build_icon_url`, `_api_icon_url`, `_ICON_VERSION_KEYS`. Writes `sprite_urls.icon` / `icon_female` / `icon_shiny` |
| Backend cache | same file | `/resolved` rows cached 7 days (`ttl_days=7`); flushed via `DELETE /admin/cache/pokemon?all=true` |
| Backend schema | `backend/app/schemas/pokemon_resolved.py` | `icon_shiny` is documented as "game_front_shiny (no dedicated shiny icon sprites exist)". PokeSprite makes that false. |
| Flutter mirror | `lib/services/pokemon_resolved/sprite_url_builder.dart` | `buildIconUrl`, `apiIconUrl`, `iconUrlCandidates`, `genderedIconUrlCandidates`, `kIconFolders`. Must stay identical to the backend |
| Fallback widget | `lib/shared/widgets/fallback_network_image.dart` | Walks a URL list on load error |
| Consumers | `lib/features/teams/presentation/teams_screen.dart` (`_SlotSprite`, `_SlotSpriteFormAware`, 60×50 slot); `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` / `pokemon_grid_card.dart`; move/ability/item detail cross-reference lists; `PokemonDataResolver.resolvePokedexImageUrl` (compact mode) | Display |
| Shared registry | `shared/pokemon_registry.json` (bundled in `pubspec.yaml`, copied in `backend/Dockerfile`) | Pattern to reuse for a generated icon map |
| Slot data | `lib/database/tables/team_slots_table.dart` (`isShiny`, `gender`) | Enables shiny and female icons |

---

## 3. Questions Answered

**Is PokeSprite better calibrated than PokéAPI?**  
Yes. It uses one uniform 68×56 canvas with consistent relative scale across all of Gen 1–8, including Megas and G-Max. In the #328 chain, Megas come from 40×30 Gen VII icons and Gen 9 comes from cropped HD renders.

**Can PokeSprite be the only source?**  
No. It has no Gen 9 icons, and upstream is frozen. bamq fills most of Gen 9 at the same canvas. The PokéAPI chain remains the last resort.

**How do we map our data to PokeSprite filenames?**  
Generate the mapping with a script, don't hand-write it. PokéAPI variety/form names are joined to PokeSprite slugs through `data/pokemon.json`, with `is_alias_of` resolved. A small override table covers mismatches such as `calyrex-ice` → `calyrex-ice-rider` and `pikachu-original` → `pikachu-original-cap`. The script lists anything still uncovered.

**Hotlink or bundle?**  
Hotlink, pinned to a commit SHA rather than `master`/`main`:
- PokeSprite: `c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e`
- bamq: `c1958e7260a4bce93bd104e79966a27fb333c7aa`

An upstream rename or deletion like PokeAPI/sprites#295 then cannot break us. Updating means bumping the SHA and re-running the script.

**Which scale style?**  
Relative (box-icon): small Pokémon stay small, matching the in-game PC box.

**Shiny and female icons?**  
Both sources ship `shiny/` and `female/` directories. `team_slots.isShiny` already exists, so team slots can show real shiny icons. Today `iconShiny` just mirrors `gameFrontShiny`.

---

## 4. Risks

| Risk | Mitigation |
|---|---|
| Upstream repos deleted or restructured | Pin SHAs. Keep the PokéAPI chain as a fallback in `iconUrlCandidates`. |
| bamq has no license | Credit bamq and the Version Delta artists in the README/About screen. Treat it as an accepted risk; it can be removed later, and Gen 9 then falls through to the scale-normalised PokéAPI fallback. |
| Name-mapping drift when new forms are added | The generator script prints an uncovered list. Re-run it whenever `shared/ps_data` is synced. |
| Stale cached backend URLs after rollout | Flush the `/resolved` cache on deploy. Client-side `iconUrlCandidates` already rewrites legacy URLs. |
| Fallback images still miscalibrated (Z-A Megas) | Task 3 normalises fallback scale. |

---

## 5. Implementation Plan

Each task is independently shippable and becomes a sub-issue of #231 after this PR merges.

### Task 1: Icon map generator
- New `scripts/build_icon_map.py`. Reads PokeSprite `data/pokemon.json` plus its git tree, the bamq git tree, and PokéAPI variety/form names, all at the pinned SHAs. It resolves `is_alias_of`, applies a hand-curated override table, and prints uncovered names.
- Output: `shared/pokesprite_icons.json`, shaped as `{ "<pokeapi-name>": { "src": "ps" | "bq", "slug": "...", "female": bool, "shiny": bool } }`, plus the pinned SHAs.
- Register the file in `pubspec.yaml` assets and copy it in `backend/Dockerfile`. Document it in `scripts/README.md`.
- **Acceptance:** every species 1–905 and all Megas/G-Max resolve to PokeSprite, and Gen 9 base species resolve to bamq. The uncovered list holds only known gaps (Z-A Megas and the bamq gaps in §2.3).

### Task 2: Backend and Flutter URL builders
- Backend `_build_icon_url` and the variety/form builders look up the map first and emit the PokeSprite/bamq raw URL. Otherwise they keep the current PokéAPI chain.
- Flutter `buildIconUrl` / `buildVarietySpriteUrls` / `buildFormSpriteUrls` mirror this exactly. `iconUrlCandidates` / `genderedIconUrlCandidates` append the PokéAPI chain after a PokeSprite/bamq URL.
- Flush the backend resolved cache on deploy.
- **Tests:**
  - pytest `TestIconUrls`
  - `test/services/pokemon_resolved/sprite_url_builder_icon_test.dart`, covering a variety (Calyrex-Ice), a **form-entry cosmetic (Shellos-East)** per CLAUDE.md's form-test rule, a Mega, a G-Max, a Gen 9 species and a Z-A Mega (fallback)
- **Acceptance:** a team with Pikachu, Mega Charizard X, G-Max Toxtricity and Sprigatito shows all four at the same pixel scale.

### Task 3: Fallback scale normalisation
- Fix the `kIconFolders` doc comment.
- Choose one approach:
  - (a) Render known-fill sources (Scarlet/Violet, Champions) inside a reduced inner box, and draw Gen VII 40×30 icons at 68/40 of PokeSprite scale.
  - (b) Drop Scarlet/Violet from the icon chain and fall through to the front sprite.
- Decide during implementation from screenshots.
- **Acceptance:** a Legends Z-A Mega in a team row isn't visibly larger than its neighbours.

### Task 4: Shiny and female icons
- Populate `icon_shiny` / `iconShiny` and `icon_female` / `iconFemale` from PokeSprite/bamq `shiny/` and `female/`.
- Update the `icon_shiny` schema comment.
- Team slots honour `isShiny` (and the gender-specific female icon), falling back to the regular icon.
- **Acceptance:** a shiny female Indeedee slot shows the shiny female box icon.

### Task 5: Attribution and docs
- Credit PokeSprite (MIT) and bamq / National Pokédex Version Delta artists in the README and About screen.
- Update `lib/services/README.md`, `lib/shared/README.md` and `backend/README.md` with the new icon source chain.

**Out of scope:** bundling icons as assets; Pokédex `sprite`/`artwork` image modes, which don't use icons.
