// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for all curated video lists (kind 30005)

@ProviderFor(curatedLists)
final curatedListsProvider = CuratedListsProvider._();

/// Provider for all curated video lists (kind 30005)

final class CuratedListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CuratedList>>,
          List<CuratedList>,
          FutureOr<List<CuratedList>>
        >
    with
        $FutureModifier<List<CuratedList>>,
        $FutureProvider<List<CuratedList>> {
  /// Provider for all curated video lists (kind 30005)
  CuratedListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListsHash();

  @$internal
  @override
  $FutureProviderElement<List<CuratedList>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CuratedList>> create(Ref ref) {
    return curatedLists(ref);
  }
}

String _$curatedListsHash() => r'74de3f9b86d5444e78e7f2c797370ca75f29f9f5';

/// State class for discovered public lists
/// Provider for videos in a specific curated list

@ProviderFor(curatedListVideos)
final curatedListVideosProvider = CuratedListVideosFamily._();

/// State class for discovered public lists
/// Provider for videos in a specific curated list

final class CuratedListVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// State class for discovered public lists
  /// Provider for videos in a specific curated list
  CuratedListVideosProvider._({
    required CuratedListVideosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'curatedListVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curatedListVideosHash();

  @override
  String toString() {
    return r'curatedListVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return curatedListVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CuratedListVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curatedListVideosHash() => r'ce7db4b5ea59279d88325cdc9e928dc5a89a92b0';

/// State class for discovered public lists
/// Provider for videos in a specific curated list

final class CuratedListVideosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  CuratedListVideosFamily._()
    : super(
        retry: null,
        name: r'curatedListVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// State class for discovered public lists
  /// Provider for videos in a specific curated list

  CuratedListVideosProvider call(String listId) =>
      CuratedListVideosProvider._(argument: listId, from: this);

  @override
  String toString() => r'curatedListVideosProvider';
}

/// Provider for videos from all members of a user list
///
/// The body is a plain function so every `Ref` read happens synchronously
/// during `build` — see [_LiveDeps] for why an `async*` body cannot
/// touch `Ref`.

@ProviderFor(userListMemberVideos)
final userListMemberVideosProvider = UserListMemberVideosFamily._();

/// Provider for videos from all members of a user list
///
/// The body is a plain function so every `Ref` read happens synchronously
/// during `build` — see [_LiveDeps] for why an `async*` body cannot
/// touch `Ref`.

final class UserListMemberVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider for videos from all members of a user list
  ///
  /// The body is a plain function so every `Ref` read happens synchronously
  /// during `build` — see [_LiveDeps] for why an `async*` body cannot
  /// touch `Ref`.
  UserListMemberVideosProvider._({
    required UserListMemberVideosFamily super.from,
    required List<String> super.argument,
  }) : super(
         retry: null,
         name: r'userListMemberVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userListMemberVideosHash();

  @override
  String toString() {
    return r'userListMemberVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as List<String>;
    return userListMemberVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserListMemberVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userListMemberVideosHash() =>
    r'acb78c2d384c7425a9ecc45210b60fb0f764ed31';

/// Provider for videos from all members of a user list
///
/// The body is a plain function so every `Ref` read happens synchronously
/// during `build` — see [_LiveDeps] for why an `async*` body cannot
/// touch `Ref`.

final class UserListMemberVideosFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, List<String>> {
  UserListMemberVideosFamily._()
    : super(
        retry: null,
        name: r'userListMemberVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for videos from all members of a user list
  ///
  /// The body is a plain function so every `Ref` read happens synchronously
  /// during `build` — see [_LiveDeps] for why an `async*` body cannot
  /// touch `Ref`.

  UserListMemberVideosProvider call(List<String> pubkeys) =>
      UserListMemberVideosProvider._(argument: pubkeys, from: this);

  @override
  String toString() => r'userListMemberVideosProvider';
}

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

@ProviderFor(publicListsContainingVideo)
final publicListsContainingVideoProvider = PublicListsContainingVideoFamily._();

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

final class PublicListsContainingVideoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CuratedList>>,
          List<CuratedList>,
          Stream<List<CuratedList>>
        >
    with
        $FutureModifier<List<CuratedList>>,
        $StreamProvider<List<CuratedList>> {
  /// Provider that streams public lists containing a specific video
  /// Accumulates results as they arrive from Nostr relays, yielding updated list
  /// on each new result. This enables progressive UI updates via Riverpod.
  PublicListsContainingVideoProvider._({
    required PublicListsContainingVideoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'publicListsContainingVideoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicListsContainingVideoHash();

  @override
  String toString() {
    return r'publicListsContainingVideoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<CuratedList>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CuratedList>> create(Ref ref) {
    final argument = this.argument as String;
    return publicListsContainingVideo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PublicListsContainingVideoProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicListsContainingVideoHash() =>
    r'b8c596353975f2448715a57f63e10f048a273fd3';

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

final class PublicListsContainingVideoFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<CuratedList>>, String> {
  PublicListsContainingVideoFamily._()
    : super(
        retry: null,
        name: r'publicListsContainingVideoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that streams public lists containing a specific video
  /// Accumulates results as they arrive from Nostr relays, yielding updated list
  /// on each new result. This enables progressive UI updates via Riverpod.

  PublicListsContainingVideoProvider call(String videoId) =>
      PublicListsContainingVideoProvider._(argument: videoId, from: this);

  @override
  String toString() => r'publicListsContainingVideoProvider';
}

/// Provider that fetches a public curated list (kind 30005) by author +
/// d-tag for the `/list/:pubkey/:listId` universal-link route.
///
/// Unlike [curatedListVideos], this does not require the list to be in
/// local storage — it resolves from cache + relays, so deep links to lists
/// the user has never seen still work. Returns `null` when no matching
/// list event exists.

@ProviderFor(publicCuratedList)
final publicCuratedListProvider = PublicCuratedListFamily._();

/// Provider that fetches a public curated list (kind 30005) by author +
/// d-tag for the `/list/:pubkey/:listId` universal-link route.
///
/// Unlike [curatedListVideos], this does not require the list to be in
/// local storage — it resolves from cache + relays, so deep links to lists
/// the user has never seen still work. Returns `null` when no matching
/// list event exists.

final class PublicCuratedListProvider
    extends
        $FunctionalProvider<
          AsyncValue<CuratedList?>,
          CuratedList?,
          FutureOr<CuratedList?>
        >
    with $FutureModifier<CuratedList?>, $FutureProvider<CuratedList?> {
  /// Provider that fetches a public curated list (kind 30005) by author +
  /// d-tag for the `/list/:pubkey/:listId` universal-link route.
  ///
  /// Unlike [curatedListVideos], this does not require the list to be in
  /// local storage — it resolves from cache + relays, so deep links to lists
  /// the user has never seen still work. Returns `null` when no matching
  /// list event exists.
  PublicCuratedListProvider._({
    required PublicCuratedListFamily super.from,
    required ({String authorPubkey, String listId}) super.argument,
  }) : super(
         retry: null,
         name: r'publicCuratedListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicCuratedListHash();

  @override
  String toString() {
    return r'publicCuratedListProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CuratedList?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CuratedList?> create(Ref ref) {
    final argument = this.argument as ({String authorPubkey, String listId});
    return publicCuratedList(
      ref,
      authorPubkey: argument.authorPubkey,
      listId: argument.listId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PublicCuratedListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicCuratedListHash() => r'2b8f4915387aa7b0954908543571a9c780921860';

/// Provider that fetches a public curated list (kind 30005) by author +
/// d-tag for the `/list/:pubkey/:listId` universal-link route.
///
/// Unlike [curatedListVideos], this does not require the list to be in
/// local storage — it resolves from cache + relays, so deep links to lists
/// the user has never seen still work. Returns `null` when no matching
/// list event exists.

final class PublicCuratedListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CuratedList?>,
          ({String authorPubkey, String listId})
        > {
  PublicCuratedListFamily._()
    : super(
        retry: null,
        name: r'publicCuratedListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that fetches a public curated list (kind 30005) by author +
  /// d-tag for the `/list/:pubkey/:listId` universal-link route.
  ///
  /// Unlike [curatedListVideos], this does not require the list to be in
  /// local storage — it resolves from cache + relays, so deep links to lists
  /// the user has never seen still work. Returns `null` when no matching
  /// list event exists.

  PublicCuratedListProvider call({
    required String authorPubkey,
    required String listId,
  }) => PublicCuratedListProvider._(
    argument: (authorPubkey: authorPubkey, listId: listId),
    from: this,
  );

  @override
  String toString() => r'publicCuratedListProvider';
}

/// Resolves a discovered public people list by author + d-tag from relays.
///
/// The owner-scoped [PeopleListsBloc] only holds the viewer's own lists, so
/// discovery cards and deep links to someone else's list resolve through
/// this instead.

@ProviderFor(publicPeopleList)
final publicPeopleListProvider = PublicPeopleListFamily._();

/// Resolves a discovered public people list by author + d-tag from relays.
///
/// The owner-scoped [PeopleListsBloc] only holds the viewer's own lists, so
/// discovery cards and deep links to someone else's list resolve through
/// this instead.

final class PublicPeopleListProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserList?>,
          UserList?,
          FutureOr<UserList?>
        >
    with $FutureModifier<UserList?>, $FutureProvider<UserList?> {
  /// Resolves a discovered public people list by author + d-tag from relays.
  ///
  /// The owner-scoped [PeopleListsBloc] only holds the viewer's own lists, so
  /// discovery cards and deep links to someone else's list resolve through
  /// this instead.
  PublicPeopleListProvider._({
    required PublicPeopleListFamily super.from,
    required ({String ownerPubkey, String listId}) super.argument,
  }) : super(
         retry: null,
         name: r'publicPeopleListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicPeopleListHash();

  @override
  String toString() {
    return r'publicPeopleListProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<UserList?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UserList?> create(Ref ref) {
    final argument = this.argument as ({String ownerPubkey, String listId});
    return publicPeopleList(
      ref,
      ownerPubkey: argument.ownerPubkey,
      listId: argument.listId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PublicPeopleListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicPeopleListHash() => r'986437af516d1010431e1fc765d9e51a035d8413';

/// Resolves a discovered public people list by author + d-tag from relays.
///
/// The owner-scoped [PeopleListsBloc] only holds the viewer's own lists, so
/// discovery cards and deep links to someone else's list resolve through
/// this instead.

final class PublicPeopleListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<UserList?>,
          ({String ownerPubkey, String listId})
        > {
  PublicPeopleListFamily._()
    : super(
        retry: null,
        name: r'publicPeopleListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves a discovered public people list by author + d-tag from relays.
  ///
  /// The owner-scoped [PeopleListsBloc] only holds the viewer's own lists, so
  /// discovery cards and deep links to someone else's list resolve through
  /// this instead.

  PublicPeopleListProvider call({
    required String ownerPubkey,
    required String listId,
  }) => PublicPeopleListProvider._(
    argument: (ownerPubkey: ownerPubkey, listId: listId),
    from: this,
  );

  @override
  String toString() => r'publicPeopleListProvider';
}

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays
///
/// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
/// this provider is the one that matters most, because
/// `curated_list_feed_screen` calls
/// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
/// which disposes the previous build while it is still awaiting relays.

@ProviderFor(curatedListVideoEvents)
final curatedListVideoEventsProvider = CuratedListVideoEventsFamily._();

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays
///
/// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
/// this provider is the one that matters most, because
/// `curated_list_feed_screen` calls
/// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
/// which disposes the previous build while it is still awaiting relays.

final class CuratedListVideoEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider that fetches actual VideoEvent objects for a curated list
  /// Streams videos as they are fetched from cache or relays
  ///
  /// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
  /// this provider is the one that matters most, because
  /// `curated_list_feed_screen` calls
  /// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
  /// which disposes the previous build while it is still awaiting relays.
  CuratedListVideoEventsProvider._({
    required CuratedListVideoEventsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'curatedListVideoEventsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curatedListVideoEventsHash();

  @override
  String toString() {
    return r'curatedListVideoEventsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return curatedListVideoEvents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CuratedListVideoEventsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curatedListVideoEventsHash() =>
    r'9f195da0426a9a6a75e2dfd097b6b9ec1410010b';

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays
///
/// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
/// this provider is the one that matters most, because
/// `curated_list_feed_screen` calls
/// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
/// which disposes the previous build while it is still awaiting relays.

final class CuratedListVideoEventsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, String> {
  CuratedListVideoEventsFamily._()
    : super(
        retry: null,
        name: r'curatedListVideoEventsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that fetches actual VideoEvent objects for a curated list
  /// Streams videos as they are fetched from cache or relays
  ///
  /// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
  /// this provider is the one that matters most, because
  /// `curated_list_feed_screen` calls
  /// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
  /// which disposes the previous build while it is still awaiting relays.

  CuratedListVideoEventsProvider call(String listId) =>
      CuratedListVideoEventsProvider._(argument: listId, from: this);

  @override
  String toString() => r'curatedListVideoEventsProvider';
}

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage
///
/// The body is a plain function, and the reads it needs after an `await` go
/// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.

@ProviderFor(videoEventsByIds)
final videoEventsByIdsProvider = VideoEventsByIdsFamily._();

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage
///
/// The body is a plain function, and the reads it needs after an `await` go
/// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.

final class VideoEventsByIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider that fetches VideoEvent objects directly from a list of video IDs
  /// Use this for discovered lists that aren't in local storage
  ///
  /// The body is a plain function, and the reads it needs after an `await` go
  /// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.
  VideoEventsByIdsProvider._({
    required VideoEventsByIdsFamily super.from,
    required List<String> super.argument,
  }) : super(
         retry: null,
         name: r'videoEventsByIdsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoEventsByIdsHash();

  @override
  String toString() {
    return r'videoEventsByIdsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as List<String>;
    return videoEventsByIds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoEventsByIdsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoEventsByIdsHash() => r'71472b817b86016d74247fcb6288e252abf97cbf';

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage
///
/// The body is a plain function, and the reads it needs after an `await` go
/// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.

final class VideoEventsByIdsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, List<String>> {
  VideoEventsByIdsFamily._()
    : super(
        retry: null,
        name: r'videoEventsByIdsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that fetches VideoEvent objects directly from a list of video IDs
  /// Use this for discovered lists that aren't in local storage
  ///
  /// The body is a plain function, and the reads it needs after an `await` go
  /// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.

  VideoEventsByIdsProvider call(List<String> videoIds) =>
      VideoEventsByIdsProvider._(argument: videoIds, from: this);

  @override
  String toString() => r'videoEventsByIdsProvider';
}
