library;

import 'package:elyx_digital_assignment/core/network/network_info.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/api/users_api.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/domain/repositories/user_repository.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks(<Type>[
  UsersApi,
  UserLocalDataSource,
  NetworkInfo,

  UserRepository,
])
void main() {}
