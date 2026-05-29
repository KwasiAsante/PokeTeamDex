import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'auth_token';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(appConfigRepositoryProvider));
});

class ApiClient {
  ApiClient(AppConfigRepository configRepo) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(_AppInterceptor(configRepo));
  }

  late final Dio _dio;

  Dio get dio => _dio;
}

class _AppInterceptor extends Interceptor {
  _AppInterceptor(this._configRepo);
  final AppConfigRepository _configRepo;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Resolve base URL from config on every request
    options.baseUrl = await _configRepo.getApiBaseUrl();

    // Attach auth token if present
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
