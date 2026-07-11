# lib/services/catalog/

Dart models for the backend catalog endpoints (`/moves`, `/items`, `/abilities`),
plus the client-side replication of the backend's PokéAPI+PS merge used when
both the backend and the local cache are unavailable.

| File | Purpose |
| ---- | ------- |
| `catalog_models.dart` | `BackendMoveEntry`, `BackendItemEntry`, `BackendAbilityEntry`, `PaginatedCatalogResponse<T>` — each entry type has `fromJson`/`toJson` (round-trips through the `withBackendFallback` cache). No sentinel/placeholder constructors — every path returns a fully-populated entry or the provider throws. |
| `catalog_offline_merge.dart` | `buildOfflineMoveCatalog()`/`buildOfflineItemCatalog()`/`buildOfflineAbilityCatalog()` — mirrors the backend's `CatalogService._preload_kind`: enumerate every name from PokéAPI, fetch each concurrently (bounded), enrich with `PsDataService` PS data, then append PS-only entries (Z-moves, Max moves, etc.) with no PokéAPI page of their own |

The fetch methods that call the backend live in `pokemon_resolved/pokemon_backend_repository.dart`
(`fetchCatalogMoves`, `fetchCatalogMove`, `fetchCatalogItems`, `fetchCatalogItem`,
`fetchCatalogAbilities`, `fetchCatalogAbility`).

The Riverpod providers that wire backend → cache → offline merge → filtering
live in the respective feature provider files, each built on
`withBackendFallback` (`lib/services/util/backend_provider_utils.dart`):

| Feature | Provider file |
| ------- | ------------- |
| Moves   | `lib/features/moves/providers/moves_provider.dart` |
| Items   | `lib/features/items/providers/items_provider.dart` |
| Abilities | `lib/features/abilities/providers/abilities_provider.dart` |
