library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/network_info.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import 'users_list_view.dart';

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
