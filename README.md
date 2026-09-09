# GitHub Users Directory

A paginated GitHub users browser built with Clean Architecture, `flutter_bloc`,
Dio and Hive.

## Running

```bash
flutter pub get
dart run build_runner build   # generates test mocks
flutter run
```

That runs **unauthenticated**, which GitHub limits to **60 requests per hour
per IP**. At ten users per page that is roughly six pages plus a handful of
profile views before the app starts showing its rate-limit screen. It is
enough to demo, and the app handles exhaustion gracefully — but for real use,
supply a token.

## Supplying a GitHub token (`--dart-define`)

A personal access token raises the limit from 60 to **5,000 requests/hour**.
The app reads it at compile time:

```dart
static const String githubToken = String.fromEnvironment('GITHUB_TOKEN');
```

Create a token at <https://github.com/settings/tokens> — this app reads only
public data, so a **fine-grained token with no scopes at all** is sufficient.
Do not grant `repo` or `user`.

### Option 1 — a file (recommended)

`env.json` is git-ignored; `env.example.json` is the committed template.

```bash
cp env.example.json env.json     # then paste your token into it
flutter run --dart-define-from-file=env.json
```

Preferred because the token never enters your shell history.

### Option 2 — inline

```bash
flutter run --dart-define=GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

### Option 3 — VS Code

`.vscode/launch.json` ships three configurations; pick
**"Run (with GitHub token, 5000 req/hour)"** from the Run and Debug panel.
It reads `env.json`, so do Option 1 first.

### Other commands

The flag is not specific to `run` — it applies to any build:

```bash
flutter test  --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

### Security

`--dart-define` values are **compiled into the binary** and are recoverable
from a release build. That is acceptable for a read-only public-data token; it
is not a mechanism for real secrets. When no token is supplied the
`Authorization` header is omitted **entirely** rather than sent empty, because
GitHub treats a malformed Bearer credential as a hard 401 — worse than being
unauthenticated. The Dio logging interceptor is configured never to print
request headers, so the token cannot leak into logs.

## Testing

```bash
flutter test                                   # 153 tests
flutter analyze
```

The token wiring itself is covered by `test/core/constants/api_constants_test.dart`.
Because `String.fromEnvironment` resolves at compile time, one run can only
exercise one branch, so that file takes a second define stating what it should
expect:

```bash
# unauthenticated (the CI default)
flutter test test/core/constants

# authenticated — asserts the Bearer header is actually built
flutter test test/core/constants \
  --dart-define=GITHUB_TOKEN=ghp_xxx --dart-define=EXPECT_TOKEN=true
```

Without `EXPECT_TOKEN` the "Authorization is present if and only if a token was
defined" assertion would pass trivially when the flag is dropped — both sides
would be false. With it, a broken flag is a red test.

## Architecture

Feature-first Clean Architecture under `lib/features/users/`, with shared
infrastructure in `lib/core/`.

| Layer | Contents | Depends on |
|---|---|---|
| `domain/` | Entities, repository contract, use cases. Pure Dart + `equatable` + `dartz` — no Dio, Hive or Flutter. | nothing |
| `data/` | Models with JSON, remote/local data sources, repository implementation. | `domain` |
| `presentation/` | Blocs, pages, widgets. | `domain` |

`package:dio` is confined to `core/network` plus `core/error/error_mapper.dart`;
`test/architecture/dio_boundary_test.dart` fails the build if it leaks.

### API constraints this design works around

- **Cursor pagination.** `GET /users` pages via `since` (a user id), not
  `page`. There is no way to jump to an arbitrary page, which is why the UI is
  infinite scroll and a refresh restarts from the beginning.
- **The list endpoint has no name or email.** Hence two entities,
  `UserSummary` and `UserDetail`, rather than one with nullable fields.
- **GitHub has no phone number at all.** No entity has a `phone` field; the
  detail screen renders an explicit "Not provided by GitHub API" row, styled so
  it cannot be mistaken for data.
- **Rate limiting.** A 403/429 with `x-ratelimit-remaining: 0` becomes its own
  failure type carrying the reset time; the UI shows a live countdown and
  disables Retry until the quota returns.
- **No server-side search.** Filtering is client-side over loaded users, by
  login, using `contains()` rather than a regex so metacharacters are literals.
