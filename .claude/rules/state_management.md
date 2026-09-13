# State Management

## Migration Policy

> **New features**: Use `flutter_bloc` following the layered architecture (UI → BLoC → Repository → Client)
>
> **Existing code**: Riverpod is used for legacy code maintenance only

## Ownership Boundary

**Riverpod owns:** app-level DI, long-lived services/clients, infrastructure side-effects.  
**BLoC/Cubit owns:** all feature UI state, all UI side effects, all loading/error/success states.

## Signing readiness: identity known is not signer ready

`AuthState.authenticated` means the pubkey is known. It does **not** mean
anything can be signed. For a Keycast identity with no local key the
signer becomes usable *after* the auth state settles, on a different
signal entirely.

`nostrSessionProvider` (`lib/providers/nostr_client_provider.dart`) is the
app-wide contract, and it is two-tier:

| Phase | Carries | Use it for |
|-------|---------|------------|
| `identityKnown` | pubkey | reads, scoping caches/repositories to an owner, UI gating |
| `nostrReady` | pubkey **and** a keyed `NostrClient` | Nostr-client signing/publishing that needs the initialized client |

Rules:

- **Anything that signs or publishes through the app-wide `NostrClient`
  watches `nostrReady`**, via
  `ref.watch(nostrSessionProvider).isReadyForActiveClient` or a
  `ref.listen` on the provider. `profileRepositoryProvider` (nullable
  gate) and `notificationsProviders` (auth state for teardown +
  readiness for work) are the reference implementations.
- **Relay-free signing watches signer capability, not relay readiness.**
  For example, REST NIP-98 calls that use `Nip98AuthService(authService:)`
  need an identity that can sign now, but do not need relay connections.
  Watch `currentAuthStateProvider` for account changes and
  `currentAuthRpcCapabilityProvider` for the Keycast
  `unavailable -> rpcReady` transition, then sample
  `AuthService.canPublishNostrWritesNow`.
- **Never gate a signer-dependent side effect on `authStateStream` or
  `currentAuthStateProvider` alone.** Those are identity signals.
  Watching them is correct when you only need to re-scope to a new
  pubkey or show/hide UI.
- `AuthService.canPublishNostrWritesNow` answers "is this identity
  *capable* of signing", not "is the client ready". It has no direct
  stream, so sample it at the moment of use; for push consumers, pair
  that sample with a real rebuild trigger such as
  `currentAuthRpcCapabilityProvider`.

The distinction matters most for **push** consumers — code that asks
once and then waits. Pull consumers that re-read at call time cannot go
stale and are fine either way. #6977 is the worked example: the invites
screen asked at `authenticated`, got "cannot sign", and never heard the
correction 21ms later.

## Allowed / Disallowed Patterns

| Pattern | Verdict |
|---------|---------|
| `ConsumerWidget` outer Page + `BlocProvider` → `StatelessWidget` inner View | **Allowed** — canonical bridge; use `ref.watch` + `ValueKey` guard |
| `ConsumerWidget` that only creates `BlocProvider` without reading any Riverpod dep | **Disallowed** — use plain `StatelessWidget` |
| `ConsumerStatefulWidget` storing UI state in `_state` fields | **Disallowed** — extract to a `Cubit` |
| New `@riverpod` / `StateProvider` for feature UI state | **Disallowed** — use BLoC/Cubit |
| `*BridgeProvider` as infrastructure side-effect | **Allowed** — must have `// TODO(#issue):` removal comment |
| `ref.read` capturing dep in `BlocProvider.create` without `ValueKey` guard | **Disallowed** — stale dep on auth flip |
| `ref.watch` inside `BlocProvider.create` | **Disallowed** — `create` is called once; watch in `build`, pass via `ValueKey` |

### Canonical template screens

Copy the closest example when writing a new bridged screen:

| Screen | File | Pattern |
|--------|------|---------|
| `NotificationsPage` | `mobile/lib/notifications/view/notifications_page.dart` | Nullable dep gate before creating `BlocProvider`, re-keyed on watched repositories |
| `AppsDirectoryScreen` | `mobile/lib/screens/apps/apps_directory_screen.dart` | `ref.read` stable service, no `ValueKey` needed |
| `VideoEngagementListScreen` | `mobile/lib/screens/video_engagement/video_engagement_list_screen.dart` | `ref.watch` auth-sensitive repos + record `ValueKey` guard; view in separate file |

See `docs/BLOC_UI_MIGRATION_PRD.md` for the full rationale and bridge inventory.

---

# BLoC (Primary - New Features)

Use BLoC/Cubit for all new feature development.

## No BLoC-to-BLoC Dependencies

BLoCs must **never** depend on or dispatch events to other BLoCs. Each BLoC only depends on repositories and clients (the layers below it).

If one BLoC's state change should trigger another BLoC's event, use a `BlocListener` in the UI layer to bridge them.

**Bad — BLoC dispatches to another BLoC:**
```dart
class SearchResultsBloc extends Bloc<SearchResultsEvent, SearchResultsState> {
  SearchResultsBloc({required VideoSearchBloc videoSearchBloc})
    : _videoSearchBloc = videoSearchBloc;

  final VideoSearchBloc _videoSearchBloc;

  void _onQuery(QueryChanged event, Emitter emit) {
    _videoSearchBloc.add(VideoSearchQueryChanged(event.query)); // WRONG
  }
}
```

**Good — UI coordinates via BlocListener:**
```dart
BlocListener<SearchResultsBloc, SearchResultsState>(
  listenWhen: (prev, curr) => prev.query != curr.query,
  listener: (context, state) {
    context.read<VideoSearchBloc>().add(
      VideoSearchQueryChanged(state.query),
    );
  },
  child: ...,
)
```

## Event Transformers

Since Bloc v.7.2.0, events are handled concurrently by default. This allows event handler instances to execute simultaneously but provides no guarantees regarding the order of handler completion.

**Warning**: Concurrent event handling can cause race conditions when the result of operations varies with their order of execution.

### Registering Event Transformers

```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc() : super(MyState()) {
    on<MyEvent>(
      _onEvent,
      transformer: sequential(),
    );
    on<MySecondEvent>(
      _onSecondEvent,
      transformer: droppable(),
    );
  }
}
```

**Note**: Event transformers are only applied within the bucket they are specified in. Events of the same type are processed according to their transformer, while different event types are processed concurrently.

### Transformer Types

Use the `bloc_concurrency` package for these transformers:

| Transformer | Behavior | Use Case |
|-------------|----------|----------|
| `concurrent` | Default. Events handled simultaneously | Independent operations |
| `sequential` | FIFO order, one at a time | Operations that depend on previous state |
| `droppable` | Discards events while processing | Prevent duplicate API calls |
| `restartable` | Cancels previous, processes latest | Search/typeahead, latest value matters |

### Sequential Example (Prevent Race Conditions)

```dart
class MoneyBloc extends Bloc<MoneyEvent, MoneyState> {
  MoneyBloc() : super(MoneyState()) {
    // Use sequential to prevent race conditions!
    on<ChangeBalance>(_onChangeBalance, transformer: sequential());
  }

  Future<void> _onChangeBalance(
    ChangeBalance event,
    Emitter<MoneyState> emit,
  ) async {
    final balance = await api.readBalance();
    await api.setBalance(balance + event.add);
  }
}
```

### Droppable Example (Prevent Duplicate Calls)

```dart
class SayHiBloc extends Bloc<SayHiEvent, SayHiState> {
  SayHiBloc() : super(SayHiState()) {
    on<SayHello>(_onSayHello, transformer: droppable());
  }

  Future<void> _onSayHello(SayHello event, Emitter<SayHiState> emit) async {
    await api.say("Hello!");
  }
}
```

### Restartable Example (Latest Value Wins)

```dart
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchState()) {
    on<SearchQueryChanged>(_onSearch, transformer: restartable());
  }

  Future<void> _onSearch(SearchQueryChanged event, Emitter<SearchState> emit) async {
    final results = await api.search(event.query);
    emit(state.copyWith(results: results));
  }
}
```

### Testing BLoCs with Event Order

When testing, ensure predictable event order:

```dart
blocTest<MyBloc, MyState>(
  'change value',
  build: () => MyBloc(),
  act: (bloc) async {
    bloc.add(ChangeValue(add: 1));
    await pumpEventQueue(); // Let the first event settle before adding another.
    bloc.add(ChangeValue(remove: 1));
  },
  expect: () => const [
    MyState(value: 1),
    MyState(value: 0),
  ],
);
```

Tests must not use `Future.delayed` for synchronization. The
`scripts/check_future_delayed_ceiling.sh` ratchet enforces this while the
remaining test debt tracked by #4837 is paid down.

---

## Error Handling in BLoC

> **Hard rule**: State must NEVER contain error messages, error strings, or exception objects. This is a frequent review finding — treat any `String? errorMessage` or `Exception?` field in state as a bug.

Errors are transient events, not stable UI data. Use BLoC's built-in `addError` to report them, and use a status enum to drive UI reactions.

### Correct Pattern

```dart
// In BLoC — report error, then update status only
catch (e, stackTrace) {
  addError(e, stackTrace);
  emit(state.copyWith(status: MyStatus.failure));
}

// In UI — react to the failure status
BlocBuilder<MyBloc, MyState>(
  builder: (context, state) {
    if (state.status == MyStatus.failure) {
      return const Text('Something went wrong');
    }
    return SuccessView(state.data);
  },
)
```

### Anti-Pattern

```dart
// DON'T store error strings in state
class MyState {
  final String? errorMessage;   // WRONG — pollutes state
  final Exception? exception;   // WRONG
}

emit(state.copyWith(
  status: MyStatus.failure,
  errorMessage: e.toString(),  // WRONG
));
```

### Why

1. **State semantics** — state represents displayable UI data, not transient error info.
2. **Lifecycle** — `addError` integrates with BLoC's error stream, logging, and `blocTest`'s `errors` parameter.
3. **Cleaner copyWith** — no `clearError` flags or manual error reset logic.
4. **l10n readiness** — error messages in state bypass localization; status enums let the UI choose the correct translated string.

---

## Work that outlives close(): emitIfOpen / addIfOpen

`close()` does not cancel work that is already in flight. An awaited
future resumes into a disposed cubit, and the emit throws:

```
Bad state: Cannot emit new states after calling close
Bad state: Cannot add new events after calling close
```

Both shipped as Crashlytics aggregates (#7293). The `add` half is the
less obvious one: `Bloc.close()` closes the event controller **before**
draining the queue, so `isClosed` is already `true` while pending
handlers are still running — any `add` they make lands on a closed
controller.

**Rule.** Every `emit` or `add` reachable across a suspension point —
an `await`, a stream callback, a timer, an unawaited future — is
guarded. Mix in `CloseGuardedEmit` and use the guarded calls from
[`lib/blocs/close_guard.dart`](../../mobile/lib/blocs/close_guard.dart):

```dart
class SettingsCubit extends Cubit<SettingsState>
    with CloseGuardedEmit<SettingsState> {
  Future<void> load() async {
    final value = await _service.read();
    emitIfOpen(state.copyWith(value: value));   // not emit(...)
  }
}

// Blocs get addIfOpen from the CloseGuardedAdd extension — no mixin
// needed, since Bloc.add is public.
_subscription = _stream.listen((v) => addIfOpen(FooChanged(v)));
```

Both return `bool`: `false` means the call was dropped because the
instance is closed, which is occasionally useful when the caller has
follow-up work that only makes sense against a live instance.

An `if (isClosed) return;` **after** the suspension point works too, and
is the right shape when there is cleanup to skip as well. A guard
*before* the await is not a guard — that is the bug.

Prefer cancelling the work where it is cancellable; the guard is for
genuinely uncancellable in-flight futures. Do not re-invent a private
`_emitIfOpen` per cubit — four of them had accumulated before #7370
consolidated them.

### What is NOT affected

An `on<Event>` handler's own `emit` parameter is `Emitter.call`, and
`Bloc.close()` cancels every live emitter before `super.close()`, so it
degrades to a silent no-op rather than throwing. Leave those alone — the
guard is for `BlocBase.emit` (any cubit method, or a bloc method outside
a handler) and for `Bloc.add`. `addError` never throws after close
either; it just forwards to `onError`.

### Enforcement

`scripts/check_post_close_emit_ceiling.sh` freezes the per-file count of
unguarded sites under `mobile/lib` in
`mobile/scripts/baseline/post_close_emit.txt` — a ceiling that may only
shrink. It runs in CI (the `generated-files` job), not in the pre-push
hook. To see the individual sites in a file:

```bash
cd mobile && dart run scripts/lib/post_close_emit_detector.dart lib --detail
```

After guarding sites, lock the win:

```bash
UPDATE_BASELINE=1 bash mobile/scripts/check_post_close_emit_ceiling.sh
```

---

## BlocProvider is lazy by default

`BlocProvider(create:)` defaults to `lazy: true` (inherited from
`provider`). The `create:` factory only runs the **first time** a
descendant reads the bloc — via `context.read<X>()`, `context.watch<X>()`,
`context.select((X b) => ...)`, `BlocBuilder<X, Y>`, `BlocListener<X, Y>`,
`BlocConsumer<X, Y>`, or `BlocSelector<X, Y, S>`.

**Consequence:** side effects inside the `create:` factory — a classic
example being `..add(const LoadRequested())` to warm a cache — **do not
run** unless something in the subtree consumes the bloc. A
`BlocProvider` with no consumer in its subtree is dead code.

**Bad — looks like cache warming, actually does nothing:**
```dart
// profile_grid.dart: there is no context.read<MyFollowersBloc> or
// BlocBuilder<MyFollowersBloc, ...> anywhere under `content`, so the
// factory — and therefore the load event — never fires.
return BlocProvider<MyFollowersBloc>(
  create: (_) => MyFollowersBloc(
    followRepository: followRepository,
  )..add(const MyFollowersListLoadRequested()),
  child: content,
);
```

**Before adding or keeping a `BlocProvider<X>`, verify a consumer
exists.** A quick grep across the subtree's files:

```
grep -rn "context.read<X>\|context.watch<X>\|context.select((X\|BlocBuilder<X,\|BlocListener<X,\|BlocConsumer<X,\|BlocSelector<X,"
```

If the grep returns nothing, choose one:

1. **Delete the wrapper.** If the work is "just cache warming," push it
   to the repository layer where it belongs — the repository owns
   composition, fallback, and pre-fetch strategies
   (see `architecture.md`).
2. **Add `lazy: false`** with a code comment justifying why the factory
   must run eagerly, and add a test that covers the eager effect.

This also applies to `MultiBlocProvider` and to nested providers — each
bloc needs its own consumer; one consumer does not wake the others.

---

## Bridging Riverpod-provided dependencies into BlocProvider

`BlocProvider(create: ...)` runs its factory **once per subtree
mount**. If the factory reads a Riverpod-provided dependency via
`ref.read`, the bloc captures whatever instance the provider
returned at that moment and keeps it for the lifetime of the
surrounding widget. When that dependency is later rebuilt — auth
flip, account switch, sign-out, explicit `ref.invalidate` — the
provider emits a fresh instance, but the bloc stays wired to the
stale one and silently operates on the previous state of the
world.

**Before applying this rule, check whether Pattern A is available.**
Some Riverpod-provided dependencies are *already* gated on a
readiness signal — `profileRepositoryProvider` returns `null` until
`nostrSessionProvider` reports `isReadyForActiveClient`. When that's the case, the consumer
reads the nullable value and renders a loading / disabled
affordance until it's non-null; the bloc never gets a chance to
capture a stale instance, and there's nothing for this rule to
guard. Migrating `likes` / `comments` / `reposts` to that same
nullable-gated shape was evaluated in #3523 and closed as not
planned — they stay under the rule below, where the `ValueKey`
guard is the shipped defense.

The rule below is the answer when Pattern A isn't available — when
the provider has no clean "not ready" signal, or when restructuring
the provider isn't in scope.

**Rule.** When a `BlocProvider.create:` consumes a Riverpod
dependency whose identity can change at runtime, the surrounding
`ConsumerWidget.build` must (a) read each such dependency with
`ref.watch`, and (b) compose those watched values into a
record-typed `ValueKey` on the `BlocProvider`. When any dependency
changes identity, the key changes, the old bloc is closed, and
`create:` runs again with the fresh dependencies. Records compare
per-field with `==`; for classes that don't override `==` (most
repositories and clients in this codebase) equality falls through
to identity — exactly the semantics this pattern needs.

**If any captured type ever overrides `==`** (e.g. content-based
equality on a repository for testing) the record key silently stops
detecting identity swaps — two distinct instances with equal
content compare equal, the key doesn't change on rebuild, and the
bloc keeps the stale capture. In that case, switch to an explicit
identity-hash key:

```dart
key: ValueKey(
  Object.hash(
    identityHashCode(likesRepository),
    identityHashCode(commentsRepository),
    identityHashCode(repostsRepository),
  ),
),
```

This was the original form shipped in #3503 before #3522 simplified
to records once the captured classes were confirmed not to override
`==`. The hash form stays correct under any `==` override, at the
cost of a vanishingly small (~2⁻³²) collision risk on a swap.

**Bad — captures the dep at first build, never recovers:**
```dart
class _FeedItem extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider); // WRONG
    return BlocProvider<VideoInteractionsBloc>(
      create: (_) => VideoInteractionsBloc(
        likesRepository: likesRepository,
        // ...
      ),
      child: ...,
    );
  }
}
```

**Good — bloc lifecycle tracks the dep's identity:**
```dart
class _FeedItem extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    return BlocProvider<VideoInteractionsBloc>(
      key: ValueKey(
        (likesRepository, commentsRepository, repostsRepository),
      ),
      create: (_) => VideoInteractionsBloc(
        likesRepository: likesRepository,
        commentsRepository: commentsRepository,
        repostsRepository: repostsRepository,
        // ...
      ),
      child: ...,
    );
  }
}
```

The canonical implementation lives in `feed_videos.dart` at the
`BlocProvider<VideoInteractionsBloc>` created in
`__OverlayState.build`, using `videoInteractionsBlocKey(...)` from
`video_interactions_bloc_key.dart`. The failure it cures (#3503): a
cold-launch race where the warm-up
chain materialised `likesRepository` before
`AuthService.initialize()` resolved, the underlying `Nostr` wrapped
a `LocalKeySigner(null)` placeholder, and every `sendLike` from the
captured bloc threw `StateError("No public key available …")`.

### Tradeoff: bloc state resets on swap

When the record key flips, the old bloc is closed and a new one is
constructed at initial state. **In-flight optimistic state — half-
flipped UI, pending publishes — is dropped.** This is intentional:
the optimistic state was bound to the *previous* dependency (a
different signer / `NostrClient` / user), and replaying it against
the new one is unsafe. The state-loss contract is pinned by
`pooled_video_feed_item_repo_swap_test.dart` ("resets bloc state
when likesRepositoryProvider rebuilds (intentional)"). If a future
change introduces a non-auth invalidation of one of these providers,
that test fails loudly so the state loss can be re-evaluated.

### When the rule does NOT apply

1. **The Riverpod dependency is genuinely stable for the bloc's
   lifetime.** A `StateProvider<int>` that is never invalidated is
   fine to read with `ref.read` — document the assumption inline.
2. **The bloc lives at a higher scope than the dependency change.**
   An app-shell-level bloc that needs to *react* to auth flips
   internally must subscribe to the change (e.g. via `ref.listen`
   from a parent `ConsumerWidget` or a stream subscription inside
   the bloc) — the `BlocProvider` key trick does not apply, because
   the bloc is supposed to outlive the change.
3. **Pattern A (gate the provider on readiness) is available.**
   When the dependency can be in a "not ready" state, the cleaner
   option is to gate the *provider itself* on a readiness flag —
   `profileRepositoryProvider` already gates on
   `nostrSessionProvider` and returns `null` until
   the real instance is available. The widget renders a loading /
   disabled affordance until the provider hands over a non-null
   dependency, and the bloc never gets to capture a stale one.

### Detection

A reviewer's quickest first filter is to grep for `ref.read` of a
provider whose backing object can flip identity, then check whether
each hit sits inside a `BlocProvider.create:` callback:

```
grep -rn "ref\.read(.*\(Repository\|Service\|Client\|Manager\)Provider)" mobile/lib --include="*.dart"
```

The type-suffix filter is a starting point, not exhaustive — the
codebase has ~40 `*ServiceProvider` / `*ClientProvider` /
`*ManagerProvider` instances on top of the `*RepositoryProvider`
ones, and naming isn't enforced. To catch every case at the cost of
more false positives (e.g. unchanging `StateProvider`s, `.notifier`
/ `.future` modifiers), widen to:

```
grep -rn "ref\.read\(.*Provider\)" mobile/lib --include="*.dart"
```

If the surrounding widget is a `ConsumerWidget` /
`ConsumerStatefulWidget` that wraps the value in a
`BlocProvider<...>` without a `ValueKey`, this rule applies.

---

## Stateful widgets that hold the captured-dep bloc directly

The same capture trap reproduces in a different shape:
`ConsumerStatefulWidget` whose `State` constructs a bloc in
`initState` and holds it via `late final`. The `ref.read` calls
inside `initState` capture whichever instance each provider
returned at that moment, and the `late final` field can never be
reassigned — so the captured chain is permanent for the widget's
lifetime, even across auth flips and account switches. Greppable
shape:

```dart
class _MyState extends ConsumerState<MyWidget> {
  late final SomeBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = SomeBloc(
      repository: ref.read(someRepositoryProvider), // WRONG
    );
  }
}
```

The `BlocProvider`-keyed-on-identity rule above doesn't apply
directly — there is no `BlocProvider` at the construction site to
attach a `ValueKey` to.

### Preferred fix: Page/View split

Push the bloc construction up into a `ConsumerWidget` parent that
wraps a `StatefulWidget` child via `BlocProvider`, and have the
stateful child consume the bloc through `context.read<Bloc>()`.
The parent then uses the existing rule (record-typed `ValueKey`
over the captured provider tuple) — no new shape introduced. This
matches the existing feed item host in `feed_videos.dart`, where
`__OverlayState` watches the repositories and keys the
`BlocProvider<VideoInteractionsBloc>` with
`videoInteractionsBlocKey(...)`. It also follows the Page/View
pattern in [`ui_theming.md`](ui_theming.md) and the
constructor-injection guidance in
[`architecture.md`](architecture.md) — the stateful child stops
reaching into Riverpod for its dependencies.

**Skeleton:**

```dart
class _MyParent extends ConsumerWidget {
  const _MyParent({required this.input});

  final InputType input;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo1 = ref.watch(repo1Provider);
    final repo2 = ref.watch(repo2Provider);
    return BlocProvider<MyBloc>(
      key: ValueKey((repo1, repo2)),
      create: (_) => MyBloc(repo1: repo1, repo2: repo2)
        ..add(const MyInitialEvent()),
      child: _MyChild(input: input),
    );
  }
}

class _MyChild extends StatefulWidget {
  const _MyChild({required this.input});

  final InputType input;

  @override
  State<_MyChild> createState() => _MyChildState();
}

class _MyChildState extends State<_MyChild> {
  // animation controllers, ValueNotifiers, scroll listeners, …

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MyBloc>();
    // …
  }
}
```

The split lets the parent own dependency lifecycle and the child
own local UI state, which is the same separation the existing four
sites already use.

### Workaround when refactor is blocked

When splitting the widget isn't feasible in scope (e.g. the
stateful logic tangles with the bloc lifecycle in a way the
refactor would balloon), snapshot the captured deps in `initState`
and use `ref.listen` in `build` to detect identity changes and
rebuild the bloc. The codebase already uses `ref.listen`-in-`build`
for forwarding Riverpod signals to a Bloc (see
`my_followers_screen.dart`'s blocklist invalidation handler) — this
extends the same idiom to "rebuild the bloc itself when its
captured deps change identity":

```dart
late MyBloc _bloc;
late (Repo1, Repo2) _captured;

@override
void initState() {
  super.initState();
  _captured = (
    ref.read(repo1Provider),
    ref.read(repo2Provider),
  );
  _bloc = _createBloc(_captured)..add(const MyInitialEvent());
}

@override
Widget build(BuildContext context) {
  ref.listen<Repo1>(repo1Provider, (_, _) => _maybeRecreate());
  ref.listen<Repo2>(repo2Provider, (_, _) => _maybeRecreate());
  return BlocProvider<MyBloc>.value(
    value: _bloc,
    child: const _MyChild(),
  );
}

void _maybeRecreate() {
  if (!mounted) return;
  final fresh = (
    ref.read(repo1Provider),
    ref.read(repo2Provider),
  );
  if (fresh == _captured) return;
  _bloc.close();
  _captured = fresh;
  setState(() {
    _bloc = _createBloc(fresh)..add(const MyInitialEvent());
  });
}

@override
void dispose() {
  _bloc.close();
  super.dispose();
}

MyBloc _createBloc((Repo1, Repo2) deps) {
  final (repo1, repo2) = deps;
  return MyBloc(repo1: repo1, repo2: repo2);
}
```

This is a fallback, not the primary recommendation. It introduces
a shape that doesn't currently appear elsewhere in the codebase
and bypasses the established Page/View precedent. Prefer the
refactor when reasonable.

The same state-loss tradeoff applies as the `BlocProvider` case:
each recreate drops in-flight optimistic state and pending
publishes, which is the correct behaviour when the underlying
repository is bound to a different signer / `NostrClient` / user.

### Detection

```
grep -rn "late\s\+\(final\s\+\)\?[A-Z][A-Za-z]*\(Bloc\|Cubit\)\b" mobile/lib --include="*.dart"
```

For each hit, check `initState` for `ref.read(...Provider)` calls
that capture providers whose identity can flip (auth flip, account
switch, sign-out, explicit `ref.invalidate`). Apply the same
identity-flip judgment as the `BlocProvider.create:` case — if the
captured provider rebuilds in response to runtime events, the
`late final` field will go stale.

---

## Persisting state across shell-route transitions

Screens inside a `ShellRoute` whose content is gated on the current URL
(e.g. `_ProfileContentView` returning `SizedBox.shrink()` when
`routeContext.type != RouteType.profile`) will **unmount** the content
subtree whenever the URL briefly leaves the route — including during
`context.push(...)` to a route defined outside the shell.

Consequences:

- `TabController`, `ScrollController`, animation controllers, and any
  other state living in a widget `State` are **disposed** and
  re-created on return.
- The user sees the screen "reset" (e.g. selected tab → Videos, scroll
  position → top) after closing the pushed route.

**Fix:** persist the state externally, keyed by stable identifiers.
For per-screen state like "active tab index," include both the signed-in
viewer and target profile so account switches cannot restore another
identity's tab selection for the same profile:

```dart
// lib/providers/profile_tab_index_provider.dart
import 'package:flutter_riverpod/legacy.dart';

typedef ProfileTabIndexKey = ({
  String? viewerPubkeyHex,
  String targetPubkeyHex,
});

final profileTabIndexProvider = StateProvider<Map<ProfileTabIndexKey, int>>(
  (ref) => <ProfileTabIndexKey, int>{},
);
```

Read in `initState` to seed `TabController.initialIndex`; write in the
tab listener using `authServiceProvider.currentPublicKeyHex` plus the
profile pubkey as the key. Lazy-sync side effects (e.g. loading a tab's
data on first view) must also be re-dispatched when the restored index is
not zero, since the controller's listener doesn't fire for the initial
index.

See `profile_grid.dart` + `profile_tab_index_provider.dart` for the
pattern.

### Riverpod 3.x gotcha

`StateProvider` lives in **`package:flutter_riverpod/legacy.dart`** in
Riverpod 3 — it's not exported from the main `flutter_riverpod.dart`
entry. `StateProvider.family` type inference has sharp edges; prefer a
plain `StateProvider<Map<K, V>>` for per-key state unless you
specifically need independent cache scopes per key.

---

## No Mutable Instance Variables in BLoC

All mutable data must live in the BLoC's state object, never as private fields on the BLoC class. Private fields bypass the state stream, making them invisible to the UI, untestable via `blocTest`, and prone to desyncing from the actual state.

**Bad:**
```dart
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  int _retryCount = 0;            // WRONG — hidden from state
  bool _isInitialized = false;    // WRONG — not observable
  List<String> _selectedIds = []; // WRONG — bypasses emit

  Future<void> _onShare(...) async {
    _retryCount++;
    // UI has no idea _retryCount changed
  }
}
```

**Good:**
```dart
class ShareSheetState extends Equatable {
  const ShareSheetState({
    this.retryCount = 0,
    this.isInitialized = false,
    this.selectedIds = const [],
  });

  final int retryCount;
  final bool isInitialized;
  final List<String> selectedIds;
  // ...
}
```

**Exception**: Injected dependencies (repositories, clients) are fine as `final` fields — they are immutable configuration, not mutable state.

---

## Use BlocSelector for Granular Rebuilds

When a widget only needs one or a few properties from state, use `BlocSelector` or `context.select` instead of `BlocBuilder` or `context.watch`. Watching the full state rebuilds the widget on every emit, even when the property it cares about hasn't changed.

**Bad — rebuilds on every state change:**
```dart
class ConversationView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Rebuilds entire subtree on ANY state change
    final state = context.watch<ConversationBloc, ConversationState>();
    return Column(
      children: [
        ConversationAppBar(title: state.title),
        MessageList(messages: state.messages),
        SendButton(status: state.sendStatus),
      ],
    );
  }
}
```

**Good — each widget selects only what it needs:**
```dart
class ConversationView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _AppBar(),
        _MessageList(),
        _SendButton(),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    // Only rebuilds when sendStatus changes
    final sendStatus = context.select(
      (ConversationBloc bloc) => bloc.state.sendStatus,
    );
    return ElevatedButton(
      onPressed: sendStatus == SendStatus.ready ? () {} : null,
      child: const Text('Send'),
    );
  }
}
```

**When to use which:**

| Widget | Use |
|--------|-----|
| `BlocBuilder` | Widget depends on most/all of the state |
| `BlocSelector` / `context.select` | Widget depends on one or a few properties |
| `BlocListener` | Side effects (snackbars, navigation) |

---

## Computed Properties on State and Models

When logic derives a display value from state fields, add it as a getter on the state or model class rather than computing it inline in the UI or BLoC. This keeps the UI thin, makes the logic testable, and avoids duplication when the same derivation is needed elsewhere.

**Bad — logic scattered in UI:**
```dart
// In widget
final displayName = state.profile.name.isNotEmpty
    ? state.profile.name
    : state.profile.npub.substring(0, 12);
```

**Good — getter on model or state:**
```dart
class UserProfile {
  // ...
  String get displayName =>
      name.isNotEmpty ? name : npub.substring(0, 12);
}

// In widget — clean and reusable
Text(state.profile.displayName);
```

**Good — derived validation on state:**
```dart
class CreateAccountState extends Equatable {
  // ...
  bool get isValid =>
      name?.isNotEmpty == true &&
      email?.isNotEmpty == true;
}
```

### Getters vs Stored State: When Computation Is Expensive

Simple derivations (null checks, string formatting, boolean flags) are fine as getters. However, if the computation is expensive — sorting, filtering, or transforming a list — store the result as a field in state rather than recomputing it on every access.

```dart
// Good — cheap derivation, getter is fine
bool get isValid => name?.isNotEmpty == true;

// Bad — expensive list operation as a getter, recomputed on every access
List<Video> get sortedVideos =>
    videos.toList()..sort((a, b) => b.date.compareTo(a.date));

// Good — computed once at emit time and stored in state
emit(state.copyWith(
  sortedVideos: videos.toList()..sort((a, b) => b.date.compareTo(a.date)),
));
```

---

## State Handling: Enum vs Sealed Classes

Choose based on whether you need to persist data across state changes.

### When to Use Enum Status (Persist Data)

Use a **single class with an enum status** when:
- Form data is updated step by step
- State has several values loaded independently
- You need to preserve previously emitted data

```dart
enum CreateAccountStatus { initial, loading, success, failure }

class CreateAccountState extends Equatable {
  const CreateAccountState({
    this.status = CreateAccountStatus.initial,
    this.name,
    this.surname,
    this.email,
  });

  final CreateAccountStatus status;
  final String? name;
  final String? surname;
  final String? email;

  CreateAccountState copyWith({
    CreateAccountStatus? status,
    String? name,
    String? surname,
    String? email,
  }) {
    return CreateAccountState(
      status: status ?? this.status,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
    );
  }

  bool get isValid => name?.isNotEmpty == true
      && surname?.isNotEmpty == true
      && email?.isNotEmpty == true;

  @override
  List<Object?> get props => [status, name, surname, email];
}
```

**Cubit usage:**
```dart
class CreateAccountCubit extends Cubit<CreateAccountState> {
  CreateAccountCubit() : super(const CreateAccountState());

  void updateName(String name) {
    emit(state.copyWith(name: name)); // Preserves other data
  }

  Future<void> createAccount() async {
    emit(state.copyWith(status: CreateAccountStatus.loading));
    try {
      if (state.isValid) {
        emit(state.copyWith(status: CreateAccountStatus.success));
      }
    } catch (e, s) {
      addError(e, s);
      emit(state.copyWith(status: CreateAccountStatus.failure));
    }
  }
}
```

**UI consumption:**
```dart
BlocListener<CreateAccountCubit, CreateAccountState>(
  listener: (context, state) {
    if (state.status == CreateAccountStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  },
  child: CreateAccountFormView(),
)
```

### When to Use Sealed Classes (Fresh State)

Use **sealed classes** when:
- Data fetching is a one-time operation
- You don't need to preserve data across state changes
- Each state has isolated, non-nullable properties

```dart
sealed class ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileSuccess extends ProfileState {
  ProfileSuccess(this.profile);
  final Profile profile;
}

class ProfileFailure extends ProfileState {
  ProfileFailure(this.errorMessage);
  final String errorMessage;
}
```

**Cubit usage:**
```dart
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileLoading()) {
    getProfileDetails();
  }

  Future<void> getProfileDetails() async {
    try {
      final data = await repository.getProfile();
      emit(ProfileSuccess(data));
    } catch (e) {
      emit(ProfileFailure('Could not load profile'));
    }
  }
}
```

**UI consumption with exhaustive switch:**
```dart
BlocBuilder<ProfileCubit, ProfileState>(
  builder: (context, state) {
    return switch (state) {
      ProfileLoading() => const CircularProgressIndicator(),
      ProfileSuccess(:final profile) => ProfileView(profile),
      ProfileFailure(:final errorMessage) => Text(errorMessage),
    };
  },
)
```

### Sharing Properties Across Sealed States

```dart
sealed class ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileSuccess extends ProfileState {
  ProfileSuccess(this.profile);
  final Profile profile;
}

class ProfileEditing extends ProfileState {
  ProfileEditing(this.profile);
  final Profile profile;
}

class ProfileFailure extends ProfileState {
  ProfileFailure(this.errorMessage);
  final String errorMessage;
}

// In Cubit - handle shared properties:
Future<void> editName(String newName) async {
  switch (state) {
    case ProfileSuccess(profile: final prof):
    case ProfileEditing(profile: final prof):
      final newProfile = prof.copyWith(name: newName);
      emit(ProfileSuccess(newProfile));
    case ProfileLoading():
    case ProfileFailure():
      return;
  }
}

// In UI - pattern match shared properties:
return switch (state) {
  ProfileLoading() => const CircularProgressIndicator(),
  ProfileSuccess(profile: final prof) ||
  ProfileEditing(profile: final prof) => ProfileView(prof),
  ProfileFailure(errorMessage: final message) => Text(message),
};
```

---

# Riverpod (Legacy - Existing Code)

> **Note**: These rules are for maintaining existing Riverpod code only. Use BLoC for new features.

## Using Ref

1. `Ref` is essential for accessing the provider system, reading/watching other providers, managing lifecycles
2. In functional providers, obtain `Ref` as a parameter; in class-based providers, access it as a property of the Notifier
3. In widgets, use `WidgetRef` (a subtype of `Ref`) to interact with providers

### Ref Methods

| Method | Use Case |
|--------|----------|
| `ref.watch` | Reactive listening, rebuilds on change |
| `ref.read` | One-time access (non-reactive) |
| `ref.listen` | Imperative subscriptions |
| `ref.onDispose` | Cleanup resources |

```dart
// Functional provider
@riverpod
int example(Ref ref) {
  final value = ref.watch(otherProvider);
  return value * 2;
}

// Widget consumption
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myProvider);
    return Text('$value');
  }
}
```

## Key Rules

1. **Prefer `ref.watch`** for reactive logic that auto-recomputes
2. **Avoid `ref.watch` in imperative code** (callbacks, Notifier methods) - only use during build phase
3. **Use `ref.read` sparingly** - only when you cannot use `ref.watch`
4. **Always enable `autoDispose` for parameterized providers** to prevent memory leaks
5. **Use `ConsumerWidget`/`ConsumerStatefulWidget`** over raw StatelessWidget when accessing providers

## Auto Dispose

```dart
// Code generation - auto dispose by default
@riverpod
Future<Data> fetchData(Ref ref) async {
  return api.getData();
}

// Opt out of auto dispose
@Riverpod(keepAlive: true)
Future<Data> persistentData(Ref ref) async {
  return api.getData();
}
```

## Passing Arguments (Families)

```dart
@riverpod
Future<User> user(Ref ref, String id) async {
  return api.getUser(id);
}

// Consumption
final user = ref.watch(userProvider('user-123'));
```

## Side Effects in Notifiers

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    return repository.getTodos();
  }

  Future<void> addTodo(Todo todo) async {
    await repository.addTodo(todo);
    ref.invalidateSelf(); // Refresh the list
  }
}
```

## Testing

```dart
// Unit test
final container = ProviderContainer();
addTearDown(container.dispose);
expect(container.read(myProvider), equals('value'));

// Widget test
await tester.pumpWidget(
  ProviderScope(
    overrides: [myProvider.overrideWithValue('mock')],
    child: MyWidget(),
  ),
);
```
