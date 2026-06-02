import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/database/repositories/app_config_repository.dart';
import 'package:poke_team_dex/features/auth/providers/auth_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.read(appConfigRepositoryProvider),
    // Closure reads the in-memory provider state on every request so the
    // token is always current even immediately after login or logout without
    // relying on SharedPreferences flush timing.
    getToken: () => ref.read(authTokenProvider),
  );
});

class ApiClient {
  ApiClient(AppConfigRepository configRepo, {required String? Function() getToken}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(_AppInterceptor(configRepo, getToken));
  }

  late final Dio _dio;

  Dio get dio => _dio;
}

class _AppInterceptor extends Interceptor {
  _AppInterceptor(this._configRepo, this._getToken);
  final AppConfigRepository _configRepo;
  final String? Function() _getToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Resolve base URL from config on every request.
    options.baseUrl = await _configRepo.getApiBaseUrl();

    // Attach auth token from the in-memory provider state.
    final token = _getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
