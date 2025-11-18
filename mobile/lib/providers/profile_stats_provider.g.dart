// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Async provider for loading profile statistics

@ProviderFor(fetchProfileStats)
const fetchProfileStatsProvider = FetchProfileStatsFamily._();

/// Async provider for loading profile statistics

final class FetchProfileStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileStats>,
          ProfileStats,
          FutureOr<ProfileStats>
        >
    with $FutureModifier<ProfileStats>, $FutureProvider<ProfileStats> {
  /// Async provider for loading profile statistics
  const FetchProfileStatsProvider._({
    required FetchProfileStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fetchProfileStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fetchProfileStatsHash();

  @override
  String toString() {
    return r'fetchProfileStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ProfileStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileStats> create(Ref ref) {
    final argument = this.argument as String;
    return fetchProfileStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FetchProfileStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fetchProfileStatsHash() => r'919af7a596e149771c5cef8407bf74e5502599d5';

/// Async provider for loading profile statistics

final class FetchProfileStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ProfileStats>, String> {
  const FetchProfileStatsFamily._()
    : super(
        retry: null,
        name: r'fetchProfileStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Async provider for loading profile statistics

  FetchProfileStatsProvider call(String pubkey) =>
      FetchProfileStatsProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'fetchProfileStatsProvider';
}
