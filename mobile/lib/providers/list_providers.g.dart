// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for all user lists (kind 30000 - people lists)

@ProviderFor(userLists)
const userListsProvider = UserListsProvider._();

/// Provider for all user lists (kind 30000 - people lists)

final class UserListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UserList>>,
          List<UserList>,
          FutureOr<List<UserList>>
        >
    with $FutureModifier<List<UserList>>, $FutureProvider<List<UserList>> {
  /// Provider for all user lists (kind 30000 - people lists)
  const UserListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userListsHash();

  @$internal
  @override
  $FutureProviderElement<List<UserList>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UserList>> create(Ref ref) {
    return userLists(ref);
  }
}

String _$userListsHash() => r'dc1bef2ba8574f8c26a348c27b5cdb0d7aff077f';

/// Provider for all curated video lists (kind 30005)

@ProviderFor(curatedLists)
const curatedListsProvider = CuratedListsProvider._();

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
  const CuratedListsProvider._()
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

String _$curatedListsHash() => r'5d299cccc88df3a9b075edf11d7c0bf06a2703f8';

/// Combined provider for both types of lists

@ProviderFor(allLists)
const allListsProvider = AllListsProvider._();

/// Combined provider for both types of lists

final class AllListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<
            ({List<CuratedList> curatedLists, List<UserList> userLists})
          >,
          ({List<CuratedList> curatedLists, List<UserList> userLists}),
          FutureOr<({List<CuratedList> curatedLists, List<UserList> userLists})>
        >
    with
        $FutureModifier<
          ({List<CuratedList> curatedLists, List<UserList> userLists})
        >,
        $FutureProvider<
          ({List<CuratedList> curatedLists, List<UserList> userLists})
        > {
  /// Combined provider for both types of lists
  const AllListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allListsHash();

  @$internal
  @override
  $FutureProviderElement<
    ({List<CuratedList> curatedLists, List<UserList> userLists})
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({List<CuratedList> curatedLists, List<UserList> userLists})> create(
    Ref ref,
  ) {
    return allLists(ref);
  }
}

String _$allListsHash() => r'8d7c4fb84d445151d5bb84764da34cedf4e7e8a6';

/// Provider for videos in a specific curated list

@ProviderFor(curatedListVideos)
const curatedListVideosProvider = CuratedListVideosFamily._();

/// Provider for videos in a specific curated list

final class CuratedListVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Provider for videos in a specific curated list
  const CuratedListVideosProvider._({
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

String _$curatedListVideosHash() => r'169a900d5e9fb23b8f8f33a76e026fe7b846d052';

/// Provider for videos in a specific curated list

final class CuratedListVideosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  const CuratedListVideosFamily._()
    : super(
        retry: null,
        name: r'curatedListVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for videos in a specific curated list

  CuratedListVideosProvider call(String listId) =>
      CuratedListVideosProvider._(argument: listId, from: this);

  @override
  String toString() => r'curatedListVideosProvider';
}

/// Provider for videos from all members of a user list

@ProviderFor(userListMemberVideos)
const userListMemberVideosProvider = UserListMemberVideosFamily._();

/// Provider for videos from all members of a user list

final class UserListMemberVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider for videos from all members of a user list
  const UserListMemberVideosProvider._({
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
    r'005a02b0974013a6cc82aec093a1e17cf5cc4020';

/// Provider for videos from all members of a user list

final class UserListMemberVideosFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, List<String>> {
  const UserListMemberVideosFamily._()
    : super(
        retry: null,
        name: r'userListMemberVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for videos from all members of a user list

  UserListMemberVideosProvider call(List<String> pubkeys) =>
      UserListMemberVideosProvider._(argument: pubkeys, from: this);

  @override
  String toString() => r'userListMemberVideosProvider';
}

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

@ProviderFor(publicListsContainingVideo)
const publicListsContainingVideoProvider = PublicListsContainingVideoFamily._();

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
  const PublicListsContainingVideoProvider._({
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
    r'3b529d01bfb47dba5d78907674eb3cc28939c8ba';

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

final class PublicListsContainingVideoFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<CuratedList>>, String> {
  const PublicListsContainingVideoFamily._()
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
