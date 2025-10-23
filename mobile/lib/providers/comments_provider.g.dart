// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing comments for a specific video

@ProviderFor(CommentsNotifier)
const commentsProvider = CommentsNotifierFamily._();

/// Notifier for managing comments for a specific video
final class CommentsNotifierProvider
    extends $NotifierProvider<CommentsNotifier, CommentsState> {
  /// Notifier for managing comments for a specific video
  const CommentsNotifierProvider._({
    required CommentsNotifierFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'commentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commentsNotifierHash();

  @override
  String toString() {
    return r'commentsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CommentsNotifier create() => CommentsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CommentsNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commentsNotifierHash() => r'123affa2371b5fceda185d403e8bed8c5752fc87';

/// Notifier for managing comments for a specific video

final class CommentsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CommentsNotifier,
          CommentsState,
          CommentsState,
          CommentsState,
          (String, String)
        > {
  const CommentsNotifierFamily._()
    : super(
        retry: null,
        name: r'commentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Notifier for managing comments for a specific video

  CommentsNotifierProvider call(String rootEventId, String rootAuthorPubkey) =>
      CommentsNotifierProvider._(
        argument: (rootEventId, rootAuthorPubkey),
        from: this,
      );

  @override
  String toString() => r'commentsProvider';
}

/// Notifier for managing comments for a specific video

abstract class _$CommentsNotifier extends $Notifier<CommentsState> {
  late final _$args = ref.$arg as (String, String);
  String get rootEventId => _$args.$1;
  String get rootAuthorPubkey => _$args.$2;

  CommentsState build(String rootEventId, String rootAuthorPubkey);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2);
    final ref = this.ref as $Ref<CommentsState, CommentsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentsState, CommentsState>,
              CommentsState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
