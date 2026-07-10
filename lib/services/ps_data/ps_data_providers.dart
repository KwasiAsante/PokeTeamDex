import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_service.dart';

/// Singleton [PsDataService] — raw PS data used by `offlineFallback`
/// implementations across the catalog/resolved-Pokémon providers.
final psDataServiceProvider = Provider<PsDataService>((ref) {
  return PsDataService();
});
