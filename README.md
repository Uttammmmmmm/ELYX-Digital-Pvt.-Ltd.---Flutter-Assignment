# GitHub Users

A paginated GitHub users browser built with Clean Architecture, `flutter_bloc`,
Dio and Hive — with offline caching, client-side search, and honest handling of
the places where the assignment brief and the GitHub API disagree.

## Screenshots

| List (light) | List (dark) | Detail | Search |
|---|---|---|---|
| _screenshot_ | _screenshot_ | _screenshot_ | _screenshot_ |

| Offline banner | Rate limit | Error + retry | Tablet grid |
|---|---|---|---|
| _screenshot_ | _screenshot_ | _screenshot_ | _screenshot_ |

---

## Setup

```bash
git clone <repo-url>
cd elyx_digital_assignment

flutter pub get

# Regenerates Hive TypeAdapters and Mockito mocks.
# Generated files ARE committed, so this is only needed after changing a
# @HiveType model or a @GenerateMocks list.
dart run build_runner build

flutter run
```

Requires Flutter **3.41+** / Dart **3.11+**.

### Optional: a GitHub token

**The app runs without any token.** Unauthenticated, GitHub allows **60
requests per hour per IP** — roughly six pages of users plus a handful of
profile views. The app handles exhaustion gracefully (see the rate-limit row in
the scenarios table), but for comfortable use, supply a token to raise the
limit to **5,000 requests/hour**:

```bash
# Preferred — keeps the token out of your shell history.
cp env.example.json env.json     # paste your token into it
flutter run --dart-define-from-file=env.json

# Or inline
flutter run --dart-define=GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

`env.json` is git-ignored. In VS Code, pick the **"Run (with GitHub token,
5000 req/hour)"** launch configuration.

A **fine-grained token with no scopes at all** is sufficient — the app reads
only public data. Do not grant `repo` or `user`.

> **Security note.** `--dart-define` values are compiled into the binary and
> are recoverable from a release build. That is acceptable for a read-only
> public-data token; it is not a mechanism for real secrets. When no token is
> supplied the `Authorization` header is omitted **entirely** rather than sent
> empty, because GitHub treats a malformed Bearer credential as a hard 401 —
> worse than being unauthenticated. The Dio logging interceptor is configured
> never to print request headers.

---

## Architecture

Feature-first Clean Architecture. The dependency arrow points **inward**: the
domain layer depends on nothing.

```
┌──────────────────────────────────────────────┐
│  presentation   pages · widgets · blocs      │
│                 depends on: domain           │
├──────────────────────────────────────────────┤
│  domain         entities · repository        │──► depends on NOTHING
│                 contracts · use cases        │
├──────────────────────────────────────────────┤
│  data           models · data sources ·      │
│                 repository impl              │
│                 depends on: domain           │
└──────────────────────────────────────────────┘
        core/  ── shared infrastructure, no feature knowledge
```

### Why Clean Architecture here

The layer that *consumes* a capability declares it, so the domain states its
need in its own vocabulary (`Either<Failure, UserDetail>`) rather than
accepting whatever shape HTTP hands back. The implementation lives in `data`
because *how* users arrive — Dio, Hive, a cursor buried in a `Link` header — is
exactly the detail business rules must never depend on. That inversion is what
lets GitHub be swapped for another backend, or Hive for Isar, without touching
a domain file, and lets every use case be unit-tested against a stub with no
server and no mocking framework.

`package:dio` is confined to `core/network` plus `core/error/error_mapper.dart`.
That boundary is not a convention — `test/architecture/dio_boundary_test.dart`
fails the build if it leaks.

### Folder tree

```
lib/
├── main.dart                     bootstrap: Hive → DI → runApp, error zones
├── app.dart                      MaterialApp, themes, onGenerateRoute
├── hive_registrar.g.dart         generated adapter registration
│
├── core/
│   ├── bloc/                     shared event transformers
│   ├── constants/                api + cache constants
│   ├── di/                       injection_container.dart
│   ├── error/                    exceptions, failures, error_mapper
│   ├── models/                   —
│   ├── network/                  dio_client, interceptors, link parser,
│   │                             rate-limit tracker, network_info
│   ├── routing/                  app_routes, route_generator, not_found_page
│   ├── storage/                  hive_initializer, hive_type_ids
│   ├── theme/                    app_theme, app_spacing
│   ├── usecase/                  UseCase / SyncUseCase contracts
│   └── utils/                    duration_format, responsive
│
└── features/users/
    ├── domain/
    │   ├── entities/             UserSummary, UserDetail, PaginatedUsers
    │   ├── repositories/         UserRepository (abstract)
    │   └── usecases/             GetUsers, GetUserDetail, FilterUsers
    ├── data/
    │   ├── models/               *Model + generated *.g.dart adapters
    │   ├── datasources/          remote (Dio) + local (Hive)
    │   └── repositories/         UserRepositoryImpl — the cache policy
    └── presentation/
        ├── bloc/                 UsersBloc, UserDetailBloc
        ├── formatters/           user_display
        ├── pages/                list page/view, detail page
        └── widgets/              tiles, cards, and one file per UI state
```

---

## State management

**`flutter_bloc`**, because this screen's behaviour is a sequence of discrete
events with non-trivial concurrency rules — and Bloc's event transformers
express those rules declaratively instead of as hand-rolled flags:

```dart
on<UsersNextPageRequested>(_onNextPage, transformer: dropWhileBusy());
on<UsersSearchQueryChanged>(_onSearch, transformer: debounceRestartable(300ms));
```

`droppable()` is what makes a fast scroll fling issue **one** request instead of
three — a correctness property against a 60/hour budget, not an optimisation.
A boolean `_isLoading` guard is forgettable on an early return or a throw; a
transformer cannot be.

### Why a single state class, not a sealed union

The mid-scroll error decides it. With `UsersLoadingMore` / `UsersFailure` as
separate variants, a failure interrupting page 5 either **discards the 40 users
already on screen** or forces every variant to carry them anyway — at which
point the union is a flat class with extra ceremony. A status field keeps
*"40 users loaded AND the last page failed"* directly representable, which is
exactly what an inline footer error needs.

The detail screen *does* use a status enum with a seed object, because there the
states genuinely are mutually exclusive.

---

## Design decisions

These are the five places where the obvious implementation is wrong.

### 1. Pagination is cursor-based (`since`), not `?page=`

`GET /users` does **not** support `?page=`. The parameter is accepted and
silently ignored — it returns the first page every time, which fails as an
infinite list that repeats itself forever rather than as an error.

The real mechanism is `?since={user_id}`, a **cursor**: "give me users after
this id". Consequences that shape the whole app:

- There is no "page 7". Pages are only reachable by walking forward from the
  start, which is why the UI is infinite scroll and not a numbered pager.
- A refresh cannot re-request "the current page" — it can only restart the walk.
- The next cursor comes from the `Link` header, not the body:
  ```
  Link: <https://api.github.com/users?per_page=10&since=57>; rel="next", ...
  ```
  Parsing that is authoritative for "is there a next page", and saves one whole
  request per exhausted list versus discovering the end via an empty array.
- The cache is keyed by cursor (`page_first`, `page_47`), never by index. "Page
  3" is not a stable identity — it means "whatever the third hop landed on",
  which changes the moment a user is created or deleted upstream.

Above the data layer the cursor is **opaque**: the Bloc stores it and hands it
back untouched, so a backend using string tokens would need no change outside
one model.

### 2. Two entities: `UserSummary` and `UserDetail`

The list endpoint returns exactly six fields — `login`, `id`, `avatar_url`,
`html_url`, `type`, `site_admin`. It has **no name and no email**.

One shared entity with `String? name` would make the detail screen unable to
distinguish *"not fetched yet"* from *"GitHub returned null"* — two situations
that need different UI (a skeleton versus a fallback label). Two types make the
wrong state unrepresentable rather than relying on a convention.

Fetching the missing fields is not an option either: names live behind
`GET /users/{login}`, **one request per user**. Prefetching them across a page
would spend the entire hourly budget in six pages.

### 3. The phone field

The assignment asks the detail screen to show a phone number. **The GitHub REST
API does not expose one.** Not a nullable field that happens to be empty, and
not an endpoint I overlooked — there is no phone concept anywhere in the user
resource, at any scope, with or without authentication.

The detail screen **always renders a Phone row**, styled as unavailable —
muted, italic, non-interactive — reading *"Not provided by the GitHub API"*. It
is never hidden, because hiding it would make the gap invisible and leave a
reviewer unable to tell "the API has no phone number" from "the candidate
forgot the phone number".

Equally deliberately, the app does **not** generate a placeholder number, not
even a deterministic one derived from the user id. A fabricated value that looks
like a phone number is indistinguishable from real data to anyone reading the
screen. To make that impossible rather than merely discouraged, there is no
`phone` field on the `UserDetail` entity or on any model — **the row has nothing
to read from, by construction.**

The same reasoning governs `email`, which the API *does* have but leaves null
for most accounts: it renders as *"Not publicly listed"* rather than blank.

### 4. Search is client-side

`/users` supports no name or login filter of any kind. There is a separate
`/search/users` endpoint, but it is a different resource with its own stricter
rate limit (10/min unauthenticated) and its own pagination model — using it
would mean two incompatible list implementations.

So search filters the users already paged in, by `login`. Two consequences
handled explicitly:

- **`contains()`, never `RegExp`.** A user typing `a|b`, `(`, or a trailing `\`
  would either throw a `FormatException` at pattern-compile time or silently
  succeed as a pattern and return wrong matches. `contains()` has no pattern
  semantics, so every character is a literal by construction rather than by
  vigilance. All 13 metacharacters have tests.
- **"No results" never implies the user does not exist.** The empty state says
  *"GitHub has no username filter, so only the 40 users loaded so far were
  searched"* and offers **Load more** — because client-side filtering cannot
  know whether the term exists on GitHub.

### 5. Cache-then-network with stale fallback

One class decides where data comes from — `UserRepositoryImpl` — in this order:

| # | Condition | Behaviour |
|---|---|---|
| 1 | `forceRefresh` | Go remote; clear stored batches first so a refresh cannot be served the data it is replacing |
| 2 | Fresh cache (within TTL) | Serve it. **Zero requests.** |
| 3 | Offline | Serve cache at **any** age; fail only if there is none |
| 4 | Stale cache + online | Go remote |
| 5 | Remote failed | Fall back to stale cache; surface the failure only if nothing is cached |
| 6 | Remote succeeded | Cache, then return |
| 7 | Empty batch | `hasReachedEnd: true` — a **success**, not a failure |

TTLs: **15 minutes** for list batches (a moving window over a growing dataset),
**6 hours** for profiles (near-static, and each refetch costs a request).

Step 5 is what makes a spent rate limit survivable: stale data plus a banner
beats an error screen. Step 7 matters because reaching the end of GitHub's user
list is not an outage.

---

## Problem scenarios

| Scenario | How it is handled | Where |
|---|---|---|
| Infinite scroll loads the next page | Cursor from the `Link` header; `droppable()` collapses duplicate scroll events into one request | `users_bloc.dart`, `link_header_parser.dart` |
| Short first page on a tall screen | Post-frame viewport fill requests another page when `maxScrollExtent == 0`, guarded so it cannot loop | `users_list_view.dart` `_fillViewport` |
| Scrolling costs nothing when data is fresh | Branch 2 — fresh cache hit, no network call | `user_repository_impl.dart` |
| Pull-to-refresh | `forceRefresh: true`, cursor reset, list replaced only after the new page arrives — never blanked mid-refresh | `users_bloc.dart` `_onRefreshed` |
| Refresh while the network is flaky | Branch 1 → 5: falls back to stale cache rather than an error screen | `user_repository_impl.dart` |
| App opened offline | Branch 3 — cached users at any age; offline banner states the data may be stale | `user_repository_impl.dart`, `offline_banner.dart` |
| Connection drops mid-scroll | Inline footer error; loaded rows stay on screen; Retry resumes from the same cursor | `pagination_footer.dart`, `users_bloc.dart` |
| Rate limit exhausted (60/hr) | Distinct `RateLimitFailure` carrying `resetAt`; countdown UI with **Retry disabled** until the window reopens | `rate_limit_interceptor.dart`, `rate_limit_view.dart` |
| Reaching the end of the user list | `hasReachedEnd`, "You've reached the end"; the empty batch is cached so the end is not rediscovered | `paginated_users.dart` |
| Server 5xx / timeout | Mapped to typed failures; stale cache preferred, error only if nothing cached | `error_mapper.dart` |
| Search with no matches | `NoSearchResultsView`, visually distinct from "no users exist", with Clear + Load more | `no_search_results_view.dart` |
| Deleted account (404) on detail | `NotFoundFailure` — the **one** failure that must not fall back to cache, since the cached copy is now wrong | `user_repository_impl.dart` |
| Malformed record in a batch | Coercing parsers + `whereType`; one bad record never discards the batch | `user_summary_model.dart` |
| Back navigation / memory leaks | Blocs are `registerFactory`; `BlocProvider` closes on pop; `isClosed` checked after every await; controllers disposed | `injection_container.dart`, `users_bloc.dart`, `users_list_view.dart` |
| Rotation | Bloc state survives automatically; `PageStorageKey` preserves scroll across the list↔grid swap | `users_list_view.dart` |
| Corrupted cache on launch | Box is deleted and recreated rather than crashing before `runApp` | `hive_initializer.dart` |
| Unknown / malformed route | Type-checked arguments; resolves to a 404 page instead of throwing | `route_generator.dart` |

---

## Testing

**214 tests, 83.7% line coverage.**

```bash
flutter test
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

Mocks are generated by Mockito from a single declaration file:

```dart
// test/helpers/mocks.dart
@GenerateMocks(<Type>[
  UserRemoteDataSource,
  UserLocalDataSource,
  NetworkInfo,
  UserRepository,
])
void main() {}
```

```bash
dart run build_runner build
```

| Layer | Coverage | What is covered |
|---|---|---|
| domain | 90.6% | Search edge cases (all 13 regex metacharacters, whitespace, unicode), validation guards, cursor derivation |
| presentation | 87.0% | Bloc concurrency and state transitions; every UI state widget by Key |
| data | 80.4% | All 7 repository branches, defensive JSON parsing, Hive round trips through real boxes |
| core | 79.4% | `Link` header parsing, rate-limit classification, route generation, DI graph |

Notable tests: an **architecture test** failing the build if `package:dio`
leaks past `core/network`; an **end-to-end network test** faking only the
socket, so the real interceptor chain, error mapper and Link parser all
execute; **Hive tests against real boxes** in a temp directory.

---

## Known limitations

Stated plainly, in rough order of how much they would matter to a reviewer.

1. **Limited real-device testing.** The app has been run against the live
   GitHub API — the list, detail requests and rate-limit handling all work
   against real responses — but only briefly, on one device. Long sessions,
   iOS, and tablets are unverified.
2. **No master-detail split view on tablets.** The grid uses the extra width,
   but there is no two-pane layout. Split-view navigation interacts with the
   back button and deep links in ways widget tests at a fixed surface size will
   not catch, so it was left out rather than shipped unverified.
3. **`hive_generator` is unusable on this SDK** (it pins `analyzer <7.0.0`,
   which cannot coexist with `bloc_test`), so the project uses **`hive_ce`** —
   the maintained fork, same API and same `@HiveType` annotations.
4. **Search matches `login` only**, not display names. Names live behind
   per-user detail requests, and prefetching them would exhaust the hourly
   budget. Searching names for the arbitrary subset whose profile happened to
   be cached would produce results users cannot predict.
5. **Blog and profile links copy to the clipboard** rather than opening a
   browser. `url_launcher` needs an Android `<queries>` manifest entry to work
   on API 30+, which cannot be verified without a device.
6. **No localisation.** Copy is hardcoded English; `formatClockTime` does not
   respect a 24-hour locale preference.
7. **The launcher icon is a generated placeholder**, not a designed mark.
8. **Widget tests never close their blocs.** `Bloc.close()` never completes
   inside `testWidgets` (its clock is faked); it completes normally in plain
   `test()` and `bloc_test`. Documented at the top of each affected file.
