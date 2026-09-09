library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../error/error_mapper.dart';
import 'api_response.dart';
import 'rate_limit_interceptor.dart';
import 'rate_limit_tracker.dart';

class DioClient {
  DioClient({
    required RateLimitTracker rateLimitTracker,
    required String baseUrl,
    required Map<String, String> headers,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: headers,
      responseType: ResponseType.json,
      validateStatus: (int? status) => status != null && status < 400,
    );

    _dio.interceptors.add(RateLimitInterceptor(rateLimitTracker));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
          logPrint: (Object o) => debugPrint('[dio] $o'),
        ),
      );
    }
  }

  final Dio _dio;

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final Response<T> response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
      );
      return ApiResponse<T>(
        data: response.data,
        statusCode: response.statusCode ?? 200,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
