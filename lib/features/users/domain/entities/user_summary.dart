library;

import 'package:equatable/equatable.dart';

class UserSummary extends Equatable {
  const UserSummary({
    required this.id,
    required this.detailId,
    required this.avatarUrl,
    this.handle,
    this.firstName,
    this.lastName,
    this.email,
    this.profileUrl,
    this.accountType,
  });

  final int id;

  final String detailId;

  final String avatarUrl;

  final String? handle;

  final String? firstName;

  final String? lastName;

  final String? email;

  final String? profileUrl;

  final String? accountType;

  String get displayName {
    final String full = <String?>[firstName, lastName]
        .whereType<String>()
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .join(' ');
    if (full.isNotEmpty) return full;

    final String? h = handle;
    if (h != null && h.trim().isNotEmpty) return h;

    return 'User $id';
  }

  bool get hasHandle => handle != null && handle!.trim().isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    id,
    detailId,
    avatarUrl,
    handle,
    firstName,
    lastName,
    email,
    profileUrl,
    accountType,
  ];
}
