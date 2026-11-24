import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'subscription_service.dart';

/// No SDK/local flag authorizes benefits. Every result belongs to one sign-in.
class PremiumService {
  PremiumService(this.api, this.storage);
  final ApiService api;
  final StorageService storage;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Sign in to use Premium.', statusCode: 401);
    }
    var changed = false;
    void accountChanged() => changed = true;
    storage.addListener(accountChanged);
    try {
      final response = await api.dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
          // This caller tracks sign-in events, including A→out→A with the
          // same credential. The generic token-only interceptor cannot do so.
          extra: {'callerHandlesUnauthorized': true},
        ),
      );
      if (changed || await storage.getToken() != token) {
        throw const ApiException(
          'Your account changed. Please try again.',
          statusCode: 409,
        );
      }
      if (response.data == null) {
        throw const FormatException('Missing Premium response');
      }
      return response.data!;
    } on DioException catch (error) {
      if (changed || await storage.getToken() != token) {
        throw const ApiException(
          'Your account changed. Please try again.',
          statusCode: 409,
        );
      }
      final body = error.response?.data;
      if (error.response?.statusCode == 401) await storage.clearToken();
      throw ApiException(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Couldn’t load Premium. Please try again.',
        statusCode: error.response?.statusCode,
      );
    } finally {
      storage.removeListener(accountChanged);
    }
  }

  Map<String, dynamic> _validated(Map<String, dynamic> data) {
    final remaining = data['remaining'];
    if (data['userId'] is! String ||
        data['active'] is! bool ||
        remaining is! Map ||
        remaining['full'] is! int ||
        remaining['initial'] is! int ||
        (remaining['full'] as int) < 0 ||
        (remaining['full'] as int) > 2 ||
        (remaining['initial'] as int) < 0 ||
        (remaining['initial'] as int) > 5) {
      throw const FormatException('Incomplete Premium status');
    }
    return data;
  }

  Future<Map<String, dynamic>> status() async =>
      _validated(await request('/api/premium'));
  Future<Map<String, dynamic>> vote(String id) async => _validated(
    await request('/api/premium/votes/${Uri.encodeComponent(id)}'),
  );
  Future<Map<String, dynamic>> reveal(String id, String kind) async =>
      _validated(
        await request(
          '/api/premium/votes/${Uri.encodeComponent(id)}/reveal',
          method: 'POST',
          data: {'kind': kind},
        ),
      );

  Future<String> preparePurchase() async {
    // Resolve the backend-owned billing alias before Apple purchase/restore.
    final result = await request(
      '/api/notifications/activity',
      method: 'POST',
      data: {'timezone': 'UTC', 'locale': 'en'},
    );
    final id = result['billingId'];
    if (id is! String ||
        !RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
        ).hasMatch(id)) {
      throw const ApiException(
        'Couldn’t link billing to your account. Please try again.',
      );
    }
    await SubscriptionService.instance.prepareAccountBilling(id);
    return id;
  }
}
