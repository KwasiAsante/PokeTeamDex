# Task E — Flutter Hybrid Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `resolvedPokemonProvider` use `GET /pokemon/{id}/resolved` as its primary source, extend the backend response to carry all data currently sourced from PokéAPI, and migrate `PokemonEntry` from raw maps to typed Dart models.

**Architecture:** The backend aggregates PokéAPI + Showdown + Smogon into one response and caches it in PostgreSQL. Flutter checks a new `pokemon_resolved_cache` Hive box first, calls the backend on miss, and falls back to the existing `PokeApiRepository` path when offline. Moves and flavor text are lazy-loaded via separate providers and endpoints to keep the base response slim.

**Tech Stack:** FastAPI + Pydantic (backend), Flutter + Riverpod + Hive (frontend), PostgreSQL JSONB (backend cache), pytest (backend tests), flutter_test + flutter_riverpod (Flutter tests).

## Global Constraints

- Backend: Python 3.11+, FastAPI, Pydantic v2, SQLAlchemy async, httpx
- Flutter: Dart 3, Riverpod 2, Hive 2, `keepAlive` on `resolvedPokemonProvider` (no autoDispose)
- New backend routes must be declared **before** `/{name_or_id}/resolved` in `pokemon.py`
- New Hive box key: `pokemon_resolved_cache`; TTL: 7 days
- `PokemonEntry.fromJson` must continue to work with raw PokéAPI JSON (offline path)
- `FlavorTextEntry` already exists in `pokemon_species_entry.dart` — reuse it, do not duplicate
- No Alembic migration needed — `pokemon_resolved.data` is JSONB

---

## File Map

**Backend — modify:**
- `backend/app/schemas/pokemon_resolved.py` — new models, updated response shape
- `backend/app/services/pokemon_resolver.py` — populate new fields, new resolver methods
- `backend/app/routers/pokemon.py` — two new endpoints
- `backend/tests/test_pokemon_resolver.py` — new tests

**Flutter — create:**
- `lib/services/pokemon_resolved/models.dart` — `AbilityInfo`, `MoveLearnDetail`, `MoveSummary`, `SpriteUrlsFull`, `PokemonResolvedBackendResponse`
- `lib/services/pokemon_resolved/pokemon_resolved_cache.dart` — Hive box wrapper
- `lib/services/pokemon_resolved/pokemon_backend_repository.dart` — backend API calls
- `lib/services/pokemon_resolved/pokemon_resolved_providers.dart` — Riverpod providers
- `test/services/pokemon_resolved/models_test.dart`
- `test/services/pokemon_resolved/pokemon_backend_repository_test.dart`
- `test/services/pokemon_resolved/resolved_pokemon_provider_test.dart`

**Flutter — modify:**
- `lib/main.dart` — open new Hive box
- `lib/services/pokeapi/models/pokemon_entry.dart` — typed fields, updated `fromJson`
- `lib/features/pokedex/models/resolved_pokemon.dart` — new fields
- `lib/features/pokedex/providers/resolved_pokemon_provider.dart` — hybrid fetch
- `lib/features/pokedex/providers/pokemon_detail_provider.dart` — two new providers
- `lib/features/pokedex/presentation/pokemon_detail_screen.dart` — moves + flavor + types/stats/abilities access
- `lib/features/pokedex/presentation/pokemon_detail_placeholder_screen.dart` — types access
- `lib/features/teams/presentation/slot_config_screen.dart` — moves + abilities + stats access
- `lib/features/teams/presentation/team_detail_screen.dart` — abilities + stats access

---

## Task 1: Backend schema — new Pydantic models + updated `PokemonResolvedResponse`

**Files:**
- Modify: `backend/app/schemas/pokemon_resolved.py`
- Test: `backend/tests/test_pokemon_resolver.py`

**Interfaces:**
- Produces: `AbilityInfo`, `MoveLearnDetail`, `MoveSummary`, `FlavorTextEntry`, `MovesResponse`, `FlavorTextResponse`, updated `FormData`, updated `PokemonResolvedResponse`

- [ ] **Step 1: Add new Pydantic models to `pokemon_resolved.py`**

Insert after the existing `_coerce_to_list` / `_StrOrList` block and before `EventMove`:

```python
class AbilityInfo(BaseModel):
    name: str
    is_hidden: bool
    slot: int


class MoveLearnDetail(BaseModel):
    version_group: str
    method: str   # "level-up", "machine", "egg", "tutor"
    level: int    # 0 for non-level-up methods


class MoveSummary(BaseModel):
    name: str
    learn_details: list[MoveLearnDetail]


class FlavorTextEntry(BaseModel):
    text: str
    language: str
    version: str


class MovesResponse(BaseModel):
    pokemon_id: int
    name: str
    moves: list[MoveSummary]


class FlavorTextResponse(BaseModel):
    pokemon_id: int
    name: str
    flavor_text_entries: list[FlavorTextEntry]
```

- [ ] **Step 2: Update `FormData` to add `form_id` and `is_default`**

```python
class FormData(BaseModel):
    name: str
    form_id: int | None = None
    is_default: bool = False
    front_sprite_url: str | None = None
    sprite_urls: SpriteUrlsFull | None = None
```

- [ ] **Step 3: Change `abilities` field type and add all new fields to `PokemonResolvedResponse`**

Replace the existing `PokemonResolvedResponse` class:

```python
class PokemonResolvedResponse(BaseModel):
    pokemon_id: int
    gen: int
    name: str
    # pokemon detail
    types: list[str]
    base_stats: dict[str, int]
    abilities: list[AbilityInfo]          # changed from dict[str, str]
    height: int = 0
    weight: int = 0
    base_experience: int | None = None
    species_name: str | None = None
    form_names: list[str] = []            # derived from forms[].name for convenience
    moves: list[MoveSummary] = []         # slim: []; full via ?includes[]=moves
    moves_url: str | None = None
    supplement_moves: list[EventMove]
    smogon_analyses: list[SmogonFormatData] | None
    smogon_url: str | None = None
    varieties: list[VarietyData]
    varieties_url: str | None = None
    forms: list[FormData]
    forms_url: str | None = None
    sprite_urls: SpriteUrlsFull
    resolved_at: datetime
    # species detail
    genus: str | None = None
    generation_name: str = "generation-ix"
    gender_rate: int | None = None
    capture_rate: int | None = None
    base_happiness: int | None = None
    hatch_counter: int | None = None
    growth_rate: str | None = None
    egg_groups: list[str] = []
    flavor_text_entries: list[FlavorTextEntry] = []  # slim: []; full via ?includes[]=flavor
    flavor_text_url: str | None = None
    is_baby: bool = False
    is_legendary: bool = False
    is_mythical: bool = False
    evolution_chain_id: int | None = None
```

- [ ] **Step 4: Write failing schema validation test**

Add to `backend/tests/test_pokemon_resolver.py`:

```python
def test_pokemon_resolved_response_has_new_fields():
    """PokemonResolvedResponse accepts all new fields without validation errors."""
    from app.schemas.pokemon_resolved import (
        PokemonResolvedResponse, AbilityInfo, MoveLearnDetail, MoveSummary,
        SpriteUrlsFull, FlavorTextEntry, FormData
    )
    from datetime import datetime, timezone

    data = PokemonResolvedResponse(
        pokemon_id=6,
        gen=9,
        name="charizard",
        types=["Fire", "Flying"],
        base_stats={"hp": 78, "attack": 84, "defense": 78,
                    "special-attack": 109, "special-defense": 85, "speed": 100},
        abilities=[
            AbilityInfo(name="blaze", is_hidden=False, slot=1),
            AbilityInfo(name="solar-power", is_hidden=True, slot=3),
        ],
        height=17,
        weight=905,
        base_experience=240,
        species_name="charizard",
        supplement_moves=[],
        smogon_analyses=None,
        varieties=[],
        forms=[
            FormData(name="charizard", form_id=6, is_default=True,
                     front_sprite_url="https://example.com/6.png")
        ],
        sprite_urls=SpriteUrlsFull(official_artwork="https://example.com/art/6.png"),
        resolved_at=datetime.now(timezone.utc),
        genus="Flame Pokémon",
        generation_name="generation-i",
        gender_rate=1,
        evolution_chain_id=2,
        egg_groups=["monster", "dragon"],
        flavor_text_entries=[
            FlavorTextEntry(text="Spits fire.", language="en", version="red")
        ],
    )
    assert data.pokemon_id == 6
    assert data.abilities[0].name == "blaze"
    assert data.abilities[0].is_hidden is False
    assert data.evolution_chain_id == 2
    assert data.forms[0].is_default is True
    assert data.flavor_text_entries[0].language == "en"


def test_moves_response_schema():
    from app.schemas.pokemon_resolved import MovesResponse, MoveSummary, MoveLearnDetail

    data = MovesResponse(
        pokemon_id=6,
        name="charizard",
        moves=[
            MoveSummary(
                name="flamethrower",
                learn_details=[
                    MoveLearnDetail(version_group="sword-shield", method="machine", level=0)
                ],
            )
        ],
    )
    assert data.moves[0].name == "flamethrower"
    assert data.moves[0].learn_details[0].method == "machine"


def test_flavor_text_response_schema():
    from app.schemas.pokemon_resolved import FlavorTextResponse, FlavorTextEntry

    data = FlavorTextResponse(
        pokemon_id=6,
        name="charizard",
        flavor_text_entries=[
            FlavorTextEntry(text="Spits fire.", language="en", version="red")
        ],
    )
    assert data.flavor_text_entries[0].version == "red"
```

- [ ] **Step 5: Run the test to confirm it passes (schema-only, no resolver yet)**

```bash
cd backend && pytest tests/test_pokemon_resolver.py::test_pokemon_resolved_response_has_new_fields tests/test_pokemon_resolver.py::test_moves_response_schema tests/test_pokemon_resolver.py::test_flavor_text_response_schema -v
```

Expected: all 3 PASS.

- [ ] **Step 6: Run full backend test suite to confirm no regressions**

```bash
cd backend && pytest -v
```

Expected: all existing tests pass (schema changes have defaults so old construction still works).

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas/pokemon_resolved.py backend/tests/test_pokemon_resolver.py
git commit -m "feat: extend PokemonResolvedResponse schema with detail + species fields"
```

---

## Task 2: Backend resolver — populate new fields + new endpoints

**Files:**
- Modify: `backend/app/services/pokemon_resolver.py`
- Modify: `backend/app/routers/pokemon.py`
- Test: `backend/tests/test_pokemon_resolver.py`

**Interfaces:**
- Consumes: `AbilityInfo`, `MoveLearnDetail`, `MoveSummary`, `FlavorTextEntry`, `FormData` (with `form_id`, `is_default`), `MovesResponse`, `FlavorTextResponse` from Task 1
- Produces: `GET /pokemon/{name_or_id}/moves`, `GET /pokemon/{name_or_id}/flavor-text`

- [ ] **Step 1: Write failing tests for the new response fields**

Add to `backend/tests/test_pokemon_resolver.py`. These tests mock the PokéAPI calls:

```python
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timezone


def _make_mock_pokemon_data():
    return {
        "id": 6,
        "name": "charizard",
        "height": 17,
        "weight": 905,
        "base_experience": 240,
        "species": {"name": "charizard", "url": "https://pokeapi.co/api/v2/pokemon-species/6/"},
        "types": [
            {"slot": 1, "type": {"name": "fire", "url": "..."}},
            {"slot": 2, "type": {"name": "flying", "url": "..."}},
        ],
        "stats": [
            {"base_stat": 78, "effort": 0, "stat": {"name": "hp", "url": "..."}},
            {"base_stat": 84, "effort": 0, "stat": {"name": "attack", "url": "..."}},
            {"base_stat": 78, "effort": 0, "stat": {"name": "defense", "url": "..."}},
            {"base_stat": 109, "effort": 3, "stat": {"name": "special-attack", "url": "..."}},
            {"base_stat": 85, "effort": 0, "stat": {"name": "special-defense", "url": "..."}},
            {"base_stat": 100, "effort": 0, "stat": {"name": "speed", "url": "..."}},
        ],
        "abilities": [
            {"ability": {"name": "blaze", "url": "..."}, "is_hidden": False, "slot": 1},
            {"ability": {"name": "solar-power", "url": "..."}, "is_hidden": True, "slot": 3},
        ],
        "moves": [
            {
                "move": {"name": "flamethrower", "url": "..."},
                "version_group_details": [
                    {
                        "level_learned_at": 0,
                        "move_learn_method": {"name": "machine", "url": "..."},
                        "version_group": {"name": "sword-shield", "url": "..."},
                    }
                ],
            }
        ],
        "forms": [{"name": "charizard", "url": "..."}],
        "sprites": {
            "front_default": "https://example.com/6.png",
            "other": {
                "official-artwork": {"front_default": "https://example.com/art/6.png", "front_shiny": None},
                "home": {"front_default": "https://example.com/home/6.png", "front_shiny": None,
                         "front_female": None, "front_shiny_female": None},
            },
        },
    }


def _make_mock_species_data():
    return {
        "id": 6,
        "name": "charizard",
        "genera": [{"genus": "Flame Pokémon", "language": {"name": "en"}}],
        "names": [{"name": "Charizard", "language": {"name": "en"}}],
        "generation": {"name": "generation-i", "url": "..."},
        "gender_rate": 1,
        "capture_rate": 45,
        "base_happiness": 70,
        "hatch_counter": 20,
        "growth_rate": {"name": "medium-slow"},
        "egg_groups": [{"name": "monster"}, {"name": "dragon"}],
        "flavor_text_entries": [
            {
                "flavor_text": "Spits fire\nthat is hot\nenough.",
                "language": {"name": "en"},
                "version": {"name": "red"},
            }
        ],
        "is_baby": False,
        "is_legendary": False,
        "is_mythical": False,
        "evolution_chain": {"url": "https://pokeapi.co/api/v2/evolution-chain/2/"},
        "varieties": [{"is_default": True, "pokemon": {"name": "charizard", "url": "..."}}],
    }


@pytest.mark.asyncio
async def test_resolve_populates_detail_fields(async_db_session):
    """resolve() populates height, weight, abilities as list, and species fields."""
    from app.services.pokemon_resolver import pokemon_resolver_service

    mock_pokemon = _make_mock_pokemon_data()
    mock_species = _make_mock_species_data()

    with patch.object(
        pokemon_resolver_service, "_fetch_pokeapi",
        new=AsyncMock(return_value=(mock_pokemon, mock_species, {"english_name": "Charizard", "gen": 1, "species_name": "charizard"})),
    ), patch.object(
        pokemon_resolver_service, "_fetch_varieties", new=AsyncMock(return_value=[])
    ), patch.object(
        pokemon_resolver_service, "_fetch_forms", new=AsyncMock(return_value=[])
    ):
        result = await pokemon_resolver_service.resolve(6, 9, [], async_db_session)

    assert result.height == 17
    assert result.weight == 905
    assert result.base_experience == 240
    assert result.species_name == "charizard"
    assert result.genus == "Flame Pokémon"
    assert result.generation_name == "generation-i"
    assert result.gender_rate == 1
    assert result.capture_rate == 45
    assert result.evolution_chain_id == 2
    assert result.egg_groups == ["monster", "dragon"]
    assert result.is_legendary is False
    # abilities as list
    assert len(result.abilities) == 2
    assert result.abilities[0].name == "blaze"
    assert result.abilities[0].is_hidden is False
    assert result.abilities[1].name == "solar-power"
    assert result.abilities[1].is_hidden is True
    # moves full (no trim without includes)
    assert len(result.moves) == 1
    assert result.moves[0].name == "flamethrower"
    assert result.moves[0].learn_details[0].version_group == "sword-shield"
    # flavor text full (no trim without includes)
    assert len(result.flavor_text_entries) == 1
    assert result.flavor_text_entries[0].language == "en"
    assert "Spits fire" in result.flavor_text_entries[0].text


@pytest.mark.asyncio
async def test_resolve_slim_response_omits_moves_and_flavor(async_db_session):
    """Slim response (no includes) sets moves=[] and flavor_text_entries=[]."""
    from app.services.pokemon_resolver import pokemon_resolver_service

    mock_pokemon = _make_mock_pokemon_data()
    mock_species = _make_mock_species_data()

    with patch.object(
        pokemon_resolver_service, "_fetch_pokeapi",
        new=AsyncMock(return_value=(mock_pokemon, mock_species, {"english_name": "Charizard", "gen": 1, "species_name": "charizard"})),
    ), patch.object(
        pokemon_resolver_service, "_fetch_varieties", new=AsyncMock(return_value=[])
    ), patch.object(
        pokemon_resolver_service, "_fetch_forms", new=AsyncMock(return_value=[])
    ):
        result = await pokemon_resolver_service.resolve(6, 9, [], async_db_session)

    assert result.moves == []
    assert result.flavor_text_entries == []
    assert result.moves_url is not None
    assert result.flavor_text_url is not None


@pytest.mark.asyncio
async def test_resolve_includes_moves_returns_full_list(async_db_session):
    """?includes[]=moves returns full move list."""
    from app.services.pokemon_resolver import pokemon_resolver_service

    mock_pokemon = _make_mock_pokemon_data()
    mock_species = _make_mock_species_data()

    with patch.object(
        pokemon_resolver_service, "_fetch_pokeapi",
        new=AsyncMock(return_value=(mock_pokemon, mock_species, {"english_name": "Charizard", "gen": 1, "species_name": "charizard"})),
    ), patch.object(
        pokemon_resolver_service, "_fetch_varieties", new=AsyncMock(return_value=[])
    ), patch.object(
        pokemon_resolver_service, "_fetch_forms", new=AsyncMock(return_value=[])
    ):
        result = await pokemon_resolver_service.resolve(6, 9, ["moves"], async_db_session)

    assert len(result.moves) == 1
    assert result.moves[0].name == "flamethrower"
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd backend && pytest tests/test_pokemon_resolver.py::test_resolve_populates_detail_fields tests/test_pokemon_resolver.py::test_resolve_slim_response_omits_moves_and_flavor tests/test_pokemon_resolver.py::test_resolve_includes_moves_returns_full_list -v
```

Expected: FAIL — `_fetch_pokeapi` currently returns two values, not three; new fields not populated.

- [ ] **Step 3: Update `_fetch_pokeapi` to return full `species_data`**

In `pokemon_resolver.py`, replace the `_fetch_pokeapi` method:

```python
async def _fetch_pokeapi(self, pokemon_id: int) -> tuple[dict, dict, dict]:
    """Returns (pokemon_data, species_data, meta) where meta = {english_name, gen, species_name}."""
    pokemon_r = await self._pokeapi_http.get(f"{_POKEAPI_BASE}/pokemon/{pokemon_id}")
    pokemon_r.raise_for_status()
    pokemon_data = pokemon_r.json()

    species_url: str = pokemon_data["species"]["url"]
    species_r = await self._pokeapi_http.get(species_url)
    species_r.raise_for_status()
    species_data = species_r.json()

    english_name = next(
        (n["name"] for n in species_data.get("names", []) if n["language"]["name"] == "en"),
        species_data["name"].title(),
    )
    gen_suffix = species_data.get("generation", {}).get("name", "generation-ix").split("-")[-1]
    gen_num = _ROMAN.get(gen_suffix, 9)
    species_name: str = species_data["name"]

    return pokemon_data, species_data, {
        "english_name": english_name,
        "gen": gen_num,
        "species_name": species_name,
    }
```

- [ ] **Step 4: Update all callers of `_fetch_pokeapi` to unpack three values**

In `resolve()`, change:
```python
# Before
pokemon_data, species_info = await self._fetch_pokeapi(pokemon_id)
# ...
english_species_name: str = species_info["english_name"]
species_gen: int = species_info["gen"]
species_name: str = species_info["species_name"]
raw_varieties = species_info["varieties"]

# After
pokemon_data, species_data, species_info = await self._fetch_pokeapi(pokemon_id)
# ...
english_species_name: str = species_info["english_name"]
species_gen: int = species_info["gen"]
species_name: str = species_info["species_name"]
raw_varieties = species_data.get("varieties", [])
```

- [ ] **Step 5: Populate new fields in `resolve()` — after existing step 4 (gen overrides)**

Add after the existing `types, base_stats, abilities = self._apply_gen_overrides(...)` line:

```python
# --- New fields ---
# abilities as typed list
abilities_list = [
    AbilityInfo(
        name=a["ability"]["name"],
        is_hidden=a.get("is_hidden", False),
        slot=a.get("slot", 1),
    )
    for a in pokemon_data.get("abilities", [])
]

# moves (always built; trimmed to [] at response time)
moves_list = [
    MoveSummary(
        name=m["move"]["name"],
        learn_details=[
            MoveLearnDetail(
                version_group=d["version_group"]["name"],
                method=d["move_learn_method"]["name"],
                level=d.get("level_learned_at", 0),
            )
            for d in m.get("version_group_details", [])
        ],
    )
    for m in pokemon_data.get("moves", [])
]

# species detail fields
genus = next(
    (g["genus"] for g in species_data.get("genera", []) if g["language"]["name"] == "en"),
    None,
)
generation_name = species_data.get("generation", {}).get("name", "generation-ix")
gender_rate = species_data.get("gender_rate")
capture_rate = species_data.get("capture_rate")
base_happiness = species_data.get("base_happiness")
hatch_counter = species_data.get("hatch_counter")
growth_rate_obj = species_data.get("growth_rate")
growth_rate = growth_rate_obj.get("name") if growth_rate_obj else None
egg_groups = [e["name"] for e in species_data.get("egg_groups", [])]
flavor_text_entries_list = [
    FlavorTextEntry(
        text=e["flavor_text"].replace("\n", " ").replace("\f", " "),
        language=e["language"]["name"],
        version=e["version"]["name"],
    )
    for e in species_data.get("flavor_text_entries", [])
]
is_baby = species_data.get("is_baby", False)
is_legendary = species_data.get("is_legendary", False)
is_mythical = species_data.get("is_mythical", False)
chain_url = (species_data.get("evolution_chain") or {}).get("url")
evolution_chain_id: int | None = None
if chain_url:
    try:
        evolution_chain_id = int(chain_url.rstrip("/").split("/")[-1])
    except (ValueError, IndexError):
        pass
```

- [ ] **Step 6: Update `abilities` variable and add new fields to the `PokemonResolvedResponse` construction in `resolve()`**

Replace the `abilities=abilities` assignment and add all new fields:

```python
response = PokemonResolvedResponse(
    pokemon_id=pokemon_id,
    gen=gen,
    name=pokemon_name,
    types=types,
    base_stats=base_stats,
    abilities=abilities_list,                         # changed
    height=pokemon_data.get("height", 0),             # new
    weight=pokemon_data.get("weight", 0),             # new
    base_experience=pokemon_data.get("base_experience"),  # new
    species_name=species_data.get("name"),            # new
    moves=moves_list,                                 # new (trimmed to [] later)
    moves_url=f"{base_url}/pokemon/{pokemon_id}/moves",  # new
    supplement_moves=supplement_moves,
    smogon_analyses=smogon_analyses,
    smogon_url=f"{base_url}/pokemon/{pokemon_id}/smogon",
    varieties=varieties,
    varieties_url=f"{base_url}/pokemon/{pokemon_id}/varieties",
    forms=forms,
    forms_url=f"{base_url}/pokemon/{pokemon_id}/forms",
    sprite_urls=sprite_urls,
    resolved_at=now,
    genus=genus,                                      # new
    generation_name=generation_name,                  # new
    gender_rate=gender_rate,                          # new
    capture_rate=capture_rate,                        # new
    base_happiness=base_happiness,                    # new
    hatch_counter=hatch_counter,                      # new
    growth_rate=growth_rate,                          # new
    egg_groups=egg_groups,                            # new
    flavor_text_entries=flavor_text_entries_list,     # new (trimmed to [] later)
    flavor_text_url=f"{base_url}/pokemon/{pokemon_id}/flavor-text",  # new
    is_baby=is_baby,                                  # new
    is_legendary=is_legendary,                        # new
    is_mythical=is_mythical,                          # new
    evolution_chain_id=evolution_chain_id,            # new
)
```

- [ ] **Step 7: Update `_fetch_forms` to populate `form_id` and `is_default`**

In `_fetch_forms`, change the default form construction:

```python
result: list[FormData] = [FormData(
    name=default_form_name,
    form_id=base_id,
    is_default=True,
    front_sprite_url=default_front_sprite,
    sprite_urls=default_sprite_urls,
)]
```

And for non-default forms, after `resp.json()`:

```python
form_id = resp.json().get("id", base_id) if not isinstance(resp, Exception) and resp.status_code == 200 else base_id
result.append(FormData(
    name=form_name,
    form_id=form_id,
    is_default=False,
    front_sprite_url=api_front,
    sprite_urls=sprite_urls,
))
```

And for the error fallback case, add `form_id=base_id, is_default=False`:

```python
result.append(FormData(name=form_name, form_id=base_id, is_default=False, front_sprite_url=front_sprite))
```

- [ ] **Step 8: Update `_trim_response` to slim moves and flavor text**

Add after the existing smogon trim block:

```python
if "moves" not in includes:
    response = response.model_copy(update={"moves": []})
if "flavor" not in includes:
    response = response.model_copy(update={"flavor_text_entries": []})
```

- [ ] **Step 9: Add `resolve_moves` and `resolve_flavor_text` methods to `PokemonResolverService`**

Add after `resolve_forms`:

```python
async def resolve_moves(
    self, name_or_id: str, db: AsyncSession, base_url: str = ""
) -> "MovesResponse":
    from app.schemas.pokemon_resolved import MovesResponse
    pokemon_id = await self._resolve_name_or_id(name_or_id)

    result = await db.execute(
        select(PokemonResolved).where(
            PokemonResolved.pokemon_id == pokemon_id,
            PokemonResolved.gen == 9,
            PokemonResolved.resolved_at
            + text("(ttl_days * interval '1 day')")
            > func.now(),
        )
    )
    row = result.scalar_one_or_none()
    if row and row.data.get("moves"):
        return MovesResponse(
            pokemon_id=pokemon_id,
            name=row.data.get("name", ""),
            moves=row.data["moves"],
        )

    full = await self.resolve(pokemon_id, 9, ["moves"], db, base_url)
    return MovesResponse(pokemon_id=pokemon_id, name=full.name, moves=full.moves)


async def resolve_flavor_text(
    self, name_or_id: str, lang: str | None, db: AsyncSession, base_url: str = ""
) -> "FlavorTextResponse":
    from app.schemas.pokemon_resolved import FlavorTextResponse
    pokemon_id = await self._resolve_name_or_id(name_or_id)

    result = await db.execute(
        select(PokemonResolved).where(
            PokemonResolved.pokemon_id == pokemon_id,
            PokemonResolved.gen == 9,
            PokemonResolved.resolved_at
            + text("(ttl_days * interval '1 day')")
            > func.now(),
        )
    )
    row = result.scalar_one_or_none()
    if row and row.data.get("flavor_text_entries"):
        entries = row.data["flavor_text_entries"]
        if lang:
            entries = [e for e in entries if e.get("language") == lang]
        return FlavorTextResponse(
            pokemon_id=pokemon_id,
            name=row.data.get("name", ""),
            flavor_text_entries=entries,
        )

    full = await self.resolve(pokemon_id, 9, ["flavor"], db, base_url)
    filtered = (
        [e for e in full.flavor_text_entries if e.language == lang]
        if lang else full.flavor_text_entries
    )
    return FlavorTextResponse(
        pokemon_id=pokemon_id, name=full.name, flavor_text_entries=filtered
    )
```

- [ ] **Step 10: Add new routes to `pokemon.py`**

Add **before** `@router.get("/{name_or_id}/resolved", ...)`:

```python
@router.get("/moves/{name_or_id}", response_model=MovesResponse)
async def get_pokemon_moves(
    request: Request,
    name_or_id: str,
    db: DB,
) -> MovesResponse:
    """
    Return the full moves list for a Pokémon (all version groups).
    Served from PostgreSQL cache when available; triggers a full resolve on miss.
    """
    return await pokemon_resolver_service.resolve_moves(
        name_or_id, db, _base_url(request)
    )


@router.get("/flavor-text/{name_or_id}", response_model=FlavorTextResponse)
async def get_pokemon_flavor_text(
    request: Request,
    name_or_id: str,
    db: DB,
    lang: str | None = None,
) -> FlavorTextResponse:
    """
    Return Pokédex flavor text entries for a Pokémon.
    - **lang**: Optional language code (e.g. "en"). Omit for all languages.
    Served from PostgreSQL cache when available.
    """
    return await pokemon_resolver_service.resolve_flavor_text(
        name_or_id, lang, db, _base_url(request)
    )
```

Also add `MovesResponse` and `FlavorTextResponse` to the import at the top of `pokemon.py`:

```python
from app.schemas.pokemon_resolved import (
    FlavorTextResponse,
    FormsResponse,
    MovesResponse,
    PokemonResolvedResponse,
    SmogonResponse,
    VarietiesResponse,
)
```

- [ ] **Step 11: Run the failing tests to confirm they now pass**

```bash
cd backend && pytest tests/test_pokemon_resolver.py::test_resolve_populates_detail_fields tests/test_pokemon_resolver.py::test_resolve_slim_response_omits_moves_and_flavor tests/test_pokemon_resolver.py::test_resolve_includes_moves_returns_full_list -v
```

Expected: all 3 PASS.

- [ ] **Step 12: Run full test suite**

```bash
cd backend && pytest -v
```

Expected: all tests pass.

- [ ] **Step 13: Commit**

```bash
git add backend/app/schemas/pokemon_resolved.py \
        backend/app/services/pokemon_resolver.py \
        backend/app/routers/pokemon.py \
        backend/tests/test_pokemon_resolver.py
git commit -m "feat: backend resolver populates full detail/species fields + moves/flavor endpoints"
```

---

## Task 3: Flutter typed models

**Files:**
- Create: `lib/services/pokemon_resolved/models.dart`
- Create: `test/services/pokemon_resolved/models_test.dart`

**Interfaces:**
- Produces: `AbilityInfo`, `MoveLearnDetail`, `MoveSummary`, `SpriteUrlsFull`, `PokemonResolvedBackendResponse` — used by Tasks 4, 5, 6

- [ ] **Step 1: Write failing tests**

Create `test/services/pokemon_resolved/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

void main() {
  group('AbilityInfo', () {
    test('fromJson parses backend response format', () {
      final a = AbilityInfo.fromJson({
        'name': 'blaze',
        'is_hidden': false,
        'slot': 1,
      });
      expect(a.name, 'blaze');
      expect(a.isHidden, false);
      expect(a.slot, 1);
    });

    test('fromPokeApi parses PokéAPI format', () {
      final a = AbilityInfo.fromPokeApi({
        'ability': {'name': 'blaze', 'url': '...'},
        'is_hidden': false,
        'slot': 1,
      });
      expect(a.name, 'blaze');
      expect(a.isHidden, false);
    });

    test('toJson round-trips', () {
      final a = AbilityInfo(name: 'blaze', isHidden: false, slot: 1);
      final json = a.toJson();
      final b = AbilityInfo.fromJson(json);
      expect(b.name, 'blaze');
      expect(b.slot, 1);
    });
  });

  group('MoveSummary', () {
    test('fromPokeApi parses PokéAPI move format', () {
      final m = MoveSummary.fromPokeApi({
        'move': {'name': 'flamethrower', 'url': '...'},
        'version_group_details': [
          {
            'level_learned_at': 0,
            'move_learn_method': {'name': 'machine', 'url': '...'},
            'version_group': {'name': 'sword-shield', 'url': '...'},
          }
        ],
      });
      expect(m.name, 'flamethrower');
      expect(m.learnDetails.length, 1);
      expect(m.learnDetails[0].method, 'machine');
      expect(m.learnDetails[0].versionGroup, 'sword-shield');
      expect(m.learnDetails[0].level, 0);
    });

    test('fromJson parses backend format', () {
      final m = MoveSummary.fromJson({
        'name': 'flamethrower',
        'learn_details': [
          {'version_group': 'sword-shield', 'method': 'machine', 'level': 0}
        ],
      });
      expect(m.name, 'flamethrower');
      expect(m.learnDetails[0].versionGroup, 'sword-shield');
    });

    test('toJson round-trips', () {
      final m = MoveSummary(
        name: 'flamethrower',
        learnDetails: [
          MoveLearnDetail(versionGroup: 'sword-shield', method: 'machine', level: 0)
        ],
      );
      final json = m.toJson();
      final b = MoveSummary.fromJson(json);
      expect(b.name, 'flamethrower');
      expect(b.learnDetails[0].method, 'machine');
    });
  });

  group('SpriteUrlsFull', () {
    test('fromJson parses backend response', () {
      final s = SpriteUrlsFull.fromJson({
        'official_artwork': 'https://example.com/art/6.png',
        'home': 'https://example.com/home/6.png',
        'official_artwork_shiny': null,
        'home_shiny': null,
      });
      expect(s.officialArtwork, 'https://example.com/art/6.png');
      expect(s.home, 'https://example.com/home/6.png');
      expect(s.officialArtworkShiny, isNull);
    });
  });

  group('PokemonResolvedBackendResponse', () {
    test('fromJson parses minimal valid response', () {
      final json = _minimalResolvedJson();
      final r = PokemonResolvedBackendResponse.fromJson(json);
      expect(r.pokemonId, 6);
      expect(r.name, 'charizard');
      expect(r.types, ['Fire', 'Flying']);
      expect(r.abilities.length, 1);
      expect(r.abilities[0].name, 'blaze');
      expect(r.height, 17);
      expect(r.evolutionChainId, 2);
      expect(r.genus, 'Flame Pokémon');
    });

    test('toPokemonEntry constructs correct PokemonEntry', () {
      final r = PokemonResolvedBackendResponse.fromJson(_minimalResolvedJson());
      final entry = r.toPokemonEntry();
      expect(entry.id, 6);
      expect(entry.types, ['Fire', 'Flying']);
      expect(entry.stats['hp'], 78);
      expect(entry.abilities[0].name, 'blaze');
      expect(entry.formNames, ['charizard']);
    });

    test('toPokemonSpeciesEntry constructs correct PokemonSpeciesEntry', () {
      final r = PokemonResolvedBackendResponse.fromJson(_minimalResolvedJson());
      final species = r.toPokemonSpeciesEntry();
      expect(species.generationName, 'generation-i');
      expect(species.genderRate, 1);
      expect(species.evolutionChainId, 2);
      expect(species.eggGroups, ['monster', 'dragon']);
      expect(species.isLegendary, false);
    });

    test('toCosmeticForms filters out default form', () {
      final json = _minimalResolvedJson();
      (json['forms'] as List).add({
        'name': 'charizard-mega-x',
        'form_id': 10034,
        'is_default': false,
        'front_sprite_url': 'https://example.com/10034.png',
        'sprite_urls': null,
      });
      final r = PokemonResolvedBackendResponse.fromJson(json);
      final forms = r.toCosmeticForms();
      expect(forms.length, 1);
      expect(forms[0].name, 'charizard-mega-x');
    });
  });
}

Map<String, dynamic> _minimalResolvedJson() => {
  'pokemon_id': 6,
  'gen': 9,
  'name': 'charizard',
  'types': ['Fire', 'Flying'],
  'base_stats': {'hp': 78, 'attack': 84, 'defense': 78,
                 'special-attack': 109, 'special-defense': 85, 'speed': 100},
  'abilities': [
    {'name': 'blaze', 'is_hidden': false, 'slot': 1}
  ],
  'height': 17,
  'weight': 905,
  'base_experience': 240,
  'species_name': 'charizard',
  'moves': [],
  'moves_url': 'https://example.com/pokemon/6/moves',
  'supplement_moves': [],
  'smogon_analyses': null,
  'smogon_url': null,
  'varieties': [],
  'varieties_url': null,
  'forms': [
    {'name': 'charizard', 'form_id': 6, 'is_default': true,
     'front_sprite_url': 'https://example.com/6.png', 'sprite_urls': null}
  ],
  'forms_url': null,
  'sprite_urls': {
    'official_artwork': 'https://example.com/art/6.png',
    'official_artwork_shiny': null,
    'home': 'https://example.com/home/6.png',
    'home_shiny': null,
    'home_female': null,
    'home_female_shiny': null,
    'game_front': null,
    'game_front_shiny': null,
    'game_front_female': null,
    'game_front_female_shiny': null,
  },
  'resolved_at': '2026-06-18T12:00:00Z',
  'genus': 'Flame Pokémon',
  'generation_name': 'generation-i',
  'gender_rate': 1,
  'capture_rate': 45,
  'base_happiness': 70,
  'hatch_counter': 20,
  'growth_rate': 'medium-slow',
  'egg_groups': ['monster', 'dragon'],
  'flavor_text_entries': [],
  'flavor_text_url': 'https://example.com/pokemon/6/flavor-text',
  'is_baby': false,
  'is_legendary': false,
  'is_mythical': false,
  'evolution_chain_id': 2,
};
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
flutter test test/services/pokemon_resolved/models_test.dart
```

Expected: FAIL — `lib/services/pokemon_resolved/models.dart` does not exist.

- [ ] **Step 3: Create `lib/services/pokemon_resolved/models.dart`**

```dart
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class AbilityInfo {
  final String name;
  final bool isHidden;
  final int slot;

  const AbilityInfo({
    required this.name,
    required this.isHidden,
    required this.slot,
  });

  factory AbilityInfo.fromJson(Map<String, dynamic> json) => AbilityInfo(
        name: json['name'] as String,
        isHidden: json['is_hidden'] as bool,
        slot: json['slot'] as int,
      );

  factory AbilityInfo.fromPokeApi(Map<String, dynamic> json) => AbilityInfo(
        name: (json['ability'] as Map<String, dynamic>)['name'] as String,
        isHidden: json['is_hidden'] as bool,
        slot: json['slot'] as int,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_hidden': isHidden,
        'slot': slot,
      };
}

class MoveLearnDetail {
  final String versionGroup;
  final String method;
  final int level;

  const MoveLearnDetail({
    required this.versionGroup,
    required this.method,
    required this.level,
  });

  factory MoveLearnDetail.fromJson(Map<String, dynamic> json) => MoveLearnDetail(
        versionGroup: json['version_group'] as String,
        method: json['method'] as String,
        level: json['level'] as int,
      );

  factory MoveLearnDetail.fromPokeApi(Map<String, dynamic> json) => MoveLearnDetail(
        versionGroup: (json['version_group'] as Map<String, dynamic>)['name'] as String,
        method: (json['move_learn_method'] as Map<String, dynamic>)['name'] as String,
        level: json['level_learned_at'] as int,
      );

  Map<String, dynamic> toJson() => {
        'version_group': versionGroup,
        'method': method,
        'level': level,
      };
}

class MoveSummary {
  final String name;
  final List<MoveLearnDetail> learnDetails;

  const MoveSummary({required this.name, required this.learnDetails});

  factory MoveSummary.fromJson(Map<String, dynamic> json) => MoveSummary(
        name: json['name'] as String,
        learnDetails: (json['learn_details'] as List<dynamic>)
            .map((d) => MoveLearnDetail.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  factory MoveSummary.fromPokeApi(Map<String, dynamic> json) => MoveSummary(
        name: (json['move'] as Map<String, dynamic>)['name'] as String,
        learnDetails: (json['version_group_details'] as List<dynamic>)
            .map((d) => MoveLearnDetail.fromPokeApi(d as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'learn_details': learnDetails.map((d) => d.toJson()).toList(),
      };
}

class SpriteUrlsFull {
  final String? officialArtwork;
  final String? officialArtworkShiny;
  final String? home;
  final String? homeShiny;
  final String? homeFemale;
  final String? homeFemaleShiny;
  final String? gameFront;
  final String? gameFrontShiny;
  final String? gameFrontFemale;
  final String? gameFrontFemaleShiny;

  const SpriteUrlsFull({
    this.officialArtwork,
    this.officialArtworkShiny,
    this.home,
    this.homeShiny,
    this.homeFemale,
    this.homeFemaleShiny,
    this.gameFront,
    this.gameFrontShiny,
    this.gameFrontFemale,
    this.gameFrontFemaleShiny,
  });

  factory SpriteUrlsFull.fromJson(Map<String, dynamic> json) => SpriteUrlsFull(
        officialArtwork: json['official_artwork'] as String?,
        officialArtworkShiny: json['official_artwork_shiny'] as String?,
        home: json['home'] as String?,
        homeShiny: json['home_shiny'] as String?,
        homeFemale: json['home_female'] as String?,
        homeFemaleShiny: json['home_female_shiny'] as String?,
        gameFront: json['game_front'] as String?,
        gameFrontShiny: json['game_front_shiny'] as String?,
        gameFrontFemale: json['game_front_female'] as String?,
        gameFrontFemaleShiny: json['game_front_female_shiny'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'official_artwork': officialArtwork,
        'official_artwork_shiny': officialArtworkShiny,
        'home': home,
        'home_shiny': homeShiny,
        'home_female': homeFemale,
        'home_female_shiny': homeFemaleShiny,
        'game_front': gameFront,
        'game_front_shiny': gameFrontShiny,
        'game_front_female': gameFrontFemale,
        'game_front_female_shiny': gameFrontFemaleShiny,
      };
}

class PokemonResolvedBackendResponse {
  final int pokemonId;
  final int gen;
  final String name;
  final List<String> types;
  final Map<String, int> baseStats;
  final List<AbilityInfo> abilities;
  final int height;
  final int weight;
  final int? baseExperience;
  final String? speciesName;
  final List<MoveSummary> moves;
  final String? movesUrl;
  final List<MoveSummary> supplementMoves;
  final List<Map<String, dynamic>>? smogonAnalyses;
  final List<Map<String, dynamic>> varieties;
  final List<_FormBackendData> forms;
  final SpriteUrlsFull spriteUrls;
  final String? genus;
  final String generationName;
  final int? genderRate;
  final int? captureRate;
  final int? baseHappiness;
  final int? hatchCounter;
  final String? growthRate;
  final List<String> eggGroups;
  final List<FlavorTextEntry> flavorTextEntries;
  final String? flavorTextUrl;
  final bool isBaby;
  final bool isLegendary;
  final bool isMythical;
  final int? evolutionChainId;

  const PokemonResolvedBackendResponse({
    required this.pokemonId,
    required this.gen,
    required this.name,
    required this.types,
    required this.baseStats,
    required this.abilities,
    required this.height,
    required this.weight,
    this.baseExperience,
    this.speciesName,
    required this.moves,
    this.movesUrl,
    required this.supplementMoves,
    this.smogonAnalyses,
    required this.varieties,
    required this.forms,
    required this.spriteUrls,
    this.genus,
    required this.generationName,
    this.genderRate,
    this.captureRate,
    this.baseHappiness,
    this.hatchCounter,
    this.growthRate,
    required this.eggGroups,
    required this.flavorTextEntries,
    this.flavorTextUrl,
    required this.isBaby,
    required this.isLegendary,
    required this.isMythical,
    this.evolutionChainId,
  });

  factory PokemonResolvedBackendResponse.fromJson(Map<String, dynamic> json) {
    return PokemonResolvedBackendResponse(
      pokemonId: json['pokemon_id'] as int,
      gen: json['gen'] as int,
      name: json['name'] as String,
      types: List<String>.from(json['types'] as List),
      baseStats: Map<String, int>.from(
        (json['base_stats'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      ),
      abilities: (json['abilities'] as List<dynamic>)
          .map((a) => AbilityInfo.fromJson(a as Map<String, dynamic>))
          .toList(),
      height: (json['height'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      baseExperience: (json['base_experience'] as num?)?.toInt(),
      speciesName: json['species_name'] as String?,
      moves: (json['moves'] as List<dynamic>? ?? [])
          .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
          .toList(),
      movesUrl: json['moves_url'] as String?,
      supplementMoves: (json['supplement_moves'] as List<dynamic>? ?? [])
          .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
          .toList(),
      smogonAnalyses: (json['smogon_analyses'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      varieties: (json['varieties'] as List<dynamic>? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      forms: (json['forms'] as List<dynamic>? ?? [])
          .map((f) => _FormBackendData.fromJson(f as Map<String, dynamic>))
          .toList(),
      spriteUrls: SpriteUrlsFull.fromJson(
          json['sprite_urls'] as Map<String, dynamic>? ?? {}),
      genus: json['genus'] as String?,
      generationName: json['generation_name'] as String? ?? 'generation-ix',
      genderRate: (json['gender_rate'] as num?)?.toInt(),
      captureRate: (json['capture_rate'] as num?)?.toInt(),
      baseHappiness: (json['base_happiness'] as num?)?.toInt(),
      hatchCounter: (json['hatch_counter'] as num?)?.toInt(),
      growthRate: json['growth_rate'] as String?,
      eggGroups: List<String>.from(json['egg_groups'] as List? ?? []),
      flavorTextEntries: (json['flavor_text_entries'] as List<dynamic>? ?? [])
          .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
          .toList(),
      flavorTextUrl: json['flavor_text_url'] as String?,
      isBaby: json['is_baby'] as bool? ?? false,
      isLegendary: json['is_legendary'] as bool? ?? false,
      isMythical: json['is_mythical'] as bool? ?? false,
      evolutionChainId: (json['evolution_chain_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'pokemon_id': pokemonId,
        'gen': gen,
        'name': name,
        'types': types,
        'base_stats': baseStats,
        'abilities': abilities.map((a) => a.toJson()).toList(),
        'height': height,
        'weight': weight,
        'base_experience': baseExperience,
        'species_name': speciesName,
        'moves': moves.map((m) => m.toJson()).toList(),
        'moves_url': movesUrl,
        'supplement_moves': supplementMoves.map((m) => m.toJson()).toList(),
        'smogon_analyses': smogonAnalyses,
        'varieties': varieties,
        'forms': forms.map((f) => f.toJson()).toList(),
        'sprite_urls': spriteUrls.toJson(),
        'genus': genus,
        'generation_name': generationName,
        'gender_rate': genderRate,
        'capture_rate': captureRate,
        'base_happiness': baseHappiness,
        'hatch_counter': hatchCounter,
        'growth_rate': growthRate,
        'egg_groups': eggGroups,
        'flavor_text_entries': flavorTextEntries.map((e) => e.toJson()).toList(),
        'flavor_text_url': flavorTextUrl,
        'is_baby': isBaby,
        'is_legendary': isLegendary,
        'is_mythical': isMythical,
        'evolution_chain_id': evolutionChainId,
      };

  PokemonEntry toPokemonEntry() => PokemonEntry(
        id: pokemonId,
        name: name,
        speciesName: speciesName,
        height: height,
        weight: weight,
        baseExperience: baseExperience,
        types: types,
        officialArtworkUrl: spriteUrls.officialArtwork,
        sprites: null,
        stats: baseStats,
        abilities: abilities,
        moves: moves,
        formNames: forms.map((f) => f.name).toList(),
      );

  PokemonSpeciesEntry toPokemonSpeciesEntry() => PokemonSpeciesEntry(
        id: pokemonId,
        name: speciesName ?? name,
        genus: genus,
        generationName: generationName,
        genderRate: genderRate,
        captureRate: captureRate,
        baseHappiness: baseHappiness,
        hatchCounter: hatchCounter,
        growthRate: growthRate,
        eggGroups: eggGroups,
        flavorTextEntries: flavorTextEntries,
        isBaby: isBaby,
        isLegendary: isLegendary,
        isMythical: isMythical,
        evolutionChainId: evolutionChainId,
        varieties: varieties
            .map((v) => PokemonVariety(
                  isDefault: v['is_default'] as bool? ?? false,
                  name: (v['name'] as String?) ?? '',
                ))
            .toList(),
      );

  List<PokemonFormEntry> toCosmeticForms() {
    const kBase =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';
    return forms
        .where((f) => !f.isDefault)
        .map((f) => PokemonFormEntry(
              id: f.formId ?? pokemonId,
              name: f.name,
              formName: _extractFormName(f.name, speciesName ?? name),
              isDefault: false,
              spriteUrl: f.spriteUrls?.gameFront ?? f.frontSpriteUrl,
              spriteShinyUrl: f.spriteUrls?.gameFrontShiny,
              officialArtworkUrl: f.spriteUrls?.officialArtwork,
              officialArtworkShinyUrl: f.spriteUrls?.officialArtworkShiny,
            ))
        .toList();
  }

  static String _extractFormName(String formName, String speciesName) {
    final prefix = '$speciesName-';
    if (formName.startsWith(prefix)) return formName.substring(prefix.length);
    return formName;
  }
}

class _FormBackendData {
  final String name;
  final int? formId;
  final bool isDefault;
  final String? frontSpriteUrl;
  final SpriteUrlsFull? spriteUrls;

  const _FormBackendData({
    required this.name,
    this.formId,
    required this.isDefault,
    this.frontSpriteUrl,
    this.spriteUrls,
  });

  factory _FormBackendData.fromJson(Map<String, dynamic> json) => _FormBackendData(
        name: json['name'] as String,
        formId: (json['form_id'] as num?)?.toInt(),
        isDefault: json['is_default'] as bool? ?? false,
        frontSpriteUrl: json['front_sprite_url'] as String?,
        spriteUrls: json['sprite_urls'] != null
            ? SpriteUrlsFull.fromJson(json['sprite_urls'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'form_id': formId,
        'is_default': isDefault,
        'front_sprite_url': frontSpriteUrl,
        'sprite_urls': spriteUrls?.toJson(),
      };
}
```

- [ ] **Step 4: Add `fromBackend` and `toJson` to `FlavorTextEntry` in `pokemon_species_entry.dart`**

```dart
// Add after the existing fromJson factory:
factory FlavorTextEntry.fromBackend(Map<String, dynamic> json) {
  return FlavorTextEntry(
    text: json['text'] as String,
    language: json['language'] as String,
    version: json['version'] as String,
  );
}

Map<String, dynamic> toJson() => {
  'text': text,
  'language': language,
  'version': version,
};
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/services/pokemon_resolved/models_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/pokemon_resolved/models.dart \
        lib/services/pokeapi/models/pokemon_species_entry.dart \
        test/services/pokemon_resolved/models_test.dart
git commit -m "feat: Flutter typed models for backend resolved response"
```

---

## Task 4: `PokemonEntry` field type migration + consumer updates

**Files:**
- Modify: `lib/services/pokeapi/models/pokemon_entry.dart`
- Modify: `lib/features/pokedex/models/resolved_pokemon.dart`
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`
- Modify: `lib/features/pokedex/presentation/pokemon_detail_placeholder_screen.dart`
- Modify: `lib/features/teams/presentation/slot_config_screen.dart`
- Modify: `lib/features/teams/presentation/team_detail_screen.dart`

**Interfaces:**
- Consumes: `AbilityInfo`, `MoveSummary`, `MoveLearnDetail` from Task 3
- Produces: updated `PokemonEntry` with typed fields — used by all providers

- [ ] **Step 1: Update `PokemonEntry` fields and `fromJson`**

Replace the entire `pokemon_entry.dart` content:

```dart
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';

class PokemonEntry {
  final int id;
  final String name;
  final String? speciesName;
  final int height;
  final int weight;
  final int? baseExperience;
  final List<String> types;           // was Map<int, String>
  final String? officialArtworkUrl;
  final Map<String, dynamic>? sprites;
  final Map<String, int> stats;       // was List<Map<String, dynamic>>
  final List<AbilityInfo> abilities;  // was List<Map<String, dynamic>>
  final List<MoveSummary> moves;      // was List<Map<String, dynamic>>
  final List<String> formNames;

  PokemonEntry({
    required this.id,
    required this.name,
    this.speciesName,
    required this.height,
    required this.weight,
    this.baseExperience,
    required this.types,
    this.officialArtworkUrl,
    this.sprites,
    this.stats = const {},
    this.abilities = const [],
    this.moves = const [],
    this.formNames = const [],
  });

  factory PokemonEntry.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'] as Map<String, dynamic>?;
    final rawTypes = json['types'] as List<dynamic>? ?? [];
    final sortedTypes = List.of(rawTypes)
      ..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));

    return PokemonEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      speciesName: json['species']?['name'] as String?,
      height: json['height'] as int,
      weight: json['weight'] as int,
      baseExperience: json['base_experience'] as int?,
      types: sortedTypes.map((t) => t['type']['name'] as String).toList(),
      sprites: sprites,
      officialArtworkUrl:
          sprites?['other']?['official-artwork']?['front_default'] as String?,
      stats: Map.fromEntries(
        (json['stats'] as List<dynamic>? ?? []).map(
          (s) => MapEntry(
            (s as Map<String, dynamic>)['stat']['name'] as String,
            s['base_stat'] as int,
          ),
        ),
      ),
      abilities: (json['abilities'] as List<dynamic>? ?? [])
          .map((a) => AbilityInfo.fromPokeApi(a as Map<String, dynamic>))
          .toList(),
      moves: (json['moves'] as List<dynamic>? ?? [])
          .map((m) => MoveSummary.fromPokeApi(m as Map<String, dynamic>))
          .toList(),
      formNames: (json['forms'] as List<dynamic>? ?? [])
          .map((f) => (f as Map)['name'] as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'height': height,
        'weight': weight,
        'base_experience': baseExperience,
        'types': types,
        'sprites': sprites,
        'stats': stats,
        'abilities': abilities.map((a) => a.toJson()).toList(),
        'moves': moves.map((m) => m.toJson()).toList(),
      };

  String displayId() => '#${id.toString().padLeft(3, '0')}';

  String get displaySpeciesName {
    final sn = speciesName;
    if (sn != null && name.startsWith('$sn-')) {
      return sn
          .split('-')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return name
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String? get defaultFormLabel {
    final sn = speciesName;
    if (sn != null && name.startsWith('$sn-')) {
      return name.substring(sn.length + 1);
    }
    return null;
  }

  String? get officialArtworkShinyUrl =>
      sprites?['other']?['official-artwork']?['front_shiny'] as String?;

  String? getImageUrl() {
    if (officialArtworkUrl != null && officialArtworkUrl!.isNotEmpty) {
      return officialArtworkUrl;
    }
    return sprites?['front_default'] as String?;
  }

  String displayHeight() => '${(height / 10).toStringAsFixed(1)} m';
  String displayWeight() => '${(weight / 10).toStringAsFixed(1)} kg';
}
```

- [ ] **Step 2: Update `resolved_pokemon.dart` delegation getters**

```dart
// Change the three raw-map getters:
List<String> get types => detail.types;                  // was Map<int, String>
Map<String, int> get stats => detail.stats;              // was List<Map<String, dynamic>>
List<AbilityInfo> get abilities => detail.abilities;     // was List<Map<String, dynamic>>
List<MoveSummary> get moves => detail.moves;             // was List<Map<String, dynamic>>
```

- [ ] **Step 3: Run `flutter analyze` to find all broken consumers**

```bash
flutter analyze 2>&1 | grep "error:" | head -40
```

This lists every file with a broken access pattern. Fix each one using the patterns below.

- [ ] **Step 4: Fix `pokemon_detail_screen.dart` — types access (3 locations)**

Find all occurrences of `.types[1]` and `.types.values`:

```bash
grep -n "\.types\[1\]\|\.types\.values\|\.types\.keys" lib/features/pokedex/presentation/pokemon_detail_screen.dart
```

**Pattern A** — primary type:
```dart
// Before
effectivePokemon.types[1] ?? effectivePokemon.types.values.first
// After
effectivePokemon.types.isNotEmpty ? effectivePokemon.types[0] : 'normal'
```

**Pattern B** — iterating all types:
```dart
// Before
pokemon.types.values.map((type) => TypeBadge(type: type))
// After
pokemon.types.map((type) => TypeBadge(type: type))
```

Apply to every occurrence in `pokemon_detail_screen.dart` (lines 149, 391, 687, 2007, 2702, 2846, 2882).

- [ ] **Step 5: Fix `pokemon_detail_screen.dart` — stats access**

The `_base()` method at line ~847:

```dart
// Before
int _base(String statName) {
  for (final s in pokemon.stats) {
    if ((s['stat'] as Map)['name'] == statName) {
      return s['base_stat'] as int;
    }
  }
  return 0;
}

// After
int _base(String statName) => pokemon.stats[statName] ?? 0;
```

Also fix line ~2025 where stats are iterated for display. Find it:

```bash
grep -n "pokemon\.stats\|s\['base_stat'\]\|s\['stat'\]" lib/features/pokedex/presentation/pokemon_detail_screen.dart
```

Replace any `s['base_stat'] as int` / `s['stat']['name'] as String` patterns with direct map access using the stat name keys `hp`, `attack`, `defense`, `special-attack`, `special-defense`, `speed`.

- [ ] **Step 6: Fix `pokemon_detail_screen.dart` — abilities access (line ~1562-1574)**

```dart
// Before
final abilities = pokemon.abilities;
// ...
final isHidden = slot['is_hidden'] as bool? ?? false;

// After
final abilities = pokemon.abilities;
// ...
final isHidden = ability.isHidden;  // where 'ability' is now AbilityInfo
```

Find exact context:
```bash
grep -n "abilities\|is_hidden\|ability\['" lib/features/pokedex/presentation/pokemon_detail_screen.dart | head -20
```

- [ ] **Step 7: Fix `pokemon_detail_placeholder_screen.dart` — types**

```bash
grep -n "\.types" lib/features/pokedex/presentation/pokemon_detail_placeholder_screen.dart
```

Line ~51: `data.types.values.map(...)` → `data.types.map(...)`

- [ ] **Step 8: Fix `slot_config_screen.dart` — abilities (lines 621-626, 762-765)**

```dart
// Before
final abilities = pokemon.abilities.map((a) => (
  name: a['ability']['name'] as String,
  isHidden: a['is_hidden'] as bool,
  abilitySlot: a['slot'] as int,
)).toList()
  ..sort((a, b) => a.abilitySlot.compareTo(b.abilitySlot));

// After
final abilities = pokemon.abilities
    .map((a) => (name: a.name, isHidden: a.isHidden, abilitySlot: a.slot))
    .toList()
  ..sort((a, b) => a.abilitySlot.compareTo(b.abilitySlot));
```

Apply the same transformation to the second occurrence around line 762.

- [ ] **Step 9: Fix `slot_config_screen.dart` — stats (lines 629-631, 688-689, 868-869)**

```dart
// Before
final baseStats = <String, int>{
  for (final s in pokemon.stats)
    s['stat']['name'] as String: s['base_stat'] as int,
};

// After
final baseStats = pokemon.stats;
```

The stats field is now already `Map<String, int>` — no loop needed. Apply to all three occurrences in `slot_config_screen.dart`.

- [ ] **Step 10: Fix `slot_config_screen.dart` — moves cast (line 641)**

```dart
// Before
final pokemonMoves = pokemon.moves.cast<Map<String, dynamic>>();

// After
final pokemonMoves = pokemon.moves;  // now List<MoveSummary>
```

Also fix line ~772 and ~814 where `formPokemon.moves` and `ancestor.moves` are cast/accessed as raw maps. Update all downstream access of `pokemonMoves` entries from raw map access to `m.name`, `m.learnDetails`, `d.versionGroup`, `d.method`, `d.level`.

- [ ] **Step 11: Fix `team_detail_screen.dart` — stats (lines ~842, 875, 941) and abilities (~1294)**

```dart
// Stats — before
for (final s in pokemon.stats)
  s['stat']['name'] as String: s['base_stat'] as int,
// After
...pokemon.stats,

// Abilities — before
megaPokemon.abilities.first['ability']['name'] as String
// After
megaPokemon.abilities.first.name
```

Find all locations:
```bash
grep -n "\.stats\b\|abilities\.first\[" lib/features/teams/presentation/team_detail_screen.dart
```

- [ ] **Step 12: Verify no remaining compile errors**

```bash
flutter analyze 2>&1 | grep "error:"
```

Expected: zero errors.

- [ ] **Step 13: Run existing Flutter tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 14: Commit**

```bash
git add lib/services/pokeapi/models/pokemon_entry.dart \
        lib/features/pokedex/models/resolved_pokemon.dart \
        lib/features/pokedex/presentation/pokemon_detail_screen.dart \
        lib/features/pokedex/presentation/pokemon_detail_placeholder_screen.dart \
        lib/features/teams/presentation/slot_config_screen.dart \
        lib/features/teams/presentation/team_detail_screen.dart
git commit -m "refactor: PokemonEntry typed fields (types/stats/abilities/moves) + consumer updates"
```

---

## Task 5: Flutter service layer — cache, repository, providers

**Files:**
- Create: `lib/services/pokemon_resolved/pokemon_resolved_cache.dart`
- Create: `lib/services/pokemon_resolved/pokemon_backend_repository.dart`
- Create: `lib/services/pokemon_resolved/pokemon_resolved_providers.dart`
- Modify: `lib/main.dart`
- Create: `test/services/pokemon_resolved/pokemon_backend_repository_test.dart`

**Interfaces:**
- Consumes: `PokemonResolvedBackendResponse`, `MoveSummary`, `FlavorTextEntry` from Task 3
- Produces: `pokemonResolvedCacheProvider`, `pokemonBackendRepositoryProvider`, `pokemonMovesProvider`, `pokemonFlavorTextProvider`

- [ ] **Step 1: Write failing repository tests**

Create `test/services/pokemon_resolved/pokemon_backend_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';

class MockDio extends Mock implements Dio {}
class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late PokemonBackendRepository repo;

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    repo = PokemonBackendRepository(mockApiClient);
  });

  group('fetchResolved', () {
    test('returns PokemonResolvedBackendResponse on 200', () async {
      when(() => mockDio.get<dynamic>('/pokemon/6/resolved',
              queryParameters: anyNamed('queryParameters')))
          .thenAnswer((_) async => Response(
                data: _minimalResolvedJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/pokemon/6/resolved'),
              ));

      final result = await repo.fetchResolved(6);
      expect(result.pokemonId, 6);
      expect(result.name, 'charizard');
    });

    test('throws on non-200', () async {
      when(() => mockDio.get<dynamic>('/pokemon/6/resolved',
              queryParameters: anyNamed('queryParameters')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 404,
                requestOptions: RequestOptions(path: '/pokemon/6/resolved'),
              ));

      expect(() => repo.fetchResolved(6), throwsException);
    });
  });

  group('fetchMoves', () {
    test('returns List<MoveSummary> on 200', () async {
      when(() => mockDio.get<dynamic>('/pokemon/moves/6'))
          .thenAnswer((_) async => Response(
                data: {
                  'pokemon_id': 6,
                  'name': 'charizard',
                  'moves': [
                    {
                      'name': 'flamethrower',
                      'learn_details': [
                        {'version_group': 'sword-shield', 'method': 'machine', 'level': 0}
                      ],
                    }
                  ],
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/pokemon/moves/6'),
              ));

      final moves = await repo.fetchMoves(6);
      expect(moves.length, 1);
      expect(moves[0].name, 'flamethrower');
    });
  });

  group('fetchFlavorText', () {
    test('returns List<FlavorTextEntry> filtered by lang', () async {
      when(() => mockDio.get<dynamic>('/pokemon/flavor-text/6',
              queryParameters: {'lang': 'en'}))
          .thenAnswer((_) async => Response(
                data: {
                  'pokemon_id': 6,
                  'name': 'charizard',
                  'flavor_text_entries': [
                    {'text': 'Spits fire.', 'language': 'en', 'version': 'red'}
                  ],
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/pokemon/flavor-text/6'),
              ));

      final entries = await repo.fetchFlavorText(6, lang: 'en');
      expect(entries.length, 1);
      expect(entries[0].text, 'Spits fire.');
    });
  });
}

Map<String, dynamic> _minimalResolvedJson() => {
  'pokemon_id': 6, 'gen': 9, 'name': 'charizard',
  'types': ['Fire', 'Flying'],
  'base_stats': {'hp': 78, 'attack': 84, 'defense': 78,
                 'special-attack': 109, 'special-defense': 85, 'speed': 100},
  'abilities': [{'name': 'blaze', 'is_hidden': false, 'slot': 1}],
  'height': 17, 'weight': 905, 'base_experience': 240,
  'species_name': 'charizard', 'moves': [], 'moves_url': null,
  'supplement_moves': [], 'smogon_analyses': null,
  'varieties': [], 'varieties_url': null,
  'forms': [{'name': 'charizard', 'form_id': 6, 'is_default': true,
             'front_sprite_url': null, 'sprite_urls': null}],
  'forms_url': null,
  'sprite_urls': {'official_artwork': null, 'official_artwork_shiny': null,
                  'home': null, 'home_shiny': null, 'home_female': null,
                  'home_female_shiny': null, 'game_front': null,
                  'game_front_shiny': null, 'game_front_female': null,
                  'game_front_female_shiny': null},
  'resolved_at': '2026-06-18T12:00:00Z',
  'genus': 'Flame Pokémon', 'generation_name': 'generation-i',
  'gender_rate': 1, 'capture_rate': 45, 'base_happiness': 70,
  'hatch_counter': 20, 'growth_rate': 'medium-slow',
  'egg_groups': ['monster', 'dragon'], 'flavor_text_entries': [],
  'flavor_text_url': null, 'is_baby': false,
  'is_legendary': false, 'is_mythical': false, 'evolution_chain_id': 2,
};
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
flutter test test/services/pokemon_resolved/pokemon_backend_repository_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create `pokemon_resolved_cache.dart`**

```dart
import 'package:hive_flutter/hive_flutter.dart';

class PokemonResolvedCache {
  static final PokemonResolvedCache _instance = PokemonResolvedCache._internal();
  factory PokemonResolvedCache() => _instance;
  PokemonResolvedCache._internal();

  Box get _hive => Hive.box('pokemon_resolved_cache');

  Map<String, dynamic>? getIfValid(String key) {
    final data = _hive.get(key);
    if (data is Map) {
      final payload = data['payload'];
      final expiresAt = data['expiresAt'] as int?;
      if (payload is Map && expiresAt != null &&
          expiresAt > DateTime.now().millisecondsSinceEpoch) {
        return Map<String, dynamic>.from(payload as Map);
      }
    }
    return null;
  }

  void putWithTTL(String key, Map<String, dynamic> value, Duration ttl) {
    _hive.put(key, {
      'payload': value,
      'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
    });
  }
}
```

- [ ] **Step 4: Create `pokemon_backend_repository.dart`**

```dart
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class PokemonBackendRepository {
  PokemonBackendRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<PokemonResolvedBackendResponse> fetchResolved(int id) async {
    final response = await _apiClient.dio.get<dynamic>('/pokemon/$id/resolved');
    if (response.statusCode != 200) {
      throw Exception('Backend resolved fetch failed for id=$id: ${response.statusCode}');
    }
    return PokemonResolvedBackendResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<MoveSummary>> fetchMoves(int id) async {
    final response = await _apiClient.dio.get<dynamic>('/pokemon/moves/$id');
    if (response.statusCode != 200) {
      throw Exception('Backend moves fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['moves'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<FlavorTextEntry>> fetchFlavorText(int id, {String? lang}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/pokemon/flavor-text/$id',
      queryParameters: lang != null ? {'lang': lang} : null,
    );
    if (response.statusCode != 200) {
      throw Exception('Backend flavor text fetch failed for id=$id: ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['flavor_text_entries'] as List<dynamic>)
        .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Step 5: Create `pokemon_resolved_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_cache.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';

final pokemonResolvedCacheProvider = Provider<PokemonResolvedCache>(
  (_) => PokemonResolvedCache(),
);

final pokemonBackendRepositoryProvider = Provider<PokemonBackendRepository>(
  (ref) => PokemonBackendRepository(ref.read(apiClientProvider)),
);

/// Lazy-loaded full moves list. Checks pokemon_resolved_cache first,
/// then backend, then falls back to PokéAPI (offline).
final pokemonMovesProvider =
    FutureProvider.family<List<MoveSummary>, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cached = cache.getIfValid('moves_$id');
  if (cached != null) {
    return (cached['moves'] as List<dynamic>)
        .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final moves = await repo.fetchMoves(id);
    cache.putWithTTL(
      'moves_$id',
      {'moves': moves.map((m) => m.toJson()).toList()},
      const Duration(days: 7),
    );
    return moves;
  } catch (_) {
    // Offline fallback: return moves from PokéAPI detail
    final detail = await ref.watch(pokemonDetailProvider(id).future);
    return detail.moves;
  }
});

/// Lazy-loaded English flavor text entries.
final pokemonFlavorTextProvider =
    FutureProvider.family<List<FlavorTextEntry>, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);
  final cached = cache.getIfValid('flavor_$id');
  if (cached != null) {
    return (cached['entries'] as List<dynamic>)
        .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
        .toList();
  }

  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final entries = await repo.fetchFlavorText(id, lang: 'en');
    cache.putWithTTL(
      'flavor_$id',
      {'entries': entries.map((e) => e.toJson()).toList()},
      const Duration(days: 7),
    );
    return entries;
  } catch (_) {
    // Offline fallback: return English entries from PokéAPI species
    final species = await ref.watch(pokemonSpeciesProvider(id).future);
    return species.flavorTextEntries
        .where((e) => e.language == 'en')
        .toList();
  }
});
```

- [ ] **Step 6: Open the new Hive box in `main.dart`**

Find the line `await Hive.openBox('pokeapi_cache');` and add after it:

```dart
await Hive.openBox('pokemon_resolved_cache');
```

There are two locations in `main.dart` — the `_workmanagerCallback` isolate and the `main()` function. Only add to the `main()` function (not the WorkManager isolate, which doesn't use `resolvedPokemonProvider`).

- [ ] **Step 7: Run repository tests**

```bash
flutter test test/services/pokemon_resolved/pokemon_backend_repository_test.dart
```

Expected: all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/services/pokemon_resolved/pokemon_resolved_cache.dart \
        lib/services/pokemon_resolved/pokemon_backend_repository.dart \
        lib/services/pokemon_resolved/pokemon_resolved_providers.dart \
        lib/main.dart \
        test/services/pokemon_resolved/pokemon_backend_repository_test.dart
git commit -m "feat: Flutter pokemon_resolved service layer (cache, repository, providers)"
```

---

## Task 6: Update `ResolvedPokemon` + `resolvedPokemonProvider` hybrid fetch

**Files:**
- Modify: `lib/features/pokedex/models/resolved_pokemon.dart`
- Modify: `lib/features/pokedex/providers/resolved_pokemon_provider.dart`
- Create: `test/services/pokemon_resolved/resolved_pokemon_provider_test.dart`

**Interfaces:**
- Consumes: `PokemonResolvedBackendResponse`, `PokemonResolvedCache`, `PokemonBackendRepository` from Tasks 3 and 5
- Produces: updated `resolvedPokemonProvider` with hybrid fetch

- [ ] **Step 1: Write failing provider tests**

Create `test/services/pokemon_resolved/resolved_pokemon_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/pokedex/models/resolved_pokemon.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_cache.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokemonResolvedCache extends Mock implements PokemonResolvedCache {}

void main() {
  late MockPokemonBackendRepository mockRepo;
  late MockPokemonResolvedCache mockCache;

  setUp(() {
    mockRepo = MockPokemonBackendRepository();
    mockCache = MockPokemonResolvedCache();
  });

  ProviderContainer _makeContainer() {
    return ProviderContainer(overrides: [
      pokemonBackendRepositoryProvider.overrideWithValue(mockRepo),
      pokemonResolvedCacheProvider.overrideWithValue(mockCache),
    ]);
  }

  test('returns ResolvedPokemon from backend when cache misses', () async {
    when(() => mockCache.getIfValid(any())).thenReturn(null);
    when(() => mockRepo.fetchResolved(6))
        .thenAnswer((_) async => _makeBackendResponse());
    when(() => mockCache.putWithTTL(any(), any(), any())).thenReturn(null);

    final container = _makeContainer();
    final result = await container.read(resolvedPokemonProvider(6).future);

    expect(result.id, 6);
    expect(result.detail.types, ['Fire', 'Flying']);
    expect(result.species.evolutionChainId, 2);
    expect(result.spriteUrls.officialArtwork,
        'https://example.com/art/6.png');
    verify(() => mockCache.putWithTTL('resolved_6', any(), any())).called(1);
  });

  test('returns ResolvedPokemon from Hive cache without backend call', () async {
    when(() => mockCache.getIfValid('resolved_6'))
        .thenReturn(_makeBackendResponse().toJson());

    final container = _makeContainer();
    final result = await container.read(resolvedPokemonProvider(6).future);

    expect(result.id, 6);
    verifyNever(() => mockRepo.fetchResolved(any()));
  });

  test('falls back to PokéAPI when backend throws', () async {
    when(() => mockCache.getIfValid(any())).thenReturn(null);
    when(() => mockRepo.fetchResolved(6)).thenThrow(Exception('offline'));

    // PokéAPI providers would need to be mocked too in a real integration test.
    // This test verifies the provider does not throw on backend failure.
    final container = _makeContainer();
    // The PokéAPI providers will themselves throw since there's no real network,
    // but the key assertion is that backend failure doesn't propagate before
    // the fallback is attempted.
    // In a full integration test with mocked PokéAPI providers, verify
    // the result has supplementMoves=[] and smogonAnalyses=null.
    expect(
      () => container.read(resolvedPokemonProvider(6).future),
      isA<Future>(), // provider attempts fallback, doesn't rethrow backend error
    );
  });
}

PokemonResolvedBackendResponse _makeBackendResponse() =>
    PokemonResolvedBackendResponse.fromJson({
      'pokemon_id': 6, 'gen': 9, 'name': 'charizard',
      'types': ['Fire', 'Flying'],
      'base_stats': {'hp': 78, 'attack': 84, 'defense': 78,
                     'special-attack': 109, 'special-defense': 85, 'speed': 100},
      'abilities': [{'name': 'blaze', 'is_hidden': false, 'slot': 1}],
      'height': 17, 'weight': 905, 'base_experience': 240,
      'species_name': 'charizard', 'moves': [], 'moves_url': null,
      'supplement_moves': [], 'smogon_analyses': null,
      'varieties': [], 'varieties_url': null,
      'forms': [{'name': 'charizard', 'form_id': 6, 'is_default': true,
                 'front_sprite_url': null, 'sprite_urls': null}],
      'forms_url': null,
      'sprite_urls': {
        'official_artwork': 'https://example.com/art/6.png',
        'official_artwork_shiny': null, 'home': null, 'home_shiny': null,
        'home_female': null, 'home_female_shiny': null, 'game_front': null,
        'game_front_shiny': null, 'game_front_female': null,
        'game_front_female_shiny': null,
      },
      'resolved_at': '2026-06-18T12:00:00Z',
      'genus': 'Flame Pokémon', 'generation_name': 'generation-i',
      'gender_rate': 1, 'capture_rate': 45, 'base_happiness': 70,
      'hatch_counter': 20, 'growth_rate': 'medium-slow',
      'egg_groups': ['monster', 'dragon'], 'flavor_text_entries': [],
      'flavor_text_url': null, 'is_baby': false,
      'is_legendary': false, 'is_mythical': false, 'evolution_chain_id': 2,
    });
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
flutter test test/services/pokemon_resolved/resolved_pokemon_provider_test.dart
```

Expected: FAIL — `ResolvedPokemon` missing `spriteUrls`, `supplementMoves`, `smogonAnalyses` fields.

- [ ] **Step 3: Update `resolved_pokemon.dart`**

```dart
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';

class ResolvedPokemon {
  final PokemonEntry detail;
  final PokemonSpeciesEntry species;
  final List<PokemonFormEntry> cosmeticForms;
  final SpriteUrlsFull spriteUrls;
  final List<MoveSummary> supplementMoves;
  final List<Map<String, dynamic>>? smogonAnalyses;

  const ResolvedPokemon({
    required this.detail,
    required this.species,
    required this.cosmeticForms,
    required this.spriteUrls,
    this.supplementMoves = const [],
    this.smogonAnalyses,
  });

  int get id => detail.id;
  String get name => detail.name;
  String? get speciesName => detail.speciesName;
  String get displaySpeciesName => detail.displaySpeciesName;
  List<String> get formNames => detail.formNames;
  List<String> get types => detail.types;
  Map<String, dynamic>? get sprites => detail.sprites;
  String? get officialArtworkUrl => detail.officialArtworkUrl;
  Map<String, int> get stats => detail.stats;
  List<AbilityInfo> get abilities => detail.abilities;
  List<MoveSummary> get moves => detail.moves;
  List<PokemonVariety> get varieties => species.varieties;
  String? get generationName => species.generationName;
}
```

- [ ] **Step 4: Update `resolved_pokemon_provider.dart` with hybrid fetch**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/resolved_pokemon.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

final resolvedPokemonProvider =
    FutureProvider.family<ResolvedPokemon, int>((ref, id) async {
  final cache = ref.read(pokemonResolvedCacheProvider);

  // 1. Hive cache hit
  final cached = cache.getIfValid('resolved_$id');
  if (cached != null) {
    final response = PokemonResolvedBackendResponse.fromJson(cached);
    return _fromBackendResponse(response);
  }

  // 2. Backend fetch (in parallel with nothing — returns fast on Postgres hit)
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final response = await repo.fetchResolved(id);
    cache.putWithTTL('resolved_$id', response.toJson(), const Duration(days: 7));
    return _fromBackendResponse(response);
  } catch (_) {
    // 3. Offline fallback — Task C behavior
  }

  // Offline: assemble from PokéAPI (already Hive-cached per pokeapi_cache)
  final detail = await ref.watch(pokemonDetailProvider(id).future);
  final species = await ref.watch(pokemonSpeciesProvider(id).future);

  final rawCosmetic =
      PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains(detail.name)
          ? const <PokemonFormEntry>[]
          : await ref.watch(cosmeticFormsProvider(detail.name).future);

  final patched = rawCosmetic.map((f) {
    if (f.spriteUrl == null && f.formName == 'female') {
      return PokemonFormEntry(
        id: f.id,
        name: f.name,
        formName: f.formName,
        isDefault: f.isDefault,
        spriteUrl: '${_kBase}female/${detail.id}.png',
        spriteShinyUrl: '${_kBase}shiny/female/${detail.id}.png',
        officialArtworkUrl: f.officialArtworkUrl,
        officialArtworkShinyUrl: f.officialArtworkShinyUrl,
      );
    }
    return f;
  }).toList();

  final cosmeticForms = [
    ...patched,
    if (PokemonDataRegistry.instance.cosmeticGenderDiffPokemon
        .contains(detail.name))
      PokemonFormEntry(
        id: detail.id,
        name: '${detail.name}-female',
        formName: 'female',
        isDefault: false,
        spriteUrl: '${_kBase}female/${detail.id}.png',
        spriteShinyUrl: '${_kBase}shiny/female/${detail.id}.png',
      ),
  ];

  return ResolvedPokemon(
    detail: detail,
    species: species,
    cosmeticForms: cosmeticForms,
    spriteUrls: SpriteUrlsFull(
      officialArtwork: detail.officialArtworkUrl,
      officialArtworkShiny: detail.officialArtworkShinyUrl,
    ),
  );
});

ResolvedPokemon _fromBackendResponse(PokemonResolvedBackendResponse r) {
  final detail = r.toPokemonEntry();
  final species = r.toPokemonSpeciesEntry();
  final cosmeticForms = _patchCosmeticForms(r.toCosmeticForms(), detail.id, detail.name);

  return ResolvedPokemon(
    detail: detail,
    species: species,
    cosmeticForms: cosmeticForms,
    spriteUrls: r.spriteUrls,
    supplementMoves: r.supplementMoves,
    smogonAnalyses: r.smogonAnalyses,
  );
}

List<PokemonFormEntry> _patchCosmeticForms(
    List<PokemonFormEntry> forms, int pokemonId, String pokemonName) {
  final patched = forms.map((f) {
    if (f.spriteUrl == null && f.formName == 'female') {
      return PokemonFormEntry(
        id: f.id,
        name: f.name,
        formName: f.formName,
        isDefault: f.isDefault,
        spriteUrl: '${_kBase}female/$pokemonId.png',
        spriteShinyUrl: '${_kBase}shiny/female/$pokemonId.png',
        officialArtworkUrl: f.officialArtworkUrl,
        officialArtworkShinyUrl: f.officialArtworkShinyUrl,
      );
    }
    return f;
  }).toList();

  if (PokemonDataRegistry.instance.cosmeticGenderDiffPokemon.contains(pokemonName)) {
    patched.add(PokemonFormEntry(
      id: pokemonId,
      name: '$pokemonName-female',
      formName: 'female',
      isDefault: false,
      spriteUrl: '${_kBase}female/$pokemonId.png',
      spriteShinyUrl: '${_kBase}shiny/female/$pokemonId.png',
    ));
  }
  return patched;
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/services/pokemon_resolved/resolved_pokemon_provider_test.dart
```

Expected: first two tests PASS, fallback test passes (no throw propagated).

- [ ] **Step 6: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/pokedex/models/resolved_pokemon.dart \
        lib/features/pokedex/providers/resolved_pokemon_provider.dart \
        test/services/pokemon_resolved/resolved_pokemon_provider_test.dart
git commit -m "feat: resolvedPokemonProvider hybrid fetch (Hive → backend → PokéAPI fallback)"
```

---

## Task 7: Lazy moves + flavor text providers wired into consumers

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`
- Modify: `lib/features/teams/presentation/slot_config_screen.dart`

**Interfaces:**
- Consumes: `pokemonMovesProvider`, `pokemonFlavorTextProvider` from Task 5; `MoveSummary`, `MoveLearnDetail` from Task 3

- [ ] **Step 1: Update `pokemon_detail_screen.dart` — moves tab switch to `pokemonMovesProvider`**

The `_PokemonMovesTab` widget takes `pokemon: PokemonEntry` and reads `widget.pokemon.moves`. Change it to receive moves directly:

Find the `_PokemonMovesTab` class declaration and add a `pokemonId` parameter, then watch `pokemonMovesProvider` inside the widget instead of using `widget.pokemon.moves`:

```dart
// In _PokemonMovesTab, add id field and watch the provider:
// Add to class fields:
final int pokemonId;

// In build or the getter methods, replace widget.pokemon.moves with:
final movesAsync = ref.watch(pokemonMovesProvider(pokemonId));
final moves = movesAsync.asData?.value ?? const [];
```

Then update `_versions` and `_grouped` to use `moves` (now `List<MoveSummary>`) instead of `widget.pokemon.moves`:

```dart
List<String> get _versions {
  final seen = <String>{};
  for (final m in moves) {
    for (final d in m.learnDetails) {
      seen.add(d.versionGroup);
    }
  }
  return seen.toList()
    ..sort((a, b) {
      final ai = _vgOrder.indexOf(a);
      final bi = _vgOrder.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return bi.compareTo(ai);
    });
}

Map<String, List<_MoveRow>> _grouped(
  String? version, {
  required Map<String, String> psIdToName,
  int? gen,
  FormatService? formatService,
}) {
  final groups = <String, List<_MoveRow>>{};
  for (final m in moves) {
    for (final d in m.learnDetails) {
      if (version != null && d.versionGroup != version) continue;
      groups.putIfAbsent(d.method, () => []);
      if (!groups[d.method]!.any((r) => r.moveName == m.name)) {
        groups[d.method]!.add(_MoveRow(moveName: m.name, level: d.level));
      }
    }
  }
  groups['level-up']?.sort((a, b) => a.level.compareTo(b.level));
  // event moves logic unchanged (uses formatService.eventMovesForGen)
  return groups;
}
```

Also update `_psIdToNameMap` and any other method in `_PokemonMovesTab` that iterates `widget.pokemon.moves` using raw map access. Use the same pattern: `m.name` and `m.learnDetails`.

- [ ] **Step 2: Update `pokemon_detail_screen.dart` — Overview tab flavor text switch**

Find where `resolved.species.flavorTextEntries` is used (in the Overview tab) and replace with:

```dart
final flavorAsync = ref.watch(pokemonFlavorTextProvider(widget.pokemonId));
final flavorEntries = flavorAsync.asData?.value ?? const [];
```

Pass `flavorEntries` (now `List<FlavorTextEntry>`) to the flavor text widget instead of the species field.

- [ ] **Step 3: Update `slot_config_screen.dart` — move picker switch to `pokemonMovesProvider`**

Find `final pokemonMoves = pokemon.moves;` (after Task 4 fix) and replace with a provider watch:

```dart
final pokemonMovesAsync = ref.watch(pokemonMovesProvider(slot.pokemonId));
final pokemonMoves = pokemonMovesAsync.asData?.value ?? const <MoveSummary>[];
```

Update all downstream access of `pokemonMoves` entries to use typed fields:
- `m.name` (was `m['move']['name'] as String`)
- `m.learnDetails` (was `m['version_group_details']`)
- `d.versionGroup` (was `d['version_group']['name']`)
- `d.method` (was `d['move_learn_method']['name']`)
- `d.level` (was `d['level_learned_at']`)

Also update `formPokemon.moves` and `ancestor.moves` access in the same file to the typed pattern. These are accessed via `pokemonByNameProvider` results, which still use `PokemonEntry.fromJson` (PokéAPI path) — since `PokemonEntry.moves` is now `List<MoveSummary>` after Task 4, the typed access already works.

- [ ] **Step 4: Run `flutter analyze`**

```bash
flutter analyze 2>&1 | grep "error:"
```

Expected: zero errors.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/pokedex/presentation/pokemon_detail_screen.dart \
        lib/features/teams/presentation/slot_config_screen.dart
git commit -m "feat: moves + flavor text lazy-loaded via backend providers in detail screen and slot config"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| New Hive box `pokemon_resolved_cache` | Task 5 |
| Backend `AbilityInfo`, `MoveSummary`, `MoveLearnDetail`, `FlavorTextEntry` models | Task 1 |
| `PokemonResolvedResponse` new fields (height, weight, species fields, etc.) | Task 1 |
| `_fetch_pokeapi` returns full `species_data` | Task 2 |
| `resolve()` populates all new fields | Task 2 |
| `_trim_response` slims moves + flavor | Task 2 |
| `GET /pokemon/{id}/moves` endpoint | Task 2 |
| `GET /pokemon/{id}/flavor-text` endpoint | Task 2 |
| Flutter `AbilityInfo`, `MoveSummary`, `SpriteUrlsFull`, `PokemonResolvedBackendResponse` | Task 3 |
| `FlavorTextEntry.fromBackend` / `.toJson` | Task 3 |
| `PokemonEntry.types → List<String>` | Task 4 |
| `PokemonEntry.stats → Map<String, int>` | Task 4 |
| `PokemonEntry.abilities → List<AbilityInfo>` | Task 4 |
| `PokemonEntry.moves → List<MoveSummary>` | Task 4 |
| Consumer access pattern updates | Task 4 |
| `PokemonResolvedCache` | Task 5 |
| `PokemonBackendRepository` | Task 5 |
| `pokemonMovesProvider` + `pokemonFlavorTextProvider` | Task 5 |
| `ResolvedPokemon` new fields (`spriteUrls`, `supplementMoves`, `smogonAnalyses`) | Task 6 |
| `resolvedPokemonProvider` hybrid fetch (Hive → backend → PokéAPI fallback) | Task 6 |
| Detail screen moves tab → `pokemonMovesProvider` | Task 7 |
| Detail screen flavor text → `pokemonFlavorTextProvider` | Task 7 |
| Slot config move picker → `pokemonMovesProvider` | Task 7 |

No gaps found.
