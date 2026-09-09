/// The user as a LIST endpoint returns it.
library;

import 'package:equatable/equatable.dart';

/// A user in the list, in a shape neither API dictates.
///
/// SOURCE-NEUTRAL BY DESIGN. Two APIs feed this type and they disagree about
/// almost everything: reqres.in returns `first_name`/`last_name`/`email` and
/// paginates by page number; GitHub returns a `login` and no name at all, and
/// paginates by cursor. Rather than model one and bend the other, this holds
/// the union as nullables and exposes [displayName], which is the only thing
/// the UI actually needs. Neither implementation's shape leaks upward.
///
/// CONSTRAINT (b) still applies to the GitHub source: its list response has no
/// name and no email, so those fields arrive null and the detail request is
/// the only way to get them. On reqres they are present in the list.
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

  /// Numeric id. Stable across both sources and used for keys and Hero tags.
  final int id;

  /// The identifier `fetchUserDetail` takes for this user.
  ///
  /// GitHub keys its detail endpoint on `login`; reqres keys on the numeric
  /// id. Holding the key here rather than deriving it at the call site is
  /// what keeps the repository from having to know which API is active.
  final String detailId;

  /// Avatar image URL.
  final String avatarUrl;

  /// GitHub `login`. Null on reqres, which has no concept of a handle.
  final String? handle;

  /// Given name. Null on GitHub list responses.
  final String? firstName;

  /// Family name. Null on GitHub list responses.
  final String? lastName;

  /// Email. Null on GitHub list responses; present on reqres.
  final String? email;

  /// Public profile URL. Null on reqres.
  final String? profileUrl;

  /// `User` / `Organization` / `Bot`. Null on reqres, which has no types.
  final String? accountType;

  /// The name to show, falling back through what each source provides.
  ///
  /// Never empty: `id` is always present, so the final fallback always
  /// resolves. Order is deliberate -- a real name beats a handle, and a
  /// handle beats a bare id.
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

  /// True when this user came from a source that provides handles.
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
