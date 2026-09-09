/// Mockito mock declarations for the users feature.
library;

import 'package:elyx_digital_assignment/core/network/network_info.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_remote_data_source.dart';
import 'package:elyx_digital_assignment/features/users/domain/repositories/user_repository.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks(<Type>[
  UserRemoteDataSource,
  UserLocalDataSource,
  NetworkInfo,
  // Blocs are tested against a mocked repository with REAL use cases, so the
  // bloc -> use case -> repository wiring is covered rather than stubbed out.
  UserRepository,
])
void main() {}
