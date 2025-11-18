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
    required (String, String, String) super.argument,
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

String _$commentsNotifierHash() => r'5d0725c5778794e9a986e585642ff288f2c86cd3';

/// Notifier for managing comments for a specific video

final class CommentsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CommentsNotifier,
          CommentsState,
          CommentsState,
          CommentsState,
          (String, String, String)
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

  CommentsNotifierProvider call(
    String rootEventId,
    String rootAuthorPubkey,
    String rootDTag,
  ) => CommentsNotifierProvider._(
    argument: (rootEventId, rootAuthorPubkey, rootDTag),
    from: this,
  );

  @override
  String toString() => r'commentsProvider';
}

/// Notifier for managing comments for a specific video

abstract class _$CommentsNotifier extends $Notifier<CommentsState> {
  late final _$args = ref.$arg as (String, String, String);
  String get rootEventId => _$args.$1;
  String get rootAuthorPubkey => _$args.$2;
  String get rootDTag => _$args.$3;

  CommentsState build(
    String rootEventId,
    String rootAuthorPubkey,
    String rootDTag,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2, _$args.$3);
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
