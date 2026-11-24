import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Every editor request, including failures, belongs to its opening session.
class ProfileEditService {
  ProfileEditService(this.api, this.storage);
  final ApiService api;
  final StorageService storage;

  Future<Map<String, dynamic>> request(
    String token, {
    String suffix = '',
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    if (token.isEmpty || token != await storage.getToken()) {
      throw const ApiException('Account changed. Reopen Edit profile.');
    }
    try {
      final response = await api.dio.request<Map<String, dynamic>>(
        '/api/profile-edit$suffix',
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (token != await storage.getToken()) {
        throw const ApiException('Account changed. Reopen Edit profile.');
      }
      return response.data ?? {};
    } on DioException catch (error) {
      if (token != await storage.getToken()) {
        throw const ApiException('Account changed. Reopen Edit profile.');
      }
      final body = error.response?.data;
      throw ApiException(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Couldn’t save your profile. Check your connection and try again.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}

/// The shell consults this only while Edit profile is the visible route.
class ProfileEditNavigationGuard {
  Future<bool> Function()? leave;
}
