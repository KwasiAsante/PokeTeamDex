import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/api/api_client.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.read(apiClientProvider).dio);
});

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<String> register(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
    return res.data!['access_token'] as String;
  }

  Future<String> login(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return res.data!['access_token'] as String;
  }

  /// Fetch the cached UtilityBillsServer session token from the backend.
  /// Returns null if the backend has not yet authenticated (503) or on any error.
  Future<String?> getLogsToken() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/meta/logs-token');
      return res.data?['token'] as String?;
    } catch (_) {
      return null;
    }
  }
}
