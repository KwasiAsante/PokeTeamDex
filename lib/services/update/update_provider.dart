import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/update/update_info.dart';
import 'package:poke_team_dex/services/update/update_service.dart';

final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  return UpdateService().checkForUpdate();
});
