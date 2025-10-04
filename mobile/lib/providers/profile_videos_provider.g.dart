// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing profile videos state
/// keepAlive: false allows disposal when profile not visible - prevents ghost video playback

@ProviderFor(ProfileVideosNotifier)
const profileVideosProvider = ProfileVideosNotifierProvider._();

/// Notifier for managing profile videos state
/// keepAlive: false allows disposal when profile not visible - prevents ghost video playback
final class ProfileVideosNotifierProvider
    extends $NotifierProvider<ProfileVideosNotifier, ProfileVideosState> {
  /// Notifier for managing profile videos state
  /// keepAlive: false allows disposal when profile not visible - prevents ghost video playback
  const ProfileVideosNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileVideosNotifierHash();

  @$internal
  @override
  ProfileVideosNotifier create() => ProfileVideosNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileVideosState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileVideosState>(value),
    );
  }
}

String _$profileVideosNotifierHash() =>
    r'a681461849e6bb95e73ad62d19e044961c2e4486';

/// Notifier for managing profile videos state
/// keepAlive: false allows disposal when profile not visible - prevents ghost video playback

abstract class _$ProfileVideosNotifier extends $Notifier<ProfileVideosState> {
  ProfileVideosState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ProfileVideosState, ProfileVideosState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProfileVideosState, ProfileVideosState>,
              ProfileVideosState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
