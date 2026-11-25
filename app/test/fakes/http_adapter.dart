import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Exercises Dio's real interceptor/error pipeline without opening a socket.
class TestHttpAdapter implements HttpClientAdapter {
  TestHttpAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
