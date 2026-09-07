// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cached following list loaded directly from SharedPreferences.
///
/// Available immediately after authentication (no NostrClient needed).
/// This provides the follow list from the previous session for instant
/// feed display. The full FollowRepository will update this when ready.

@ProviderFor(cachedFollowingList)
final cachedFollowingListProvider = CachedFollowingListProvider._();

/// Cached following list loaded directly from SharedPreferences.
///
/// Available immediately after authentication (no NostrClient needed).
/// This provides the follow list from the previous session for instant
/// feed display. The full FollowRepository will update this when ready.

final class CachedFollowingListProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Cached following list loaded directly from SharedPreferences.
  ///
  /// Available immediately after authentication (no NostrClient needed).
  /// This provides the follow list from the previous session for instant
  /// feed display. The full FollowRepository will update this when ready.
  CachedFollowingListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cachedFollowingListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cachedFollowingListHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return cachedFollowingList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$cachedFollowingListHash() =>
    r'45bc25e8c158362536dd5373b4f70bbbfae54a83';

/// Provider for FollowRepository instance
///
/// Creates a FollowRepository for managing follow relationships.
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalEventCacheService (for caching contact list events)

@ProviderFor(followRepository)
final followRepositoryProvider = FollowRepositoryProvider._();

/// Provider for FollowRepository instance
///
/// Creates a FollowRepository for managing follow relationships.
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalEventCacheService (for caching contact list events)

final class FollowRepositoryProvider
    extends
        $FunctionalProvider<
          FollowRepository,
          FollowRepository,
          FollowRepository
        >
    with $Provider<FollowRepository> {
  /// Provider for FollowRepository instance
  ///
  /// Creates a FollowRepository for managing follow relationships.
  /// Non-nullable: the repository works without keys at construction time.
  /// Read operations return cached/empty data; write operations check keys.
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - PersonalEventCacheService (for caching contact list events)
  FollowRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followRepositoryHash();

  @$internal
  @override
  $ProviderElement<FollowRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FollowRepository create(Ref ref) {
    return followRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FollowRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FollowRepository>(value),
    );
  }
}

String _$followRepositoryHash() => r'd2574431abdc640b6e7bc9e620de2d7ad7b59b5e';

/// Provider for [CuratedListRepository] instance.
///
/// Creates a repository that exposes subscribed curated lists via a
/// [BehaviorSubject] stream for reactive BLoC subscription. Data is
/// bridged from the legacy [CuratedListService] via [setSubscribedLists]
/// until the repository owns its own persistence (Phase 1b).

@ProviderFor(curatedListRepository)
final curatedListRepositoryProvider = CuratedListRepositoryProvider._();

/// Provider for [CuratedListRepository] instance.
///
/// Creates a repository that exposes subscribed curated lists via a
/// [BehaviorSubject] stream for reactive BLoC subscription. Data is
/// bridged from the legacy [CuratedListService] via [setSubscribedLists]
/// until the repository owns its own persistence (Phase 1b).

final class CuratedListRepositoryProvider
    extends
        $FunctionalProvider<
          CuratedListRepository,
          CuratedListRepository,
          CuratedListRepository
        >
    with $Provider<CuratedListRepository> {
  /// Provider for [CuratedListRepository] instance.
  ///
  /// Creates a repository that exposes subscribed curated lists via a
  /// [BehaviorSubject] stream for reactive BLoC subscription. Data is
  /// bridged from the legacy [CuratedListService] via [setSubscribedLists]
  /// until the repository owns its own persistence (Phase 1b).
  CuratedListRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListRepositoryHash();

  @$internal
  @override
  $ProviderElement<CuratedListRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CuratedListRepository create(Ref ref) {
    return curatedListRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CuratedListRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CuratedListRepository>(value),
    );
  }
}

String _$curatedListRepositoryHash() =>
    r'2ab27b85f298d47b068db155ec6a5bfcefeb1e33';

/// Provider for HashtagRepository instance.
///
/// Creates a HashtagRepository for searching hashtags via the Funnelcake API.

@ProviderFor(hashtagRepository)
final hashtagRepositoryProvider = HashtagRepositoryProvider._();

/// Provider for HashtagRepository instance.
///
/// Creates a HashtagRepository for searching hashtags via the Funnelcake API.

final class HashtagRepositoryProvider
    extends
        $FunctionalProvider<
          HashtagRepository,
          HashtagRepository,
          HashtagRepository
        >
    with $Provider<HashtagRepository> {
  /// Provider for HashtagRepository instance.
  ///
  /// Creates a HashtagRepository for searching hashtags via the Funnelcake API.
  HashtagRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagRepositoryHash();

  @$internal
  @override
  $ProviderElement<HashtagRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HashtagRepository create(Ref ref) {
    return hashtagRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagRepository>(value),
    );
  }
}

String _$hashtagRepositoryHash() => r'9bb8a737619e6dbf039bd8d0dd218c94a6ca17e6';

/// Provider for CategoriesRepository instance.
///
/// Keep-alive so the categories cache survives tab and screen transitions.

@ProviderFor(categoriesRepository)
final categoriesRepositoryProvider = CategoriesRepositoryProvider._();

/// Provider for CategoriesRepository instance.
///
/// Keep-alive so the categories cache survives tab and screen transitions.

final class CategoriesRepositoryProvider
    extends
        $FunctionalProvider<
          CategoriesRepository,
          CategoriesRepository,
          CategoriesRepository
        >
    with $Provider<CategoriesRepository> {
  /// Provider for CategoriesRepository instance.
  ///
  /// Keep-alive so the categories cache survives tab and screen transitions.
  CategoriesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoriesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoriesRepository create(Ref ref) {
    return categoriesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoriesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoriesRepository>(value),
    );
  }
}

String _$categoriesRepositoryHash() =>
    r'674c9dc3ed951c7bf04466dcd424d0195de4273b';

/// Provider for ProfileRepository instance
///
/// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
///
/// Returns `null` until `nostrSessionProvider` reports
/// `isReadyForActiveClient` — a keyed [NostrClient] for the active identity,
/// not merely `AuthState.authenticated`. A signed-in user whose signer is
/// still warming up gets `null` here, so callers must null-check. Reads that
/// only need a pubkey should take [profileReadRepositoryProvider] instead,
/// which is available one phase earlier.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - FunnelcakeApiClient for fast REST-based profile search

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provider for ProfileRepository instance
///
/// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
///
/// Returns `null` until `nostrSessionProvider` reports
/// `isReadyForActiveClient` — a keyed [NostrClient] for the active identity,
/// not merely `AuthState.authenticated`. A signed-in user whose signer is
/// still warming up gets `null` here, so callers must null-check. Reads that
/// only need a pubkey should take [profileReadRepositoryProvider] instead,
/// which is available one phase earlier.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - FunnelcakeApiClient for fast REST-based profile search

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository?,
          ProfileRepository?,
          ProfileRepository?
        >
    with $Provider<ProfileRepository?> {
  /// Provider for ProfileRepository instance
  ///
  /// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
  ///
  /// Returns `null` until `nostrSessionProvider` reports
  /// `isReadyForActiveClient` — a keyed [NostrClient] for the active identity,
  /// not merely `AuthState.authenticated`. A signed-in user whose signer is
  /// still warming up gets `null` here, so callers must null-check. Reads that
  /// only need a pubkey should take [profileReadRepositoryProvider] instead,
  /// which is available one phase earlier.
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - FunnelcakeApiClient for fast REST-based profile search
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository? create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository?>(value),
    );
  }
}

String _$profileRepositoryHash() => r'92a8519f8d195b5c33727803820aa82e94a8b0b2';

/// Read-only profile access gated on **identity-known** (a pubkey is
/// available) rather than the full `nostrReady` relay-connect settle.
///
/// Everything reachable through [ProfileReader] is signer-free: it either
/// reads Drift directly or performs a network read without signing. Fresh
/// profile reads may fall back to relays, but none requires relay readiness.
/// Gating these reads behind `nostrReady` left
/// the follower/following/video counts stuck on "—" for the ~4s relay-connect
/// window at cold start (#5863), and what replaced the signed-in user's own
/// name and avatar with a generated placeholder for that same window (#6423).
/// This provider hands over the repository as soon as the identity is known.
///
/// **The return type is the security boundary.** The identity-known phase
/// carries a pubkey but no client, so signing there is unsafe even though
/// Drift reads are not. [ProfileReader] cannot express `saveProfileEvent`,
/// `claimUsername`, `releaseUsername` or `drivePendingSave`, so a consumer of
/// this provider cannot publish by accident. Everything that signs must keep
/// using [profileRepository] — today that is
/// `MonetizationLinksSettingsCubit`, `ProfileEditorBloc`, and
/// `profileSaveRetryService`.
///
/// It does NOT warm the Kind-0 cache — that side effect belongs to the
/// relay-backed [profileRepository].

@ProviderFor(profileReadRepository)
final profileReadRepositoryProvider = ProfileReadRepositoryProvider._();

/// Read-only profile access gated on **identity-known** (a pubkey is
/// available) rather than the full `nostrReady` relay-connect settle.
///
/// Everything reachable through [ProfileReader] is signer-free: it either
/// reads Drift directly or performs a network read without signing. Fresh
/// profile reads may fall back to relays, but none requires relay readiness.
/// Gating these reads behind `nostrReady` left
/// the follower/following/video counts stuck on "—" for the ~4s relay-connect
/// window at cold start (#5863), and what replaced the signed-in user's own
/// name and avatar with a generated placeholder for that same window (#6423).
/// This provider hands over the repository as soon as the identity is known.
///
/// **The return type is the security boundary.** The identity-known phase
/// carries a pubkey but no client, so signing there is unsafe even though
/// Drift reads are not. [ProfileReader] cannot express `saveProfileEvent`,
/// `claimUsername`, `releaseUsername` or `drivePendingSave`, so a consumer of
/// this provider cannot publish by accident. Everything that signs must keep
/// using [profileRepository] — today that is
/// `MonetizationLinksSettingsCubit`, `ProfileEditorBloc`, and
/// `profileSaveRetryService`.
///
/// It does NOT warm the Kind-0 cache — that side effect belongs to the
/// relay-backed [profileRepository].

final class ProfileReadRepositoryProvider
    extends $FunctionalProvider<ProfileReader?, ProfileReader?, ProfileReader?>
    with $Provider<ProfileReader?> {
  /// Read-only profile access gated on **identity-known** (a pubkey is
  /// available) rather than the full `nostrReady` relay-connect settle.
  ///
  /// Everything reachable through [ProfileReader] is signer-free: it either
  /// reads Drift directly or performs a network read without signing. Fresh
  /// profile reads may fall back to relays, but none requires relay readiness.
  /// Gating these reads behind `nostrReady` left
  /// the follower/following/video counts stuck on "—" for the ~4s relay-connect
  /// window at cold start (#5863), and what replaced the signed-in user's own
  /// name and avatar with a generated placeholder for that same window (#6423).
  /// This provider hands over the repository as soon as the identity is known.
  ///
  /// **The return type is the security boundary.** The identity-known phase
  /// carries a pubkey but no client, so signing there is unsafe even though
  /// Drift reads are not. [ProfileReader] cannot express `saveProfileEvent`,
  /// `claimUsername`, `releaseUsername` or `drivePendingSave`, so a consumer of
  /// this provider cannot publish by accident. Everything that signs must keep
  /// using [profileRepository] — today that is
  /// `MonetizationLinksSettingsCubit`, `ProfileEditorBloc`, and
  /// `profileSaveRetryService`.
  ///
  /// It does NOT warm the Kind-0 cache — that side effect belongs to the
  /// relay-backed [profileRepository].
  ProfileReadRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileReadRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileReadRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileReader?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfileReader? create(Ref ref) {
    return profileReadRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileReader? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileReader?>(value),
    );
  }
}

String _$profileReadRepositoryHash() =>
    r'6a1e6da7d10b16ef607eaf7c1b771201ebb753a4';

/// Curation Service - manages NIP-51 video curation sets

@ProviderFor(curationRepository)
final curationRepositoryProvider = CurationRepositoryProvider._();

/// Curation Service - manages NIP-51 video curation sets

final class CurationRepositoryProvider
    extends
        $FunctionalProvider<
          CurationRepository,
          CurationRepository,
          CurationRepository
        >
    with $Provider<CurationRepository> {
  /// Curation Service - manages NIP-51 video curation sets
  CurationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationRepositoryHash();

  @$internal
  @override
  $ProviderElement<CurationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CurationRepository create(Ref ref) {
    return curationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurationRepository>(value),
    );
  }
}

String _$curationRepositoryHash() =>
    r'a1a9ce03d658dd1bf9c924270bd9dacd0d070a56';

/// Lists state notifier - manages curated lists state

@ProviderFor(CuratedListsState)
final curatedListsStateProvider = CuratedListsStateProvider._();

/// Lists state notifier - manages curated lists state
final class CuratedListsStateProvider
    extends $AsyncNotifierProvider<CuratedListsState, List<CuratedList>> {
  /// Lists state notifier - manages curated lists state
  CuratedListsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListsStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListsStateHash();

  @$internal
  @override
  CuratedListsState create() => CuratedListsState();
}

String _$curatedListsStateHash() => r'c6255dcf311db8ce01adb1aa64f5b40e38bd9729';

/// Lists state notifier - manages curated lists state

abstract class _$CuratedListsState extends $AsyncNotifier<List<CuratedList>> {
  FutureOr<List<CuratedList>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<CuratedList>>, List<CuratedList>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<CuratedList>>, List<CuratedList>>,
              AsyncValue<List<CuratedList>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Repository for NIP-51 kind 30000 people lists.
///
/// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
/// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
/// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
/// itself has no Flutter dependencies; this provider owns all UI glue.

@ProviderFor(peopleListsRepository)
final peopleListsRepositoryProvider = PeopleListsRepositoryProvider._();

/// Repository for NIP-51 kind 30000 people lists.
///
/// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
/// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
/// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
/// itself has no Flutter dependencies; this provider owns all UI glue.

final class PeopleListsRepositoryProvider
    extends
        $FunctionalProvider<
          PeopleListsRepository,
          PeopleListsRepository,
          PeopleListsRepository
        >
    with $Provider<PeopleListsRepository> {
  /// Repository for NIP-51 kind 30000 people lists.
  ///
  /// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
  /// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
  /// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
  /// itself has no Flutter dependencies; this provider owns all UI glue.
  PeopleListsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'peopleListsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$peopleListsRepositoryHash();

  @$internal
  @override
  $ProviderElement<PeopleListsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PeopleListsRepository create(Ref ref) {
    return peopleListsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeopleListsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeopleListsRepository>(value),
    );
  }
}

String _$peopleListsRepositoryHash() =>
    r'd62acfadef10fcaab46ba5f74352e7feacf3a63d';

/// Repository for the reserved kind 30000 `d=notify` subscription list.
///
/// Owns which creators the signed-in user gets new-post notifications about
/// ("bells"). Kept separate from [peopleListsRepository] so the app-managed
/// list is never reachable from list-editing UI.
///
/// Long-lived so the in-memory subscription snapshot and its mutation queue
/// survive navigation — a per-route instance would re-read the list on every
/// profile visit and lose in-flight publishes.

@ProviderFor(notifySubscriptionsRepository)
final notifySubscriptionsRepositoryProvider =
    NotifySubscriptionsRepositoryProvider._();

/// Repository for the reserved kind 30000 `d=notify` subscription list.
///
/// Owns which creators the signed-in user gets new-post notifications about
/// ("bells"). Kept separate from [peopleListsRepository] so the app-managed
/// list is never reachable from list-editing UI.
///
/// Long-lived so the in-memory subscription snapshot and its mutation queue
/// survive navigation — a per-route instance would re-read the list on every
/// profile visit and lose in-flight publishes.

final class NotifySubscriptionsRepositoryProvider
    extends
        $FunctionalProvider<
          NotifySubscriptionsRepository,
          NotifySubscriptionsRepository,
          NotifySubscriptionsRepository
        >
    with $Provider<NotifySubscriptionsRepository> {
  /// Repository for the reserved kind 30000 `d=notify` subscription list.
  ///
  /// Owns which creators the signed-in user gets new-post notifications about
  /// ("bells"). Kept separate from [peopleListsRepository] so the app-managed
  /// list is never reachable from list-editing UI.
  ///
  /// Long-lived so the in-memory subscription snapshot and its mutation queue
  /// survive navigation — a per-route instance would re-read the list on every
  /// profile visit and lose in-flight publishes.
  NotifySubscriptionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notifySubscriptionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notifySubscriptionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<NotifySubscriptionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotifySubscriptionsRepository create(Ref ref) {
    return notifySubscriptionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotifySubscriptionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotifySubscriptionsRepository>(
        value,
      ),
    );
  }
}

String _$notifySubscriptionsRepositoryHash() =>
    r'54ed8c30c8819f524052ba4abaccb01dfaeaacce';

/// Bookmark service for NIP-51 bookmarks.
///
/// Deliberately left as an autoDispose `Future` provider by the #6969
/// package extraction, so that move stayed behaviour-preserving. Both
/// consumers read it with `ref.read(...future)`, which leaves no listener, so
/// every read tears the element down and builds a fresh instance — dropping
/// its in-memory snapshot and its serialization queue. That is #7596, and it
/// is fixed next, not here.

@ProviderFor(bookmarksRepository)
final bookmarksRepositoryProvider = BookmarksRepositoryProvider._();

/// Bookmark service for NIP-51 bookmarks.
///
/// Deliberately left as an autoDispose `Future` provider by the #6969
/// package extraction, so that move stayed behaviour-preserving. Both
/// consumers read it with `ref.read(...future)`, which leaves no listener, so
/// every read tears the element down and builds a fresh instance — dropping
/// its in-memory snapshot and its serialization queue. That is #7596, and it
/// is fixed next, not here.

final class BookmarksRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookmarksRepository>,
          BookmarksRepository,
          FutureOr<BookmarksRepository>
        >
    with
        $FutureModifier<BookmarksRepository>,
        $FutureProvider<BookmarksRepository> {
  /// Bookmark service for NIP-51 bookmarks.
  ///
  /// Deliberately left as an autoDispose `Future` provider by the #6969
  /// package extraction, so that move stayed behaviour-preserving. Both
  /// consumers read it with `ref.read(...future)`, which leaves no listener, so
  /// every read tears the element down and builds a fresh instance — dropping
  /// its in-memory snapshot and its serialization queue. That is #7596, and it
  /// is fixed next, not here.
  BookmarksRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarksRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarksRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<BookmarksRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookmarksRepository> create(Ref ref) {
    return bookmarksRepository(ref);
  }
}

String _$bookmarksRepositoryHash() =>
    r'99bea35c4a70f1f2bfdfe51e10c1af14b702b71c';

/// Provider for NIP-17 DM repository.
///
/// Creates a [DmRepository] that handles receiving, decrypting, persisting,
/// and sending encrypted direct messages. Works with any [NostrSigner]
/// (local keys, Keycast RPC, Amber, etc.).
///
/// Sets auth credentials eagerly so read/send operations work immediately,
/// then starts the gift-wrap subscription so DMs are ingested for the whole
/// authenticated session — not just while [InboxPage] is mounted (#2931).
///
/// Cold-start cost is bounded by two existing mechanisms that landed with
/// the original lazy-inbox work (#2766):
/// - The `(newestWireSyncedAt ?? newestSyncedAt) - 2d` filter in
///   [DmRepository.startListening] limits the relay backlog to recent events
///   on every open after the first.
/// - Decryption is offloaded to a background isolate via
///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
///
/// Uses `keepAlive: true` because the repository must survive transient
/// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
/// `nostrServiceProvider` auth-state changes).
///
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.

@ProviderFor(dmReactionsRepository)
final dmReactionsRepositoryProvider = DmReactionsRepositoryProvider._();

/// Provider for NIP-17 DM repository.
///
/// Creates a [DmRepository] that handles receiving, decrypting, persisting,
/// and sending encrypted direct messages. Works with any [NostrSigner]
/// (local keys, Keycast RPC, Amber, etc.).
///
/// Sets auth credentials eagerly so read/send operations work immediately,
/// then starts the gift-wrap subscription so DMs are ingested for the whole
/// authenticated session — not just while [InboxPage] is mounted (#2931).
///
/// Cold-start cost is bounded by two existing mechanisms that landed with
/// the original lazy-inbox work (#2766):
/// - The `(newestWireSyncedAt ?? newestSyncedAt) - 2d` filter in
///   [DmRepository.startListening] limits the relay backlog to recent events
///   on every open after the first.
/// - Decryption is offloaded to a background isolate via
///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
///
/// Uses `keepAlive: true` because the repository must survive transient
/// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
/// `nostrServiceProvider` auth-state changes).
///
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.

final class DmReactionsRepositoryProvider
    extends
        $FunctionalProvider<
          DmReactionsRepository,
          DmReactionsRepository,
          DmReactionsRepository
        >
    with $Provider<DmReactionsRepository> {
  /// Provider for NIP-17 DM repository.
  ///
  /// Creates a [DmRepository] that handles receiving, decrypting, persisting,
  /// and sending encrypted direct messages. Works with any [NostrSigner]
  /// (local keys, Keycast RPC, Amber, etc.).
  ///
  /// Sets auth credentials eagerly so read/send operations work immediately,
  /// then starts the gift-wrap subscription so DMs are ingested for the whole
  /// authenticated session — not just while [InboxPage] is mounted (#2931).
  ///
  /// Cold-start cost is bounded by two existing mechanisms that landed with
  /// the original lazy-inbox work (#2766):
  /// - The `(newestWireSyncedAt ?? newestSyncedAt) - 2d` filter in
  ///   [DmRepository.startListening] limits the relay backlog to recent events
  ///   on every open after the first.
  /// - Decryption is offloaded to a background isolate via
  ///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
  ///
  /// Uses `keepAlive: true` because the repository must survive transient
  /// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
  /// `nostrServiceProvider` auth-state changes).
  ///
  /// Non-nullable: the repository works without keys at construction time.
  /// Read operations return cached/empty data; write operations check keys.
  DmReactionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmReactionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmReactionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<DmReactionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DmReactionsRepository create(Ref ref) {
    return dmReactionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DmReactionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DmReactionsRepository>(value),
    );
  }
}

String _$dmReactionsRepositoryHash() =>
    r'a2dd8d3f7631e76cdc9121cfe5e789bf470ab91d';

/// Provider for [FeedTuningRepository] — publishes swipe "more/less like this"
/// feed-tuning signals.
///
/// Watches only [nostrServiceProvider] (a stable, keepAlive client). The
/// repository reads `publicKey` live at publish time, so it stays correct
/// across auth/signer changes without rebuilding — no `ValueKey` guard is
/// needed at the consumer (rule exception: genuinely stable + reads live
/// state).

@ProviderFor(feedTuningRepository)
final feedTuningRepositoryProvider = FeedTuningRepositoryProvider._();

/// Provider for [FeedTuningRepository] — publishes swipe "more/less like this"
/// feed-tuning signals.
///
/// Watches only [nostrServiceProvider] (a stable, keepAlive client). The
/// repository reads `publicKey` live at publish time, so it stays correct
/// across auth/signer changes without rebuilding — no `ValueKey` guard is
/// needed at the consumer (rule exception: genuinely stable + reads live
/// state).

final class FeedTuningRepositoryProvider
    extends
        $FunctionalProvider<
          FeedTuningRepository,
          FeedTuningRepository,
          FeedTuningRepository
        >
    with $Provider<FeedTuningRepository> {
  /// Provider for [FeedTuningRepository] — publishes swipe "more/less like this"
  /// feed-tuning signals.
  ///
  /// Watches only [nostrServiceProvider] (a stable, keepAlive client). The
  /// repository reads `publicKey` live at publish time, so it stays correct
  /// across auth/signer changes without rebuilding — no `ValueKey` guard is
  /// needed at the consumer (rule exception: genuinely stable + reads live
  /// state).
  FeedTuningRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedTuningRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedTuningRepositoryHash();

  @$internal
  @override
  $ProviderElement<FeedTuningRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeedTuningRepository create(Ref ref) {
    return feedTuningRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedTuningRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedTuningRepository>(value),
    );
  }
}

String _$feedTuningRepositoryHash() =>
    r'463d46ad3800f8558da29ad9b1b95542024ea8b1';

@ProviderFor(dmRepository)
final dmRepositoryProvider = DmRepositoryProvider._();

final class DmRepositoryProvider
    extends $FunctionalProvider<DmRepository, DmRepository, DmRepository>
    with $Provider<DmRepository> {
  DmRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmRepositoryHash();

  @$internal
  @override
  $ProviderElement<DmRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DmRepository create(Ref ref) {
    return dmRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DmRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DmRepository>(value),
    );
  }
}

String _$dmRepositoryHash() => r'd54263d699b3506506cba06ad0e29b94f4452bdc';

/// Provider for CommentsRepository instance
///
/// Creates a CommentsRepository for managing comments on events.
/// Viewing comments works without authentication.
/// Posting comments requires authentication (handled by AuthService in BLoC).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)

@ProviderFor(commentsRepository)
final commentsRepositoryProvider = CommentsRepositoryProvider._();

/// Provider for CommentsRepository instance
///
/// Creates a CommentsRepository for managing comments on events.
/// Viewing comments works without authentication.
/// Posting comments requires authentication (handled by AuthService in BLoC).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)

final class CommentsRepositoryProvider
    extends
        $FunctionalProvider<
          CommentsRepository,
          CommentsRepository,
          CommentsRepository
        >
    with $Provider<CommentsRepository> {
  /// Provider for CommentsRepository instance
  ///
  /// Creates a CommentsRepository for managing comments on events.
  /// Viewing comments works without authentication.
  /// Posting comments requires authentication (handled by AuthService in BLoC).
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  CommentsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<CommentsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommentsRepository create(Ref ref) {
    return commentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentsRepository>(value),
    );
  }
}

String _$commentsRepositoryHash() =>
    r'21b8d5931408335180c18406e3aa033c6f15b448';
