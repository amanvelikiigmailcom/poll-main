import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';

class ActivityService {
  ActivityService(this.api, this.storage);
  final ApiService api;
  final StorageService storage;
  Future<Map<String, dynamic>> page({String? cursor}) async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sign in to see campus activity.',
        statusCode: 401,
      );
    }
    try {
      final response = await api.dio.get<Map<String, dynamic>>(
        '/api/activity',
        queryParameters: {if (cursor != null) 'cursor': cursor},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (await storage.getToken() != token) {
        throw const ApiException(
          'Your account changed. Refresh activity.',
          statusCode: 409,
        );
      }
      return response.data ?? {};
    } on DioException catch (error) {
      if (await storage.getToken() != token) {
        throw const ApiException(
          'Your account changed. Refresh activity.',
          statusCode: 409,
        );
      }
      final body = error.response?.data;
      throw ApiException(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Couldn’t load activity. Please try again.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
