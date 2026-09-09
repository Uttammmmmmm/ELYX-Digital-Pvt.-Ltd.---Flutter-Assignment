/// Every user-facing string in the users feature.
library;

/// Centralised copy.
///
/// Collected here for two reasons. Practically, the strings were scattered
/// across nine widgets and several named a specific API host -- which became
/// wrong the moment a second source was supported. Structurally, this is the
/// seam localisation would replace: swapping these constants for generated
/// ARB lookups touches one file rather than every widget.
///
/// Copy is deliberately SOURCE-NEUTRAL. Nothing here names reqres.in or
/// GitHub, because the active source is a build flag and the user did not
/// choose it.
abstract final class UsersStrings {
  // -- List screen ---------------------------------------------------------
  static const String listTitle = 'Users';
  static const String searchHint = 'Search loaded users';
  static const String clearSearchTooltip = 'Clear search';

  // -- Empty ---------------------------------------------------------------
  static const String emptyTitle = 'No users available';
  static const String emptyBody = 'The API returned no users for this request.';
  static const String refresh = 'Refresh';

  // -- No search results ---------------------------------------------------
  static String noMatchesTitle(String query) => 'No matches for "$query"';

  /// Must never imply the user does not exist -- client-side filtering cannot
  /// know that. It says exactly what was searched.
  static String noMatchesBody(int loadedCount) =>
      'This API has no search endpoint, so only the $loadedCount users '
      'loaded so far were searched.';
  static const String clearSearch = 'Clear search';
  static const String loadMoreUsers = 'Load more users';

  // -- Errors --------------------------------------------------------------
  static const String tryAgain = 'Try again';
  static const String retry = 'Retry';

  // -- Rate limit ----------------------------------------------------------
  static const String rateLimitTitle = 'Rate limit reached';
  static const String rateLimitBody =
      'The API is temporarily refusing further requests.';
  static const String rateLimitReady = 'You can try again now.';
  static String rateLimitResetsAt(String clockTime, String countdown) =>
      'Limit resets at $clockTime ($countdown)';
  static const String rateLimitTokenTip =
      'Tip: supply an API token at build time to raise the request limit.';

  // -- Offline -------------------------------------------------------------
  static const String offlineBanner =
      "You're offline — showing saved users, which may be out of date.";

  // -- Pagination footer ---------------------------------------------------
  static const String couldNotLoadMore = "Couldn't load more";
  static const String endOfList = "You've reached the end";

  // -- Detail screen -------------------------------------------------------
  static const String labelName = 'Name';
  static const String labelEmail = 'Email';
  static const String labelPhone = 'Phone';
  static const String labelCompany = 'Company';
  static const String labelLocation = 'Location';
  static const String labelWebsite = 'Website';
  static const String labelMemberSince = 'Member since';
  static const String labelProfile = 'Profile';

  static const String emailUnavailable = 'Not publicly listed';

  /// THE PHONE FIELD. The assignment asks for a phone number; NEITHER
  /// supported API has one. reqres returns id, email, first_name, last_name
  /// and avatar; GitHub has no phone concept at any scope. So the row always
  /// renders, marked unavailable, with source-neutral copy -- and the app
  /// never fabricates a number, not even a deterministic one, because a
  /// plausible-looking value is indistinguishable from real data on screen.
  /// There is no `phone` field on any entity to read from, by construction.
  static const String phoneUnavailable = 'Not provided by the API';

  static String copied(String label) => '$label copied';

  // -- Split view ----------------------------------------------------------
  /// Shown in the detail pane of a two-pane layout before anything is picked.
  static const String noSelectionTitle = 'No user selected';
  static const String noSelectionBody =
      'Pick someone from the list to see their profile here.';

  // -- Stats ---------------------------------------------------------------
  static const String statRepos = 'Repos';
  static const String statFollowers = 'Followers';
  static const String statFollowing = 'Following';

  /// Compact counts: `1.2k`, `23k`, `1.1m`.
  ///
  /// Follower counts run to six digits and would otherwise wrap the stat row.
  static String count(int value) {
    if (value < 1000) return '$value';
    if (value < 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value < 1000000) return '${(value / 1000).round()}k';
    return '${(value / 1000000).toStringAsFixed(1)}m';
  }
}
