/// The configured HTTP client. The only file that constructs Dio.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../error/error_mapper.dart';
import '../error/exceptions.dart';
import 'api_response.dart';
import 'rate_limit_interceptor.dart';
import 'rate_limit_tracker.dart';

/// Thin, Dio-backed HTTP client exposing an [ApiResponse] surface.
///
/// BOUNDARY: `package:dio` is imported here and in two sibling files only.
/// [get] returns [ApiResponse] rather than Dio's `Response` so callers still
/// get headers (needed for the `Link` cursor) without importing Dio. It also
/// throws [AppException], never [DioException], so data sources catch one
/// vocabulary. Enforced by `test/architecture/dio_boundary_test.dart`.
class DioClient {
  DioClient({required RateLimitTracker rateLimitTracker, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: ApiConstants.defaultHeaders,
      responseType: ResponseType.json,
      // Let every status reach the interceptors so a 403 keeps its rate-limit
      // headers instead of being thrown away as a generic bad response.
      validateStatus: (int? status) => status != null && status < 400,
    );

    // Order matters: the rate-limit interceptor must classify the error before
    // anything generic sees it.
    _dio.interceptors.add(RateLimitInterceptor(rateLimitTracker));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false, // never log headers: would print the token
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

  /// Issues a GET and returns body *and* headers.
  ///
  /// Throws an [AppException] subtype on any failure.
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
