import 'package:poke_team_dex/services/format/format_models.dart';

/// Returns [override] if non-empty after trimming, otherwise [parsed].
String resolveTeamName(String override, String parsed) =>
    override.trim().isNotEmpty ? override.trim() : parsed;

/// Returns [override].id if [override] is non-null, otherwise [parsed].
String? resolveFormatId(GameFormat? override, String? parsed) =>
    override != null ? override.id : parsed;
