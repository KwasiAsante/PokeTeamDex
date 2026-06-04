import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:poke_team_dex/services/update/update_info.dart';

const _owner = 'KwasiAsante';
const _repo = 'poke_team_dex';
const _webUrl = 'https://poketeamdex.web.app';

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = await PackageInfo.fromPlatform();
      final release = await _fetchLatestRelease();
      if (release == null) return null;

      final latestVersion = (release['tag_name'] as String).replaceFirst('v', '');
      if (!_isNewer(latestVersion, current.version)) return null;

      final assets = (release['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      return UpdateInfo(
        version: latestVersion,
        releaseUrl: release['html_url'] as String,
        apkUrl: _findAssetUrl(assets, '.apk'),
        msiUrl: _findAssetUrl(assets, '.msi'),
        exeUrl: _findAssetUrl(assets, '-Setup.exe'),
        webUrl: _webUrl,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final response = await http
        .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String? _findAssetUrl(List<Map<String, dynamic>> assets, String suffix) {
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith(suffix)) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// Returns true if [latest] is strictly greater than [current].
  bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(3, (i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0);
  }
}

/// Returns the download URL for the current platform, or null if not applicable.
String? platformDownloadUrl(UpdateInfo info) {
  if (kIsWeb) return info.webUrl;
  if (Platform.isAndroid) return info.apkUrl;
  if (Platform.isWindows) return info.exeUrl ?? info.msiUrl;
  return info.releaseUrl;
}
