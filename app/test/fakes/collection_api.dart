import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flyprox_app/services/api_service.dart';

class CollectionApiFake extends ApiService {
  CollectionApiFake(super.storage);
  int balance = 25000;
  bool failLoad = false;
  bool loseReply = false;
  int? rejectPurchase;
  Completer<void>? pending;
  final requests = <Map<String, dynamic>>[];
  final receipts = <String>{};
  final active = <Map<String, dynamic>>[];
  Map<String, dynamic> state() => {
    'userId': 'buyer',
    'balance': balance,
    'eligible': true,
    'catalog': [
      {
        'id': 'four_questions',
        'title': 'Show your name in 4 polls',
        'price': 5000,
      },
      {
        'id': 'sympathy',
        'title': 'Show your name in a crush question',
        'price': 20000,
      },
    ],
    'activeBoosts': active,
  };
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (failLoad) throw const ApiException('Offline');
    await pending?.future;
    return Response<T>(
      data: state() as T,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final body = Map<String, dynamic>.from(data as Map);
    requests.add(body);
    if (rejectPurchase != null) {
      throw ApiException('Not enough stars.', statusCode: rejectPurchase);
    }
    if (receipts.add(body['requestId'] as String)) {
      balance -= body['boostId'] == 'sympathy' ? 20000 : 5000;
      active.add({
        'boostId': body['boostId'],
        'remaining': body['boostId'] == 'sympathy' ? 1 : 4,
        'status': 'queued',
      });
    }
    await pending?.future;
    if (loseReply) throw const ApiException('Reply lost');
    return Response<T>(
      data: {...state(), 'purchaseId': 'receipt'} as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}
