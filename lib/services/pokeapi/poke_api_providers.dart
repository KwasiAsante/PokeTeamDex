import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_cache.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_client.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

final pokeApiClientProvider = Provider<PokeApiClient>((ref) => PokeApiClient());
final pokeApiCacheProvider = Provider<PokeApiCache>((ref) => PokeApiCache());
final pokeApiRepositoryProvider = Provider<PokeApiRepository>((ref) => PokeApiRepository(ref.read(pokeApiClientProvider), ref.read(pokeApiCacheProvider)));