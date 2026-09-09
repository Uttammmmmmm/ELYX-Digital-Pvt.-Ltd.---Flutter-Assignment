/// Route-level wrapper for the users list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/network_info.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import 'users_list_view.dart';

/// Supplies the [UsersBloc] and the connectivity stream, then gets out of the
/// way.
///
/// THE ONLY PLACE `sl<T>()` IS CALLED in the users feature. Everything below
/// receives what it needs through a constructor or `context.read`, which is
/// what keeps the view testable without booting the service locator and stops
/// the locator becoming a hidden dependency of every widget.
class UsersListPage extends StatelessWidget {
  const UsersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UsersBloc>(
      create: (_) => sl<UsersBloc>()..add(const UsersFetched()),
      child: UsersListView(
        connectivity: sl<NetworkInfo>().onConnectivityChanged,
      ),
    );
  }
}
