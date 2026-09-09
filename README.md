# Users

A paginated users browser built with Clean Architecture, `flutter_bloc`, Dio
and Hive — with offline caching, client-side search, and explicit handling of
the places where the assignment brief and the APIs disagree.

## Screenshots

| List (light) | List (dark) | Detail | Search |
|---|---|---|---|
| _screenshot_ | _screenshot_ | _screenshot_ | _screenshot_ |

| Offline banner | Error + retry | No results | Tablet grid |
|---|---|---|---|
| _screenshot_ | _screenshot_ | _screenshot_ | _screenshot_ |

---

## Setup

```bash
git clone <repo-url>
cd elyx_digital_assignment

flutter pub get

# Regenerates Hive TypeAdapters and Mockito mocks. Generated files ARE
# committed, so this is only needed after changing a @HiveType model or a
# @GenerateMocks list.
dart run build_runner build

flutter run
```

Requires Flutter **3.41+** / Dart **3.11+**.

### The API key

The default source, `reqres.in`, has required an API key since 2025. Requests
without it return `401 {"error":"missing_api_key"}`. The free public key is
compiled in as the default, so **`flutter run` works with no configuration**.
To supply a different one:

```bash
flutter run --dart-define=REQRES_API_KEY=your-key
```

### Switching data source

```bash
flutter run                                   # reqres.in  (default)
flutter run --dart-define=API_SOURCE=github   # api.github.com
```

GitHub is unauthenticated by default (60 requests/hour per IP). To raise that
to 5,000:

```bash
flutter run --dart-define=API_SOURCE=github --dart-define=GITHUB_TOKEN=ghp_xxx
```

> `--dart-define` values are compiled into the binary and are recoverable from
> a release build. Fine for a read-only public-data token; not a mechanism for
> real secrets. `env.json` is git-ignored; `env.example.json` is the template.

---

## DESIGN DECISIONS

### 1. Which API? Both — the brief contradicts itself

The brief's **prose** says:

> *Networking: Use Dio or http package to fetch data from `https://reqres.in/api/users`*

Its **hyperlinks**, however, resolve to `api.github.com`. These are not
interchangeable: they disagree about pagination, about what a list response
contains, and about authentication.

Rather than guess which was intended, **both are implemented behind one
interface** and selected at build time, with **reqres as the default** because
that is what the prose specifies:

```dart
abstract interface class UsersApi {
  String get baseUrl;
  Map<String, String> get headers;
  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage});
  Future<UserDetail> fetchUserDetail(String id);
}
```

| | reqres.in (default) | api.github.com |
|---|---|---|
| Pagination | `?page=N&per_page=10`, `total_pages` in the body | `?since={id}` cursor, next page in the `Link` header |
| List contains | `first_name`, `last_name`, `email`, `avatar` | `login`, `avatar_url` — **no name, no email** |
| Detail shape | `{"data": {…}}` envelope | flat object |
| Auth | **required** `x-api-key` header | optional Bearer token |
| Dataset | 12 users, 2 pages | millions |

Everything above the data layer is unaware of which is active. The cursor is
`Object?` and opaque — a page number for one, a user id for the other — and the
Bloc stores it and hands it back without inspecting it. This is the one place
the architecture genuinely earns its keep: supporting a second, structurally
incompatible backend changed the data layer and nothing else.

**reqres returns 12 users in total.** Infinite scroll therefore terminates
after two pages and shows *"You've reached the end"*. That is the dataset, not
a defect — switch to `API_SOURCE=github` to scroll indefinitely.

### 2. Two entity shapes, one neutral type

GitHub's list response has no name and no email; reqres's does. A single
entity with everything non-null would be a lie for one source, and two parallel
entity trees would double every layer above.

`UserSummary` holds the union as nullables and exposes `displayName`, which
falls back **name → handle → id** and is therefore never blank. `UserDetail`
composes it and marks every GitHub-only field (`bio`, `publicRepos`, …)
nullable, with `hasStats` letting the UI hide the counters row entirely rather
than render three zeros — which would be fabricated data.

### 3. The phone field

The assignment asks the detail screen to show a phone number. **Neither API
has one.** reqres returns `id`, `email`, `first_name`, `last_name`, `avatar`;
GitHub has no phone concept at any scope, authenticated or not.

The screen **always renders a Phone row**, styled as unavailable — muted,
italic, non-interactive — reading *"Not provided by the API"*. It is never
hidden, because hiding it would make the gap invisible and leave a reviewer
unable to tell "the API has no phone number" from "the candidate forgot it".

The app does **not** generate a placeholder, not even a deterministic one. A
fabricated value that looks like a phone number is indistinguishable from real
data on screen. To make that impossible rather than merely discouraged, there
is **no `phone` field on any entity or model** — the row has nothing to read
from, by construction, and a test asserts the entity's field count to catch
anyone adding one.

The same reasoning governs `email` when the source omits it: *"Not publicly
listed"*, never blank.

### 4. Search is client-side

Neither source offers a server-side name filter. So search filters what has
already been paged in, matching `displayName` **and** `email`.

Two consequences handled explicitly:

- **`contains()`, never `RegExp`.** A user typing `a|b`, `(`, or a trailing
  `\` would either throw a `FormatException` at compile time or silently
  succeed as a pattern and return wrong matches. `contains()` has no pattern
  semantics, so every character is literal by construction rather than by
  vigilance. All 13 metacharacters have tests.
- **"No results" never implies the user does not exist.** The empty state says
  *"This API has no search endpoint, so only the 12 users loaded so far were
  searched"* and offers **Load more** — because client-side filtering cannot
  know what exists server-side.

### 5. Cache-then-network with stale fallback

One class decides where data comes from, in this order:

| # | Condition | Behaviour |
|---|---|---|
| 1 | `forceRefresh` | **Invalidate every cached batch**, then go remote |
| 2 | Fresh cache (within TTL) | Serve it. **Zero requests.** |
| 3 | Offline | Serve cache at **any** age; fail only if there is none |
| 4 | Stale cache + online | Go remote |
| 5 | Remote failed | Fall back to stale cache; surface the failure only if nothing is cached |
| 6 | Remote succeeded | Cache, then return |
| 7 | Empty batch | `hasReachedEnd: true` — a **success**, not a failure |

TTLs: **15 minutes** for list batches, **6 hours** for profiles. The profile
cache is bounded — expired entries are evicted on write, then oldest-by-write
above 200 — because a TTL controls freshness, not size.

Step 1's invalidation is not optional: overwriting only the requested batch
leaves later pages holding pre-refresh data, so within the TTL the user scrolls
straight back into the rows they just pulled to replace.

On cold start the list is seeded from **everything ever cached**, so offline
search covers previous sessions rather than only the current one.

---

## Architecture

```
┌──────────────────────────────────────────────┐
│  presentation   pages · widgets · blocs      │
│                 depends on: domain           │
├──────────────────────────────────────────────┤
│  domain         entities · repository        │──► depends on NOTHING
│                 contracts · use cases        │
├──────────────────────────────────────────────┤
│  data           UsersApi impls · Hive models │
│                 repository impl              │
│                 depends on: domain           │
└──────────────────────────────────────────────┘
        core/  ── shared infrastructure, no feature knowledge
```

`package:dio` is confined to `core/network` plus `core/error/error_mapper.dart`
— enforced by `test/architecture/dio_boundary_test.dart`, which fails the build
if it leaks.

**State management** is `flutter_bloc`, chosen because this screen's behaviour
is a sequence of discrete events with real concurrency rules, and Bloc's event
transformers express them declaratively: `droppable()` makes a fast scroll
fling issue **one** request instead of three, and `restartable() + 300ms`
debounces search. A boolean `_isLoading` guard is forgettable on an early
return; a transformer is not.

The list uses **one flat state class with a status enum**, not a sealed union.
The deciding case is a failure mid-scroll: a union either discards the 40 users
already on screen or copies them into every variant anyway. A status field
keeps *"40 loaded AND the last page failed"* representable, which is what an
inline footer error needs.

---

## Problem scenarios

| Scenario | How it is handled | Where |
|---|---|---|
| Slow API response | 10s connect / 15s receive timeouts → `TimeoutFailure`; skeleton rows, not a bare spinner | `dio_client.dart`, `loading_view.dart` |
| No internet + retry | Cache served at any age; `NetworkFailure` + Retry when empty; persistent offline banner | `user_repository_impl.dart`, `offline_banner.dart` |
| Empty API response | `hasReachedEnd: true` — a success; friendly "No users available" | `paginated_users.dart`, `empty_view.dart` |
| Search special characters | `contains()`, never `RegExp`; trim + whitespace collapse; 13 metacharacter tests | `filter_users.dart` |
| Back navigation / leaks | Blocs are factories; `BlocProvider` closes on pop; `isClosed` after every await; controllers disposed | `injection_container.dart`, `users_bloc.dart`, `users_list_view.dart` |
| UI responsiveness | M3 window size classes; list ↔ 2/3-column grid; `PageStorageKey` preserves scroll on rotation; text scale to 2.0 | `responsive.dart`, `users_list_view.dart` |
| Stale cached data | TTLs + `forceRefresh` invalidation; bounded profile cache; schema-version guard drops incompatible boxes | `user_repository_impl.dart`, `hive_initializer.dart` |
| Infinite scroll stalls on tall screens | Post-frame viewport fill, guarded so it cannot loop | `users_list_view.dart` |
| Rate limiting / 429 | Distinct failure carrying `resetAt`; countdown with Retry **disabled**; no further requests until reset | `rate_limit_interceptor.dart`, `users_state.dart` |
| Deleted account (404) | `NotFoundFailure` — the one failure that must **not** fall back to cache | `user_repository_impl.dart` |
| Malformed record | Coercing parsers + `whereType`; one bad record never discards the batch | `reqres_users_api.dart` |
| Corrupt cache on launch | Box deleted and recreated rather than crashing before `runApp` | `hive_initializer.dart` |
| Unknown route | Type-checked arguments → 404 page, not an exception | `route_generator.dart` |

---

## Testing

```bash
flutter test
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

Mocks come from one declaration file:

```dart
@GenerateMocks(<Type>[UsersApi, UserLocalDataSource, NetworkInfo, UserRepository])
void main() {}
```

Notable coverage: an **architecture test** failing the build if Dio leaks past
`core/network`; **end-to-end API tests** faking only the socket, so the real
interceptor chain, error mapper and Link parser execute; **Hive tests against
real boxes** in a temp directory; and **regression tests** for three bugs found
on a device — a retry storm, a footer overflow, and a full-screen state
overflowing a short viewport — each verified to fail against the pre-fix code.

---

## Known limitations

1. **Only reqres has been exercised end to end on a device.** The GitHub source
   was verified against the live API during development; the reqres source is
   covered by tests against a faked socket, not a real device run.
2. **No master-detail split view on tablets.** The grid uses the extra width,
   but there is no two-pane layout. Split-view navigation interacts with the
   back button and deep links in ways widget tests at a fixed surface size will
   not catch, so it was left out rather than shipped unverified.
3. **`hive_generator` is unusable on this SDK** (it pins `analyzer <7.0.0`,
   which cannot coexist with `bloc_test`), so the project uses **`hive_ce`** —
   the maintained fork, same API and same `@HiveType` annotations.
4. **Diacritics are not folded in search.** `"jose"` will not match `"José"`.
   Dart ships no Unicode normaliser in core. This is a real limitation now that
   search covers free-form display names, and would be the first thing I fixed
   on a non-Anglophone dataset.
5. **Links copy to the clipboard** rather than opening a browser.
   `url_launcher` needs an Android `<queries>` manifest entry to work on API
   30+, which cannot be verified without a device.
6. **No localisation.** Copy is centralised in `UsersStrings` — which is the
   seam an ARB-based setup would replace — but is hardcoded English, and
   `formatClockTime` does not respect a 24-hour locale preference.
7. **The launcher icon is a generated placeholder**, not a designed mark.
8. **Widget tests never close their blocs.** `Bloc.close()` never completes
   inside `testWidgets` (its clock is faked); it completes normally in plain
   `test()` and `bloc_test`. Documented at the top of each affected file.
