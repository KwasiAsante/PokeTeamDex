import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/services/showdown_export.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

/// Writes a team's Showdown export to the configured PS teams directory.
/// Only active on desktop platforms (Windows / macOS / Linux).
class PsExportService {
  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Exports [team] to:
  ///   `{psDirectory}/{folderName}/[psFormat] {teamName}.txt`
  ///   (or `{psDirectory}/{teamName}.txt` when [folder] or format is null)
  /// Boxes use a `-box` suffix on the format tag: `[psFormat-box] {teamName}.txt`.
  /// The PS format prefix in the filename lets PS identify the tier without
  /// needing a === ... === header inside the file (which breaks PS's parser).
  static Future<void> exportTeam({
    required Team team,
    required TeamFolder? folder,
    required List<TeamSlot> slots,
    required String psDirectory,
    required PokeApiRepository pokeApi,
    String? formatLabel,
  }) async {
    if (!isSupported || slots.isEmpty) return;

    final text = await buildShowdownExport(slots, pokeApi);
    if (text.trim().isEmpty) return;

    // Build filename: "[gen6anythinggoes] Team Name.txt" when format is known.
    // Boxes get a "-box" suffix on the format tag: "[gen6anythinggoes-box] Box Name.txt".
    final psFormat = formatLabel != null ? kFormatToPsFormat[formatLabel] : null;
    final formatTag = psFormat != null
        ? (team.isBox ? '${_sanitize(psFormat)}-box' : _sanitize(psFormat))
        : null;
    final baseName = formatTag != null
        ? '[$formatTag] ${_sanitize(team.name)}'
        : _sanitize(team.name);
    final teamFile = '$baseName.txt';
    final dir = folder != null
        ? Directory('$psDirectory${Platform.pathSeparator}${_sanitize(folder.name)}')
        : Directory(psDirectory);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await File('${dir.path}${Platform.pathSeparator}$teamFile')
        .writeAsString(text);
  }

  /// Strips characters that are invalid in file / directory names on any OS.
  static String _sanitize(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
