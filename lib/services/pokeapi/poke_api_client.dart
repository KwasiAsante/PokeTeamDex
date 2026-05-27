import 'package:dio/dio.dart';

class PokeApiClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://pokeapi.co/api/v2',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  Dio get client => _dio;
}