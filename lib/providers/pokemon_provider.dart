import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/pokeapi_service.dart';

class PokemonProvider with ChangeNotifier {
  final List<Pokemon> _pokemonList = [];
  bool _isLoading = false;
  int _offset = 0;  // Track pagination offset
  final int _limit = 20;  // Number of Pokémon to load at a time

  List<Pokemon> get pokemonList => _pokemonList;
  bool get isLoading => _isLoading;

  final PokeApiService _apiService = PokeApiService();

  // Fetch Pokémon list
  Future<void> loadPokemonList() async {
    if (_isLoading) return;  // Prevent multiple requests

    _isLoading = true;
    notifyListeners();

    try {
      List<Pokemon> newPokemon = await _apiService.fetchPokemonList(limit: _limit, offset: _offset);
      _pokemonList.addAll(newPokemon);  // Append new Pokémon
      _offset += _limit;  // Update offset
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
