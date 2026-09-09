/// A scripted [HttpClientAdapter] so the whole network stack can be tested
/// without a socket.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned HTTP reply.
class FakeReply {
  const FakeReply({
    required this.statusCode,
    this.body = '',
    this.headers = const <String, List<String>>{},
  });

  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
}

/// Returns a scripted [FakeReply] and records the request that asked for it.
///
/// Preferred over mocking `DioClient`: this exercises the real interceptor
/// chain, the real error mapper and the real Link parser, so the wiring
/// between them is covered rather than assumed.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this._reply);

  final FakeReply Function(RequestOptions options) _reply;

  /// Every request that reached the adapter, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final FakeReply reply = _reply(options);

    return ResponseBody.fromBytes(
      utf8.encode(reply.body),
      reply.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
