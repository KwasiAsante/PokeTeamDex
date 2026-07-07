# lib/services/catalog/

Dart models for the backend catalog endpoints (`/moves`, `/items`, `/abilities`).

| File | Purpose |
| ---- | ------- |
| `catalog_models.dart` | `BackendMoveEntry`, `BackendItemEntry`, `BackendAbilityEntry`, `PaginatedCatalogResponse<T>` — `fromJson` parsers and `fromName` sentinel constructors used by fallback paths |

The fetch methods that call the backend live in `pokemon_resolved/pokemon_backend_repository.dart`
(`fetchCatalogMoves`, `fetchCatalogMove`, `fetchCatalogItems`, `fetchCatalogItem`,
`fetchCatalogAbilities`, `fetchCatalogAbility`).

The Riverpod providers that wire backend → PokéAPI fallback → filtering live in the
respective feature provider files:

| Feature | Provider file |
| ------- | ------------- |
| Moves   | `lib/features/moves/providers/moves_provider.dart` |
| Items   | `lib/features/items/providers/items_provider.dart` |
| Abilities | `lib/features/abilities/providers/abilities_provider.dart` |
