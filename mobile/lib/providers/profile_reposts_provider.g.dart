// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_reposts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that returns only the videos a user has reposted
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == true
/// - reposterPubkey == userIdHex

@ProviderFor(profileReposts)
const profileRepostsProvider = ProfileRepostsFamily._();

/// Provider that returns only the videos a user has reposted
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == true
/// - reposterPubkey == userIdHex

final class ProfileRepostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          FutureOr<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $FutureProvider<List<VideoEvent>> {
  /// Provider that returns only the videos a user has reposted
  ///
  /// Watches the profile feed provider and filters for videos where:
  /// - isRepost == true
  /// - reposterPubkey == userIdHex
  const ProfileRepostsProvider._({
    required ProfileRepostsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileRepostsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileRepostsHash();

  @override
  String toString() {
    return r'profileRepostsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return profileReposts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileRepostsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileRepostsHash() => r'96b8492dfca33eab83570a9e7c19e87c49b731fa';

/// Provider that returns only the videos a user has reposted
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == true
/// - reposterPubkey == userIdHex

final class ProfileRepostsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VideoEvent>>, String> {
  const ProfileRepostsFamily._()
    : super(
        retry: null,
        name: r'profileRepostsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that returns only the videos a user has reposted
  ///
  /// Watches the profile feed provider and filters for videos where:
  /// - isRepost == true
  /// - reposterPubkey == userIdHex

  ProfileRepostsProvider call(String userIdHex) =>
      ProfileRepostsProvider._(argument: userIdHex, from: this);

  @override
  String toString() => r'profileRepostsProvider';
}
