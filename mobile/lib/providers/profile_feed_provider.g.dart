// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent cursor tracking.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```

@ProviderFor(ProfileFeed)
const profileFeedProvider = ProfileFeedFamily._();

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent cursor tracking.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```
final class ProfileFeedProvider
    extends $AsyncNotifierProvider<ProfileFeed, VideoFeedState> {
  /// Profile feed provider - shows videos for a specific user with pagination
  ///
  /// This is a family provider, so each userId gets its own provider instance
  /// with independent cursor tracking.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileFeedProvider(userId));
  /// await ref.read(profileFeedProvider(userId).notifier).loadMore();
  /// ```
  const ProfileFeedProvider._({
    required ProfileFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileFeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileFeedHash();

  @override
  String toString() {
    return r'profileFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileFeed create() => ProfileFeed();

  @override
  bool operator ==(Object other) {
    return other is ProfileFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileFeedHash() => r'63a65d83868cc65d7f7d2e8524b4d0ed46f21e14';

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent cursor tracking.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```

final class ProfileFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileFeed,
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>,
          String
        > {
  const ProfileFeedFamily._()
    : super(
        retry: null,
        name: r'profileFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Profile feed provider - shows videos for a specific user with pagination
  ///
  /// This is a family provider, so each userId gets its own provider instance
  /// with independent cursor tracking.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileFeedProvider(userId));
  /// await ref.read(profileFeedProvider(userId).notifier).loadMore();
  /// ```

  ProfileFeedProvider call(String userId) =>
      ProfileFeedProvider._(argument: userId, from: this);

  @override
  String toString() => r'profileFeedProvider';
}

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent cursor tracking.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```

abstract class _$ProfileFeed extends $AsyncNotifier<VideoFeedState> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  FutureOr<VideoFeedState> build(String userId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
