library;

import 'package:flutter/foundation.dart';

import '../../../../../core/constants/api_constants.dart';
import 'reqres_users_api.dart';

@immutable
class ApiSourceConfig {
  const ApiSourceConfig({
    required this.name,
    required this.baseUrl,
    required this.headers,
  });

  final String name;

  final String baseUrl;

  final Map<String, String> headers;
}

enum ApiSource {
  reqres,

  github;

  static ApiSource fromName(String name) => switch (name.toLowerCase()) {
    'reqres' => ApiSource.reqres,
    _ => ApiSource.github,
  };

  ApiSourceConfig config({required String reqresApiKey}) => switch (this) {
    ApiSource.reqres => ApiSourceConfig(
      name: 'reqres.in',
      baseUrl: 'https://reqres.in/api',
      headers: <String, String>{
        'Accept': 'application/json',

        'x-api-key': reqresApiKey,
      },
    ),

    ApiSource.github => ApiSourceConfig(
      name: 'api.github.com',
      baseUrl: ApiConstants.baseUrl,
      headers: ApiConstants.defaultHeaders,
    ),
  };
}

const String kReqresApiKey = String.fromEnvironment(
  ReqresUsersApi.apiKeyDefine,
  defaultValue: ReqresUsersApi.defaultApiKey,
);
