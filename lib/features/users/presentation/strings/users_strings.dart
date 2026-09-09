library;

abstract final class UsersStrings {
  static const String listTitle = 'Users';
  static const String searchHint = 'Search loaded users';
  static const String clearSearchTooltip = 'Clear search';

  static const String emptyTitle = 'No users available';
  static const String emptyBody = 'The API returned no users for this request.';
  static const String refresh = 'Refresh';

  static String noMatchesTitle(String query) => 'No matches for "$query"';

  static String noMatchesBody(int loadedCount) =>
      'This API has no search endpoint, so only the $loadedCount users '
      'loaded so far were searched.';
  static const String clearSearch = 'Clear search';
  static const String loadMoreUsers = 'Load more users';

  static const String tryAgain = 'Try again';
  static const String retry = 'Retry';

  static const String rateLimitTitle = 'Rate limit reached';
  static const String rateLimitBody =
      'The API is temporarily refusing further requests.';
  static const String rateLimitReady = 'You can try again now.';
  static String rateLimitResetsAt(String clockTime, String countdown) =>
      'Limit resets at $clockTime ($countdown)';
  static const String rateLimitTokenTip =
      'Tip: supply an API token at build time to raise the request limit.';

  static const String offlineBanner =
      "You're offline — showing saved users, which may be out of date.";

  static const String couldNotLoadMore = "Couldn't load more";
  static const String endOfList = "You've reached the end";

  static const String labelName = 'Name';
  static const String labelEmail = 'Email';
  static const String labelPhone = 'Phone';
  static const String labelCompany = 'Company';
  static const String labelLocation = 'Location';
  static const String labelWebsite = 'Website';
  static const String labelMemberSince = 'Member since';
  static const String labelProfile = 'Profile';

  static const String emailUnavailable = 'Not publicly listed';

  static const String phoneUnavailable = 'Not provided by the API';

  static String copied(String label) => '$label copied';

  static const String statRepos = 'Repos';
  static const String statFollowers = 'Followers';
  static const String statFollowing = 'Following';

  static String count(int value) {
    if (value < 1000) return '$value';
    if (value < 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value < 1000000) return '${(value / 1000).round()}k';
    return '${(value / 1000000).toStringAsFixed(1)}m';
  }
}
