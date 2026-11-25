import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/person_profile.dart';

/// Every response is bound to the credential that initiated it. No cross-account cache.
class SocialService {
  SocialService(this.api, this.storage);
  final ApiService api;
  final StorageService storage;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) => _request(path, method: method, data: data);

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sign in to find and add friends.',
        statusCode: 401,
      );
    }
    try {
      final response = await api.dio.request<Map<String, dynamic>>(
        '/api/social$path',
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (await storage.getToken() != token) {
        throw const ApiException(
          'Your account changed. Please try again.',
          statusCode: 409,
        );
      }
      return response.data ?? {};
    } on DioException catch (error) {
      if (await storage.getToken() != token) {
        throw const ApiException(
          'Your account changed. Please try again.',
          statusCode: 409,
        );
      }
      final body = error.response?.data;
      throw ApiException(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Couldn’t connect. Please try again.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> search(
    String username, {
    String? cursor,
  }) => request(
    '/search?q=${Uri.encodeComponent(username)}${cursor == null ? '' : '&cursor=${Uri.encodeComponent(cursor)}'}',
  );
  Future<Map<String, dynamic>> list(String kind, {String? cursor}) => request(
    '/list?kind=$kind${cursor == null ? '' : '&cursor=${Uri.encodeComponent(cursor)}'}',
  );
  Future<Map<String, dynamic>> suggestions() => request('/suggestions');
  Future<Map<String, dynamic>> profile(String id) =>
      request('/users/${Uri.encodeComponent(id)}');
  Future<PersonNominations> nominations(String id, {String? cursor}) async =>
      PersonNominations.fromJson(
        await request(
          '/users/${Uri.encodeComponent(id)}/nominations'
          '${cursor == null ? '' : '?cursor=${Uri.encodeComponent(cursor)}'}',
        ),
      );
  Future<Map<String, dynamic>> act(String id, String action) =>
      request('/users/${Uri.encodeComponent(id)}/$action', method: 'POST');
  Future<Map<String, dynamic>> report(String id, String reason) => request(
    '/users/${Uri.encodeComponent(id)}/report',
    method: 'POST',
    data: {'reason': reason},
  );
  Future<String> saveHandle(
    String username, {
    CancelToken? cancelToken,
  }) async =>
      (await _request(
            '/handle',
            method: 'PUT',
            data: {'username': username},
            cancelToken: cancelToken,
          ))['username']
          as String;
}
