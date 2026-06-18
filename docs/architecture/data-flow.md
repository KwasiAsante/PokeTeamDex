# PokeTeamDex — Full Data Flow & Screen Architecture

> Read this if you are confused about how data moves through the app, what each screen fetches, how forms work, and where the new backend resolved endpoint fits in.

---

## Table of Contents

1. [Big Picture — Three Data Sources](#1-big-picture--three-data-sources)
2. [App Startup Sequence](#2-app-startup-sequence)
3. [Caching Stack](#3-caching-stack)
4. [Pokédex List / Grid Screen](#4-pokédex-list--grid-screen)
5. [Pokémon Detail Screen](#5-pokémon-detail-screen)
6. [Teams Screen](#6-teams-screen)
7. [Team Detail Screen](#7-team-detail-screen)
8. [Slot Config Screen](#8-slot-config-screen)
9. [How Forms Work — The Critical Flow](#9-how-forms-work--the-critical-flow)
10. [The Backend Resolved Endpoint — Where It Fits](#10-the-backend-resolved-endpoint--where-it-fits)
11. [Provider Dependency Map](#11-provider-dependency-map)

---

## 1. Big Picture — Three Data Sources

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                                 │
├──────────────────┬──────────────────────┬───────────────────────────┤
│   PokéAPI        │  Pokémon Showdown     │   Our Backend             │
│  (network)       │  (local assets)       │  (network, new)           │
├──────────────────┼──────────────────────┼───────────────────────────┤
│ • Types          │ • Learnsets (per gen) │ • Aggregated resolved     │
│ • Stats          │ • Move metadata       │   data (PokéAPI +         │
│ • Abilities      │ • Items               │   Showdown + Smogon)      │
│ • Moves          │ • Abilities           │ • Event moves PokéAPI     │
│ • Sprites        │ • Pokedex (gen-       │   doesn't have            │
│ • Species info   │   accurate types/     │ • Smogon competitive      │
│ • Evolution      │   stats)              │   sets per format         │
│   chains         │ • Form override maps  │ • 7-day PostgreSQL cache  │
│ • Encounters     │ • Sprite stem maps    │                           │
│                  │ • Mega stone map      │                           │
│                  │ • Format→version maps │                           │
└──────────────────┴──────────────────────┴───────────────────────────┘
         │                   │                        │
         ▼                   ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                                    │
│                                                                     │
│  PokeApiRepository      PokemonDataRegistry      (future: Task E)  │
│  (fetches + caches)     (loaded at startup,                        │
│                          in-memory singleton)                       │
└─────────────────────────────────────────────────────────────────────┘
```

**Key rule:** PokéAPI is the primary data source for everything. The Showdown local assets fill gaps (event moves, gen-accurate types/stats, sprite routing). The backend resolved endpoint is the aggregated version of both — but Flutter currently doesn't call it yet (Task E).

---

## 2. App Startup Sequence

```
main()
  │
  ├─ 1. WidgetsFlutterBinding.ensureInitialized()
  │
  ├─ 2. Hive.initFlutter()
  │      Hive.openBox('pokeapi_cache')          ← disk cache ready
  │
  ├─ 3. PokemonDataRegistry.initialize()        ← BLOCKS until done
  │      loads assets/data/pokemon_registry.json
  │      parses ~23 maps into memory:
  │        cosmeticSpriteStems, megaStoneMap,
  │        gameIdToVersionPath, psFormExceptions,
  │        battleMeaningfulNames, cosmeticVarietyNames, ...
  │      Result: PokemonDataRegistry.instance is ready
  │
  ├─ 4. loadStoredToken()                       ← auth token from SharedPrefs
  │
  └─ 5. runApp(ProviderScope(MyApp(...)))
         │
         └─ First frame renders
              All registry data already in memory.
              PokéAPI calls begin lazily as screens request them.
```

**What this means:** Every form name override, every sprite path map, every mega stone → form mapping is available from frame 1, before any network request happens.

---

## 3. Caching Stack

Data flows through three layers before hitting the network:

```
Riverpod Provider (in-memory, session)
        │  cache miss (provider disposed or first load)
        ▼
PokeApiRepository in-memory maps (session)
  _pokemonById: Map<int, PokemonEntry>
  _pokemonByName: Map<String, PokemonEntry>
  _speciesById: Map<int, PokemonSpeciesEntry>
  _formByName: Map<String, PokemonFormEntry>
        │  not in maps
        ▼
Hive persistent cache (disk, survives restarts)
  box: 'pokeapi_cache'
  TTLs:
    Pokemon detail .......... 7 days
    Pokemon species ......... 7 days
    Abilities / Moves / Items 7 days
    Evolution chains ........ 7 days
    Contest effects ......... 30 days
    Pokemon list ............ 24 hours  (more volatile)
        │  expired or missing
        ▼
PokéAPI network request
  GET pokeapi.co/api/v2/pokemon/{id}        ~100–500ms
  GET pokeapi.co/api/v2/pokemon-species/{id}
  GET pokeapi.co/api/v2/pokemon-form/{name}
```

**Latency profile:**
| Layer            | Hit latency | Notes                              |
|------------------|-------------|------------------------------------|
| Riverpod keepAlive | ~0ms       | `resolvedPokemonProvider` uses this |
| In-memory map    | ~0.001ms    | Skips JSON re-parsing              |
| Hive (disk)      | ~5–10ms     | Parses stored JSON                 |
| PokéAPI network  | 100–500ms   | Cold miss                          |

**Why `resolvedPokemonProvider` is `keepAlive`:** The Pokédex list has ~50 tiles, each needing 2 providers. Without keepAlive, scrolling down and back would tear down and rebuild 100 providers, each triggering Hive reads and JSON parsing. keepAlive keeps them alive for the session.

---

## 4. Pokédex List / Grid Screen

### What the user sees
- Scrollable list or grid of all 1025 Pokémon
- Filter bar: generation, type, game (regional dex), search, favorites
- Each tile: sprite, name, dex number, types, form chips

### Provider chain

```
pokedexFilterProvider (StateProvider)
    generation: int?
    type: String?
    game: String?
    sort: dexNumber | name
         │
         ▼
filteredPokemonListProvider
    ├─ pokemonListProvider
    │    GET /pokemon?limit=10000  (24h TTL)
    │    returns List<PokemonListEntry> {id, name}
    │
    ├─ _typeFilterIdsProvider    (when type selected)
    │    GET /type/{typeName}
    │
    ├─ _gamePokedexProvider      (when game selected)
    │    GET /pokedex/{dexName}
    │    (merged for games with multiple sub-dex)
    │
    ├─ pokemonSearchProvider
    ├─ showFavoritesOnlyProvider
    └─ favoritesSetProvider
    
    Applies filters in order:
    1. generation range
    2. game regional dex
    3. type intersection
    4. favorites
    5. search
    6. sort
    
    Emits: List<PokemonListEntry> (paginated, 50 per page)
```

### Per tile providers

```
For each tile (PokemonListTile or PokemonGridCard):

resolvedPokemonProvider(pokemonId)   ← KEEPALIVE
    │
    ├─ pokemonDetailProvider(id)
    │    GET /pokemon/{id}
    │    → PokemonEntry { id, name, types, stats,
    │                     abilities, moves, sprites,
    │                     formNames, height, weight }
    │
    ├─ pokemonSpeciesProvider(id)
    │    GET /pokemon-species/{id}
    │    → PokemonSpeciesEntry { varieties, evolutionChainId,
    │                            generationName, eggGroups,
    │                            captureRate, isBaby/Legendary/Mythical }
    │
    └─ cosmeticFormsProvider(pokemonName)
         Fires only if formNames.length > 1 AND not in noCosmeticFormsPokemon
         GET /pokemon-form/{formName}  for each non-default form
         → List<PokemonFormEntry> { spriteUrl, spriteShinyUrl }
         (female patches applied here for frillish, jellicent, etc.)

Image URL built by:
  PokemonDataResolver.resolvePokedexImageUrl(
    sprites, pokemonId, pokemonName, format, imageType
  )
```

### Form chip in the list tile

```
User taps a form chip (e.g. "Alolan" on Raichu):

If cosmetic form (e.g. Burmy-Sandy):
  → uses cosmeticForms from resolvedPokemonProvider
  → no new fetch
  → sprite updates, types stay the same

If battle-meaningful variety (e.g. Alolan Raichu):
  → pokemonByNameProvider("alolan-raichu")  autoDispose
       GET /pokemon/alolan-raichu
  → sprite updates, types update (Electric/Psychic)

Navigation on tap:
  cosmetic / base:  push('/pokedex/{id}')
  battle variety:   push('/pokedex/{id}?form=alolan-raichu')
```

---

## 5. Pokémon Detail Screen

**Entry:** `push('/pokedex/{pokemonId}?form={formName}')`  
**pokemonId is always the BASE species ID (1–1025).**

### What the user sees
- Header with sprite, name, types, form switcher chips
- 8 tabs: Overview, Stats, Abilities, Moves, Evolutions, Forms, Locations, Teams

### Provider chain

```
PokemonDetailScreen(pokemonId: 3, initialFormName: 'giratina-origin')
    │
    ├─ resolvedPokemonProvider(3)   ← KEEPALIVE (same as list tile)
    │    detail + species + cosmeticForms
    │
    ├─ Local state:
    │    _selectedFormName: String?    (battle variety, from form chips)
    │    _selectedCosmeticFormName: String?  (cosmetic, from header chips)
    │    _shiny: bool
    │
    └─ pokemonByNameProvider(_selectedFormName)   autoDispose
         Fires ONLY when user selects a battle variety
         GET /pokemon/{formName}
         Returns full PokemonEntry for that form
         (different stats/types/abilities)
```

### Tab-specific providers

```
Stats tab:
  Uses resolvedPokemonProvider.detail.stats
  OR pokemonByNameProvider(selectedForm).stats when form active

Abilities tab:
  abilityProvider(name)   per ability
  GET /ability/{name}

Moves tab:
  moveProvider(name)   per move
  GET /move/{name}
  formatServiceProvider  (PS learnset data)
  priorEvoMoveSetsProvider(id)
    walks evolution chain to find pre-evo exclusive moves

Evolutions tab:
  evolutionChainProvider(chainId)
  GET /evolution-chain/{chainId}
  pokemonByNameProvider(formName)  for regional form nodes

Forms tab:
  pokemonByNameProvider(variety.name)  per variety
  shows Mega/G-Max/regional forms with their stats

Locations tab:
  pokemonEncountersProvider(id)
  GET /pokemon/{id}/encounters

Teams tab:
  teamSlotsProvider  (where this Pokémon is used)
```

### Form switching in detail screen

```
initialFormName = "giratina-origin"
    │
    ▼
_selectedFormName = "giratina-origin"  (set from route param)
    │
    ▼
pokemonByNameProvider("giratina-origin")
    GET /pokemon/giratina-origin
    returns: { id: 10007, types: [Ghost, Dragon], stats: {...} }
    │
    ▼
Stats tab shows Giratina-Origin stats (Ghost/Dragon, 680 BST)
Header shows Ghost/Dragon type badges
Sprite shows Origin Forme art

User taps "Altered" chip:
    │
    ▼
_selectedFormName = null  (back to base)
    │
    ▼
Uses resolvedPokemonProvider(483).detail  (Giratina base)
Stats tab shows Altered stats (Ghost/Dragon, 680 BST different spread)
```

---

## 6. Teams Screen

### What the user sees
- Reorderable list of folders with nested teams
- Each team row: name, format, 6 mini sprites
- Add team / add folder / import from Showdown / sync status

### Provider chain

```
TeamsScreen
    │
    ├─ foldersProvider
    │    teamFolderRepositoryProvider.watchAll()
    │    Stream<List<TeamFolder>>  (live DB updates)
    │
    ├─ allTeamsProvider
    │    teamRepositoryProvider.watchAll()
    │    Stream<List<Team>>
    │
    ├─ syncStateProvider     (syncing / idle / error)
    ├─ pendingSyncCountProvider
    ├─ isOnlineProvider
    └─ authTokenProvider

Mini sprite row (per team):
    teamSlotsProvider(teamId)
        Stream<List<TeamSlot>>
        │
        └─ Per filled slot:
             pokemonByNameProvider(transformFormName)
               where transformFormName = mega/gmax/form name if active
               → PokemonEntry for correct sprite ID
```

---

## 7. Team Detail Screen

**Entry:** `push('/teams/{teamId}')`

### What the user sees
- **Narrow:** slot list (6 cards stacked), tap to open config fullscreen
- **Wide (≥840px):** slot list on left, embedded config panel on right

### Provider chain

```
TeamDetailScreen(teamId)
    │
    ├─ teamByIdProvider(teamId)          ← current team metadata
    ├─ teamSlotsProvider(teamId)         ← all slots, live stream
    ├─ allFormatsProvider                ← ensures PS data loaded
    ├─ formatServiceProvider
    └─ maxBoxSizeProvider

Per filled slot card (_FilledSlotCard):
    │
    ├─ pokemonDetailProvider(slot.pokemonId)
    │    Base species data (always fetched)
    │
    ├─ pokemonByNameProvider(slot.formName)
    │    ONLY when slot.formName != null AND form is battle variety
    │    Gets form-specific types, stats, abilities
    │
    ├─ pokemonByNameProvider(megaFormName)
    │    ONLY when slot.isMegaEvolved == true
    │
    ├─ pokemonByNameProvider(gmaxFormName)
    │    ONLY when slot.hasGigantamax && slot.gigantamaxEnabled
    │
    ├─ cosmeticFormsProvider(pokemon.name)
    │    For cosmetic forms (burmy-sandy stays here, no separate fetch)
    │
    └─ slotValidationProvider(slot, format)
         Validates moves/abilities/items for format gen
```

---

## 8. Slot Config Screen

**Entry:** `push('/teams/{teamId}/config/{slotNumber}')` or embedded in wide layout

### What the user sees
- Sprite (shiny toggle, form-aware)
- Basics: level, gender, friendship
- Ability, nature, held item
- Mega/Gigantamax/Alpha/Tera toggles (gen-gated)
- Form chips (variety + cosmetic)
- 4 move slots with learnset picker
- EV/IV bars + stat preview
- Contest conditions (Gen 3/4)
- Ribbons + instance chain linking

### Provider chain

```
SlotConfigScreen(teamId, slotNumber)
    │
    ├─ teamSlotsProvider(teamId)         ← find this slot
    ├─ teamByIdProvider(teamId)          ← format for gen gating
    │
    ├─ resolvedPokemonProvider(slot.pokemonId)   ← MAIN GATEWAY
    │    detail + species + cosmeticForms
    │    Provides: base stats, all learnable moves, cosmetic form list
    │
    ├─ priorEvoMoveSetsProvider(slot.pokemonId)
    │    Walks evolution chain to surface pre-evo exclusive moves
    │
    ├─ pokemonByNameProvider(formName)    LAZY — only when form active
    ├─ pokemonByNameProvider(megaForm)    LAZY — only when mega toggled ON
    ├─ pokemonByNameProvider(gmaxForm)    LAZY — only when gmax toggled ON
    │
    ├─ formatServiceProvider              PS learnset + event moves
    ├─ allFormatsProvider                 ensures PS data loaded
    ├─ useFormatSpritesProvider           sprite versioning pref
    │
    ├─ _abilityDetailProvider(name)       per ability (effect text)
    ├─ _moveDetailProvider(name)          per move (type, power, PP)
    └─ _itemDetailProvider(name)          per item
```

### What triggers a new PokéAPI fetch in SlotConfig

```
Action                    │ Fetch triggered?          │ What changes
──────────────────────────┼───────────────────────────┼────────────────────────────
Open screen               │ resolvedPokemonProvider   │ Base stats, moves, abilities
Tap form chip (variety)   │ pokemonByNameProvider     │ Types, stats, abilities, moves
Tap form chip (cosmetic)  │ NONE                      │ Sprite only
Hold mega stone item      │ NONE (yet)                │ Shows mega toggle
Toggle mega ON            │ pokemonByNameProvider     │ Types, stats, abilities
Toggle mega OFF           │ NONE (watch removed)      │ Reverts to base/form
Toggle gmax ON            │ pokemonByNameProvider     │ G-Max move unlocked
Toggle gmax OFF           │ NONE (watch removed)      │ G-Max move hidden
Change level/nature/EVs   │ NONE                      │ Stat preview recalculates
Change tera type          │ NONE                      │ Visual only (Gen 9)
Change ability            │ NONE                      │ Validation re-runs
Change move               │ NONE (already loaded)     │ Learnset already in memory
```

---

## 9. How Forms Work — The Critical Flow

This is the most complex part. There are **three distinct form types** and they behave differently everywhere.

### Form type classification

```
┌────────────────────────────────────────────────────────────────┐
│                    FORM TYPES                                  │
├──────────────────┬─────────────────┬───────────────────────────┤
│ Battle Variety   │ Cosmetic Variety │ Form-Entry Cosmetic       │
├──────────────────┼─────────────────┼───────────────────────────┤
│ Different stats  │ Same stats      │ Same stats                │
│ Different types  │ Same types      │ Different sprite only     │
│ Different moves  │ Same moves      │                           │
│                  │                 │                           │
│ Has own          │ Has own         │ Has /pokemon-form         │
│ /pokemon/{id}    │ /pokemon/{id}   │ endpoint only             │
│ resource         │ resource        │ NO /pokemon resource      │
│                  │                 │                           │
│ Examples:        │ Examples:       │ Examples:                 │
│ Giratina-Origin  │ Wormadam-Sandy  │ Shellos-East              │
│ Alolan Raichu    │ Vivillon-Polar  │ Unown-A through Z         │
│ Mega Venusaur    │ Mimikyu-Busted  │ Burmy-Sandy               │
│ Kyurem-Black     │ Rotom-Wash*     │ Flabébé-Blue              │
│ Deoxys-Speed     │                 │                           │
│                  │ * Rotom forms   │                           │
│                  │ are variety     │                           │
│                  │ (different      │                           │
│                  │ types in gen4)  │                           │
└──────────────────┴─────────────────┴───────────────────────────┘

Source:
  Battle variety:   pokemon_registry.json → battleMeaningfulNames
  Cosmetic variety: pokemon_registry.json → cosmeticVarietyNames
  Form-entry:       cosmeticFormsProvider (from /pokemon-form endpoint)
```

### How each form type is fetched

```
Battle Variety (e.g. "alolan-raichu"):
  Source:  species.varieties list from /pokemon-species/{id}
  Fetch:   pokemonByNameProvider("alolan-raichu")
             GET /pokemon/alolan-raichu
             Returns full PokemonEntry with own id, types, stats, abilities, moves
  Used for: stats, abilities, move list, sprite
  Navigation: push('/pokedex/{base_id}?form=alolan-raichu')

Cosmetic Variety (e.g. "wormadam-sandy"):
  Source:  species.varieties list (has /pokemon resource)
  Fetch:   pokemonByNameProvider("wormadam-sandy")  — same as battle variety
  BUT classified cosmetic because battleMeaningfulNames excludes it
  Used for: sprite only (stats same as base)
  Navigation: push('/pokedex/{base_id}')  ← NO form param

Form-Entry Cosmetic (e.g. "shellos-east-sea"):
  Source:  detail.formNames list from /pokemon/{id}
  Fetch:   cosmeticFormsProvider → GET /pokemon-form/shellos-east-sea
             Returns PokemonFormEntry { spriteUrl, spriteShinyUrl }
             NO stats, types, abilities — just sprites
  Used for: sprite only
  Navigation: push('/pokedex/{base_id}')  ← NO form param
```

### The Mega Evolution special case

Mega forms are a **battle variety** but gated by item:

```
Venusaur (ID 3) has variety "venusaur-mega" (ID 10033)
BUT this variety is only accessible when holding Venusaurite.

PokéAPI sees:   Venusaur varieties = [venusaur, venusaur-mega]
Our app:        Shows mega only when item is held (SlotConfig)
                OR as a selectable variety (Forms tab of detail screen)

In SlotConfig:
  1. User picks Venusaurite as held item
  2. megaStoneMap["venusaurite"] → {base: "venusaur", mega: "venusaur-mega"}
  3. Mega toggle appears
  4. User toggles mega ON
  5. pokemonByNameProvider("venusaur-mega")  fires
  6. Stats update to Mega Venusaur's 780 BST, Thick Fat ability

In the Forms tab of detail screen:
  varieties include venusaur-mega regardless of item
  pokemonByNameProvider("venusaur-mega") fires on display
```

### Why the `forms` field in the resolved endpoint was wrong

Current (wrong) resolved response for `/pokemon/3/resolved`:
```json
{
  "pokemon_id": 3,
  "name": "venusaur",
  "forms": ["venusaur"]   ← just its own name, useless
}
```

What it should be:
```json
{
  "pokemon_id": 3,
  "name": "venusaur",
  "forms": [
    {
      "name": "venusaur-mega",
      "pokemon_id": 10033,
      "types": ["Grass", "Poison"],
      "base_stats": { "hp": 80, "atk": 100, ... },
      "abilities": { "0": "Thick Fat" },
      "sprite_urls": { ... }
    }
  ]
}
```

**Why this matters for the frontend workflow:**

```
Current (broken) workflow to show Mega Venusaur:
  1. User has Venusaur (ID 3)
  2. App calls /pokemon/3/resolved  → gets Venusaur data + forms: ["venusaur"]
  3. App still needs to call PokéAPI /pokemon-species/3 to get varieties list
  4. App extracts variety URL, learns Mega = ID 10033
  5. App calls /pokemon/10033/resolved (or PokéAPI directly)
  → The resolved endpoint adds no value for form access

Correct workflow with embedded forms:
  1. User has Venusaur (ID 3)
  2. App calls /pokemon/3/resolved  → gets Venusaur + Mega data embedded
  3. User taps Mega → app reads from forms[] already in memory
  → Zero extra requests
```

This redesign is an open question being discussed (see PR #243 comments).

---

## 10. The Backend Resolved Endpoint — Where It Fits

**Current state:** Flutter does NOT call the backend resolved endpoint yet. That is Task E (future work).

### What the endpoint does today (Task D — PR #243)

```
GET /pokemon/{id}/resolved?gen=N

Aggregates from:
  1. PokéAPI /pokemon/{id}          → types, stats, abilities, sprite URLs
  2. PokéAPI /pokemon-species/{id}  → English name (for Smogon lookup)
  3. Showdown pokedex.json          → gen-accurate types/stats
  4. Showdown pokedex-gen-overrides → apply gen N historical values
  5. Showdown event_learnsets.json  → event-only moves PokéAPI doesn't have
  6. Smogon pkmn.github.io          → competitive sets per format (background load)

Caches result in PostgreSQL (pokemon_resolved table, 7-day TTL)
Cache key: (pokemon_id, gen)

Returns: {
  pokemon_id, gen, name,
  types,        ← gen-accurate (Clefairy is Normal in gen ≤ 5)
  base_stats,   ← gen-accurate (Charizard SpA was 85 in gen 1)
  abilities,
  event_moves,  ← moves only in Showdown event data (e.g. Dratini ExtremeSpeed)
  smogon_analyses,  ← competitive sets (null until 15s background load)
  forms,        ← currently broken, needs redesign
  sprite_urls,  ← official artwork + HOME + Showdown battle sprite
  resolved_at
}
```

### Where it will fit after Task E

```
TODAY (Task D — backend only):
  Flutter → PokéAPI directly (unchanged)
  Backend endpoint exists but Flutter doesn't call it yet

AFTER TASK E (Flutter hybrid integration):

  Flutter request flow:
    resolvedPokemonProvider(id)
      │
      ├─ Check Hive 'pokemon_resolved_{id}_{gen}' (new box, 7d TTL)
      │    Hit → return immediately
      │
      ├─ Miss → GET backend /pokemon/{id}/resolved?gen={gen}
      │    Hit (DB cached) → return, write to Hive
      │    Miss (DB cold) → backend aggregates → return → write to Hive
      │
      └─ If backend unreachable (offline):
           Fall back to current behavior:
           pokemonDetailProvider + pokemonSpeciesProvider + cosmeticFormsProvider
```

### Gen-aware resolution example

```
Request: GET /pokemon/35/resolved?gen=5   (Clefairy in Gen 5)

Backend resolution:
  1. Fetch PokéAPI /pokemon/35  → types: ["Normal", "Fairy"] (modern)
  2. Load Showdown pokedex.json → base entry: types: ["Normal", "Fairy"]
  3. Scan gen overrides upward from gen=5:
       gen5/clefairy → { types: ["Normal"] }  ← FOUND, apply
  4. Result: types: ["Normal"]  ← correct Gen 5 value

Request: GET /pokemon/35/resolved?gen=6   (Clefairy in Gen 6)

  3. Scan gen overrides upward from gen=6:
       gen6 → no Clefairy entry
       gen7 → no Clefairy entry
       gen8 → no Clefairy entry
       gen9 → no Clefairy entry
       No override found → use base types: ["Normal", "Fairy"]
  4. Result: types: ["Normal", "Fairy"]  ← correct Gen 6+ value
```

---

## 11. Provider Dependency Map

Complete map of which provider depends on which, across all screens.

```
PokéAPI
  └─ PokeApiRepository (singleton, fetches + memoizes)
       │
       ├─ pokemonDetailProvider(id)              autoDispose.family
       │    [types, stats, abilities, moves, formNames, sprites]
       │
       ├─ pokemonByNameProvider(name)            autoDispose.family
       │    Same as detail but keyed by name
       │    Used for: form variants, Mega/Gmax
       │
       ├─ pokemonSpeciesProvider(id)             autoDispose.family
       │    [varieties, evolutionChainId, generationName, eggGroups]
       │
       ├─ cosmeticFormsProvider(pokemonName)     autoDispose.family
       │    [List<PokemonFormEntry>] — from /pokemon-form endpoint
       │    Only fires if formNames.length > 1
       │
       ├─ abilityProvider(name)                 autoDispose.family
       ├─ moveProvider(name)                    autoDispose.family
       ├─ evolutionChainProvider(chainId)       autoDispose.family
       ├─ pokemonEncountersProvider(id)         autoDispose.family
       └─ priorEvoMoveSetsProvider(id)          autoDispose.family

resolvedPokemonProvider(id)                    KEEPALIVE.family
  = pokemonDetailProvider(id)
  + pokemonSpeciesProvider(id)
  + cosmeticFormsProvider(detail.name)
  + female patch logic
  → ResolvedPokemon { detail, species, cosmeticForms }

  Used by:
    PokemonListTile, PokemonGridCard      (Pokédex list)
    PokemonDetailScreen                   (detail view)
    SlotConfigScreen                      (team builder)

pokemonListProvider                        autoDispose
  GET /pokemon?limit=10000
  → List<PokemonListEntry>

filteredPokemonListProvider                autoDispose
  = pokemonListProvider
  + pokedexFilterProvider
  + pokemonSearchProvider
  + showFavoritesOnlyProvider
  + _typeFilterIdsProvider   (if type filter)
  + _gamePokedexProvider     (if game filter)

teamSlotsProvider(teamId)                  autoDispose.family
  Stream<List<TeamSlot>> from DB

formatServiceProvider                      keepAlive
  Loads PS learnsets/moves/items from Hive
  Required for: move validation, event moves, sprite versioning

allFormatsProvider                         keepAlive
  Depends on formatServiceProvider
  Emits true when PS data is fully loaded
  Gates: slot validation, move picker
```

---

## Quick Reference: "I want to know X about a Pokémon"

| What you want                          | Provider / Source                        |
|----------------------------------------|------------------------------------------|
| Name, types, stats (current gen)       | `pokemonDetailProvider(id)`              |
| Species info, varieties list           | `pokemonSpeciesProvider(id)`             |
| Cosmetic form sprites                  | `cosmeticFormsProvider(name)`            |
| All of the above merged                | `resolvedPokemonProvider(id)`            |
| A specific form's stats/types          | `pokemonByNameProvider("form-name")`     |
| Mega form data                         | `pokemonByNameProvider("base-mega")`     |
| Ability effect text                    | `abilityProvider("ability-name")`        |
| Move details (power, type, PP)         | `moveProvider("move-name")`              |
| What moves it can learn (gen-filtered) | `formatServiceProvider` + learnsets      |
| Event moves PokéAPI doesn't have       | `formatServiceProvider.eventMovesForGen` |
| Gen-accurate types (e.g. gen 5)        | `GET /pokemon/{id}/resolved?gen=5`       |
| Smogon competitive sets                | `GET /pokemon/{id}/resolved` (smogon_analyses) |
| Where it appears in the wild           | `pokemonEncountersProvider(id)`          |
| Pre-evolution exclusive moves          | `priorEvoMoveSetsProvider(id)`           |
| Sprite path for gen 2 Crystal          | `PokemonDataResolver.resolveFormSprite`  |
| Mega stone → which form it unlocks     | `PokemonDataRegistry.megaStoneMap`       |
| Form name override (PS → PokéAPI)      | `PokemonDataRegistry.psFormExceptions`   |
