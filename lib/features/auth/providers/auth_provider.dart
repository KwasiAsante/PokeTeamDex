import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/api/auth_api.dart';
import 'package:poke_team_dex/services/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'auth_token';

// ── Token persistence ─────────────────────────────────────────────────────────

Future<String?> loadStoredToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_tokenKey);
}

Future<void> _saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_tokenKey, token);
}

Future<void> _clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_tokenKey);
}

// ── Auth state ────────────────────────────────────────────────────────────────

/// null  = loading (checking stored token)
/// ''    = not logged in
/// token = logged in
final authTokenProvider = StateProvider<String?>((ref) => null);

final isLoggedInProvider = Provider<bool>((ref) {
  final token = ref.watch(authTokenProvider);
  return token != null && token.isNotEmpty;
});

// ── Auth actions ──────────────────────────────────────────────────────────────

Future<void> register(WidgetRef ref, String email, String password) async {
  final api = ref.read(authApiProvider);
  final token = await api.register(email, password);
  await _saveToken(token);
  ref.read(authTokenProvider.notifier).state = token;
  ref.read(syncServiceProvider).run(token: token);
}

Future<void> login(WidgetRef ref, String email, String password) async {
  final api = ref.read(authApiProvider);
  final token = await api.login(email, password);
  await _saveToken(token);
  ref.read(authTokenProvider.notifier).state = token;
  ref.read(syncServiceProvider).run(token: token);
}

Future<void> logout(WidgetRef ref) async {
  await _clearToken();
  ref.read(authTokenProvider.notifier).state = '';
}
