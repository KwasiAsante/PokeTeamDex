import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/pokeapi_service.dart';

class PokemonProvider with ChangeNotifier {
  List<Pokemon> _pokemonList = [];
  bool _isLoading = false;

  List<Pokemon> get pokemonList => _pokemonList;
  bool get isLoading => _isLoading;

  final PokeApiService _apiService = PokeApiService();

  // Fetch Pokémon list
  Future<void> loadPokemonList() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pokemonList = await _apiService.fetchPokemonList();
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}