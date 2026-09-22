// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The author's lifetime stats for a feed card, auto-disposing and
/// cache-first.
///
/// The card prints one author's lifetime loop total beside their name, and a
/// scroll through the feed mounts many distinct authors. The shared
/// [userProfileStatsReactiveProvider] is a non-auto-disposing family whose
/// stream fetches before it watches, so a card using it would both start a
/// fresh profile fetch per distinct author and leave that author's Drift
/// watcher alive for the rest of the session (#9431). This provider is scoped
/// to the card: `@riverpod` makes it auto-dispose, so the watcher is released
/// when the card leaves the tree, and a fresh cached row short-circuits the
/// fetch so re-mounting a card does not re-fetch.

@ProviderFor(videoCardAuthorStats)
final videoCardAuthorStatsProvider = VideoCardAuthorStatsFamily._();

/// The author's lifetime stats for a feed card, auto-disposing and
/// cache-first.
///
/// The card prints one author's lifetime loop total beside their name, and a
/// scroll through the feed mounts many distinct authors. The shared
/// [userProfileStatsReactiveProvider] is a non-auto-disposing family whose
/// stream fetches before it watches, so a card using it would both start a
/// fresh profile fetch per distinct author and leave that author's Drift
/// watcher alive for the rest of the session (#9431). This provider is scoped
/// to the card: `@riverpod` makes it auto-dispose, so the watcher is released
/// when the card leaves the tree, and a fresh cached row short-circuits the
/// fetch so re-mounting a card does not re-fetch.

final class VideoCardAuthorStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileStats?>,
          ProfileStats?,
          Stream<ProfileStats?>
        >
    with $FutureModifier<ProfileStats?>, $StreamProvider<ProfileStats?> {
  /// The author's lifetime stats for a feed card, auto-disposing and
  /// cache-first.
  ///
  /// The card prints one author's lifetime loop total beside their name, and a
  /// scroll through the feed mounts many distinct authors. The shared
  /// [userProfileStatsReactiveProvider] is a non-auto-disposing family whose
  /// stream fetches before it watches, so a card using it would both start a
  /// fresh profile fetch per distinct author and leave that author's Drift
  /// watcher alive for the rest of the session (#9431). This provider is scoped
  /// to the card: `@riverpod` makes it auto-dispose, so the watcher is released
  /// when the card leaves the tree, and a fresh cached row short-circuits the
  /// fetch so re-mounting a card does not re-fetch.
  VideoCardAuthorStatsProvider._({
    required VideoCardAuthorStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'videoCardAuthorStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoCardAuthorStatsHash();

  @override
  String toString() {
    return r'videoCardAuthorStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ProfileStats?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ProfileStats?> create(Ref ref) {
    final argument = this.argument as String;
    return videoCardAuthorStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoCardAuthorStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoCardAuthorStatsHash() =>
    r'799921ca92acce42ca7a4db1d946b692bb3de4ce';

/// The author's lifetime stats for a feed card, auto-disposing and
/// cache-first.
///
/// The card prints one author's lifetime loop total beside their name, and a
/// scroll through the feed mounts many distinct authors. The shared
/// [userProfileStatsReactiveProvider] is a non-auto-disposing family whose
/// stream fetches before it watches, so a card using it would both start a
/// fresh profile fetch per distinct author and leave that author's Drift
/// watcher alive for the rest of the session (#9431). This provider is scoped
/// to the card: `@riverpod` makes it auto-dispose, so the watcher is released
/// when the card leaves the tree, and a fresh cached row short-circuits the
/// fetch so re-mounting a card does not re-fetch.

final class VideoCardAuthorStatsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ProfileStats?>, String> {
  VideoCardAuthorStatsFamily._()
    : super(
        retry: null,
        name: r'videoCardAuthorStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The author's lifetime stats for a feed card, auto-disposing and
  /// cache-first.
  ///
  /// The card prints one author's lifetime loop total beside their name, and a
  /// scroll through the feed mounts many distinct authors. The shared
  /// [userProfileStatsReactiveProvider] is a non-auto-disposing family whose
  /// stream fetches before it watches, so a card using it would both start a
  /// fresh profile fetch per distinct author and leave that author's Drift
  /// watcher alive for the rest of the session (#9431). This provider is scoped
  /// to the card: `@riverpod` makes it auto-dispose, so the watcher is released
  /// when the card leaves the tree, and a fresh cached row short-circuits the
  /// fetch so re-mounting a card does not re-fetch.

  VideoCardAuthorStatsProvider call(String pubkey) =>
      VideoCardAuthorStatsProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'videoCardAuthorStatsProvider';
}

/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.
///
/// Reads through [profileReadRepositoryProvider], which is available at the
/// identity-known phase. Waiting for the relay-connect settle here is what
/// made the signed-in user's own header render a generated fallback name for
/// the whole cold-start window (#6423); nothing on this path signs.

@ProviderFor(userProfileReactive)
final userProfileReactiveProvider = UserProfileReactiveFamily._();

/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.
///
/// Reads through [profileReadRepositoryProvider], which is available at the
/// identity-known phase. Waiting for the relay-connect settle here is what
/// made the signed-in user's own header render a generated fallback name for
/// the whole cold-start window (#6423); nothing on this path signs.

final class UserProfileReactiveProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          Stream<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $StreamProvider<UserProfile?> {
  /// Reactive profile provider backed by Drift's watchProfile stream.
  ///
  /// On first access for a pubkey:
  /// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
  /// 2. Yields from the Drift watch stream, so any cache update (from fetch,
  ///    profile edit, or batch prefetch) automatically flows to consumers.
  ///
  /// Consumers get `AsyncValue<UserProfile?>` — same API as the old
  /// FutureProvider, so widget code changes are minimal.
  ///
  /// Reads through [profileReadRepositoryProvider], which is available at the
  /// identity-known phase. Waiting for the relay-connect settle here is what
  /// made the signed-in user's own header render a generated fallback name for
  /// the whole cold-start window (#6423); nothing on this path signs.
  UserProfileReactiveProvider._({
    required UserProfileReactiveFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userProfileReactiveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userProfileReactiveHash();

  @override
  String toString() {
    return r'userProfileReactiveProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return userProfileReactive(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileReactiveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userProfileReactiveHash() =>
    r'a3c10ea57bfa00094e9bb26d62e8dcd93312435e';

/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.
///
/// Reads through [profileReadRepositoryProvider], which is available at the
/// identity-known phase. Waiting for the relay-connect settle here is what
/// made the signed-in user's own header render a generated fallback name for
/// the whole cold-start window (#6423); nothing on this path signs.

final class UserProfileReactiveFamily extends $Family
    with $FunctionalFamilyOverride<Stream<UserProfile?>, String> {
  UserProfileReactiveFamily._()
    : super(
        retry: null,
        name: r'userProfileReactiveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reactive profile provider backed by Drift's watchProfile stream.
  ///
  /// On first access for a pubkey:
  /// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
  /// 2. Yields from the Drift watch stream, so any cache update (from fetch,
  ///    profile edit, or batch prefetch) automatically flows to consumers.
  ///
  /// Consumers get `AsyncValue<UserProfile?>` — same API as the old
  /// FutureProvider, so widget code changes are minimal.
  ///
  /// Reads through [profileReadRepositoryProvider], which is available at the
  /// identity-known phase. Waiting for the relay-connect settle here is what
  /// made the signed-in user's own header render a generated fallback name for
  /// the whole cold-start window (#6423); nothing on this path signs.

  UserProfileReactiveProvider call(String pubkey) =>
      UserProfileReactiveProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'userProfileReactiveProvider';
}

/// Resolves profiles for the accounts the viewer has blocked.
///
/// Fetching the set in bounded batches avoids starting a REST request plus two
/// relay queries for every uncached row when a synced mute list is large.

@ProviderFor(blockedUserProfiles)
final blockedUserProfilesProvider = BlockedUserProfilesFamily._();

/// Resolves profiles for the accounts the viewer has blocked.
///
/// Fetching the set in bounded batches avoids starting a REST request plus two
/// relay queries for every uncached row when a synced mute list is large.

final class BlockedUserProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, UserProfile>>,
          Map<String, UserProfile>,
          FutureOr<Map<String, UserProfile>>
        >
    with
        $FutureModifier<Map<String, UserProfile>>,
        $FutureProvider<Map<String, UserProfile>> {
  /// Resolves profiles for the accounts the viewer has blocked.
  ///
  /// Fetching the set in bounded batches avoids starting a REST request plus two
  /// relay queries for every uncached row when a synced mute list is large.
  BlockedUserProfilesProvider._({
    required BlockedUserProfilesFamily super.from,
    required Set<String> super.argument,
  }) : super(
         retry: null,
         name: r'blockedUserProfilesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blockedUserProfilesHash();

  @override
  String toString() {
    return r'blockedUserProfilesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, UserProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, UserProfile>> create(Ref ref) {
    final argument = this.argument as Set<String>;
    return blockedUserProfiles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BlockedUserProfilesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blockedUserProfilesHash() =>
    r'85f3707aa089783ffa55e4854d874a4a7bd3b68f';

/// Resolves profiles for the accounts the viewer has blocked.
///
/// Fetching the set in bounded batches avoids starting a REST request plus two
/// relay queries for every uncached row when a synced mute list is large.

final class BlockedUserProfilesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, UserProfile>>,
          Set<String>
        > {
  BlockedUserProfilesFamily._()
    : super(
        retry: null,
        name: r'blockedUserProfilesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves profiles for the accounts the viewer has blocked.
  ///
  /// Fetching the set in bounded batches avoids starting a REST request plus two
  /// relay queries for every uncached row when a synced mute list is large.

  BlockedUserProfilesProvider call(Set<String> pubkeys) =>
      BlockedUserProfilesProvider._(argument: pubkeys, from: this);

  @override
  String toString() => r'blockedUserProfilesProvider';
}

/// Watches a blocked account's cached profile without starting another fetch.
///
/// [blockedUserProfiles] hydrates the cache in bounded batches; this provider
/// keeps each tile reactive to that hydration and later profile updates.

@ProviderFor(blockedUserProfile)
final blockedUserProfileProvider = BlockedUserProfileFamily._();

/// Watches a blocked account's cached profile without starting another fetch.
///
/// [blockedUserProfiles] hydrates the cache in bounded batches; this provider
/// keeps each tile reactive to that hydration and later profile updates.

final class BlockedUserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          Stream<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $StreamProvider<UserProfile?> {
  /// Watches a blocked account's cached profile without starting another fetch.
  ///
  /// [blockedUserProfiles] hydrates the cache in bounded batches; this provider
  /// keeps each tile reactive to that hydration and later profile updates.
  BlockedUserProfileProvider._({
    required BlockedUserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'blockedUserProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blockedUserProfileHash();

  @override
  String toString() {
    return r'blockedUserProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return blockedUserProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BlockedUserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blockedUserProfileHash() =>
    r'939f57fd466b49999d7e73e97937c0660e1e1d77';

/// Watches a blocked account's cached profile without starting another fetch.
///
/// [blockedUserProfiles] hydrates the cache in bounded batches; this provider
/// keeps each tile reactive to that hydration and later profile updates.

final class BlockedUserProfileFamily extends $Family
    with $FunctionalFamilyOverride<Stream<UserProfile?>, String> {
  BlockedUserProfileFamily._()
    : super(
        retry: null,
        name: r'blockedUserProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Watches a blocked account's cached profile without starting another fetch.
  ///
  /// [blockedUserProfiles] hydrates the cache in bounded batches; this provider
  /// keeps each tile reactive to that hydration and later profile updates.

  BlockedUserProfileProvider call(String pubkey) =>
      BlockedUserProfileProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'blockedUserProfileProvider';
}

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.
///
/// Same read gate as [userProfileReactive] — both paths are signer-free.

@ProviderFor(fetchUserProfile)
final fetchUserProfileProvider = FetchUserProfileFamily._();

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.
///
/// Same read gate as [userProfileReactive] — both paths are signer-free.

final class FetchUserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          FutureOr<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $FutureProvider<UserProfile?> {
  /// One-shot provider: returns cached profile or fetches fresh.
  ///
  /// Use this when you need a single read (e.g., building a share sheet)
  /// rather than a reactive stream.
  ///
  /// Same read gate as [userProfileReactive] — both paths are signer-free.
  FetchUserProfileProvider._({
    required FetchUserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fetchUserProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fetchUserProfileHash();

  @override
  String toString() {
    return r'fetchUserProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return fetchUserProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FetchUserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fetchUserProfileHash() => r'83353a4223c0c0ca7feee6e08c2f8116ca551c66';

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.
///
/// Same read gate as [userProfileReactive] — both paths are signer-free.

final class FetchUserProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UserProfile?>, String> {
  FetchUserProfileFamily._()
    : super(
        retry: null,
        name: r'fetchUserProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One-shot provider: returns cached profile or fetches fresh.
  ///
  /// Use this when you need a single read (e.g., building a share sheet)
  /// rather than a reactive stream.
  ///
  /// Same read gate as [userProfileReactive] — both paths are signer-free.

  FetchUserProfileProvider call(String pubkey) =>
      FetchUserProfileProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'fetchUserProfileProvider';
}

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.
///
/// Reports `false` until [vanishedProfilePubkeysProvider] first emits. That
/// window belongs to the source stream, so returning a `Stream<bool>` would
/// not shorten it — only wrap it in a second, per-pubkey `AsyncLoading`.
/// Building the profile repository subscribes the source, so the wait starts
/// no later than the moment the profile graph can leave `isLoading`; that
/// ordering is what keeps a vanished account from rendering a generated name
/// first (#8208), and `repository_providers_test.dart` pins it.

@ProviderFor(profileVanished)
final profileVanishedProvider = ProfileVanishedFamily._();

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.
///
/// Reports `false` until [vanishedProfilePubkeysProvider] first emits. That
/// window belongs to the source stream, so returning a `Stream<bool>` would
/// not shorten it — only wrap it in a second, per-pubkey `AsyncLoading`.
/// Building the profile repository subscribes the source, so the wait starts
/// no later than the moment the profile graph can leave `isLoading`; that
/// ordering is what keeps a vanished account from rendering a generated name
/// first (#8208), and `repository_providers_test.dart` pins it.

final class ProfileVanishedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the account behind [pubkey] has requested NIP-62 deletion.
  ///
  /// Backed by the durable `vanished_profiles` table, so a cold start resolves
  /// without a network round trip, and it flips live when a fetch discovers a
  /// new deletion. This — not the profile provider — drives the deleted-account
  /// treatment in the inbox and the following bar.
  ///
  /// Reports `false` until [vanishedProfilePubkeysProvider] first emits. That
  /// window belongs to the source stream, so returning a `Stream<bool>` would
  /// not shorten it — only wrap it in a second, per-pubkey `AsyncLoading`.
  /// Building the profile repository subscribes the source, so the wait starts
  /// no later than the moment the profile graph can leave `isLoading`; that
  /// ordering is what keeps a vanished account from rendering a generated name
  /// first (#8208), and `repository_providers_test.dart` pins it.
  ProfileVanishedProvider._({
    required ProfileVanishedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileVanishedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileVanishedHash();

  @override
  String toString() {
    return r'profileVanishedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return profileVanished(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileVanishedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileVanishedHash() => r'29720937045a4363d508c27d1a2bf503d6f41bf7';

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.
///
/// Reports `false` until [vanishedProfilePubkeysProvider] first emits. That
/// window belongs to the source stream, so returning a `Stream<bool>` would
/// not shorten it — only wrap it in a second, per-pubkey `AsyncLoading`.
/// Building the profile repository subscribes the source, so the wait starts
/// no later than the moment the profile graph can leave `isLoading`; that
/// ordering is what keeps a vanished account from rendering a generated name
/// first (#8208), and `repository_providers_test.dart` pins it.

final class ProfileVanishedFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  ProfileVanishedFamily._()
    : super(
        retry: null,
        name: r'profileVanishedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether the account behind [pubkey] has requested NIP-62 deletion.
  ///
  /// Backed by the durable `vanished_profiles` table, so a cold start resolves
  /// without a network round trip, and it flips live when a fetch discovers a
  /// new deletion. This — not the profile provider — drives the deleted-account
  /// treatment in the inbox and the following bar.
  ///
  /// Reports `false` until [vanishedProfilePubkeysProvider] first emits. That
  /// window belongs to the source stream, so returning a `Stream<bool>` would
  /// not shorten it — only wrap it in a second, per-pubkey `AsyncLoading`.
  /// Building the profile repository subscribes the source, so the wait starts
  /// no later than the moment the profile graph can leave `isLoading`; that
  /// ordering is what keeps a vanished account from rendering a generated name
  /// first (#8208), and `repository_providers_test.dart` pins it.

  ProfileVanishedProvider call(String pubkey) =>
      ProfileVanishedProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'profileVanishedProvider';
}
