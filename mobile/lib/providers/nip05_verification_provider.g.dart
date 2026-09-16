// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nip05_verification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the NIP-05 verification service singleton

@ProviderFor(nip05VerificationService)
final nip05VerificationServiceProvider = Nip05VerificationServiceProvider._();

/// Provider for the NIP-05 verification service singleton

final class Nip05VerificationServiceProvider
    extends
        $FunctionalProvider<
          Nip05VerificationService,
          Nip05VerificationService,
          Nip05VerificationService
        >
    with $Provider<Nip05VerificationService> {
  /// Provider for the NIP-05 verification service singleton
  Nip05VerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip05VerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip05VerificationServiceHash();

  @$internal
  @override
  $ProviderElement<Nip05VerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Nip05VerificationService create(Ref ref) {
    return nip05VerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Nip05VerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Nip05VerificationService>(value),
    );
  }
}

String _$nip05VerificationServiceHash() =>
    r'3b86ff270ea0b37730bd59b4c010e6ae3205b8f0';

/// Provider that returns the NIP-05 verification status for a pubkey.
///
/// This provider:
/// 1. Watches the user profile to get the NIP-05 claim
/// 2. Returns the verification status reactively
/// 3. Triggers verification if needed
///
/// Usage in widgets:
/// ```dart
/// final statusAsync = ref.watch(nip05VerificationProvider(pubkey));
/// final isVerified = switch (statusAsync) {
///   AsyncData(:final value) => value == Nip05VerificationStatus.verified,
///   _ => false,
/// };
/// ```

@ProviderFor(nip05Verification)
final nip05VerificationProvider = Nip05VerificationFamily._();

/// Provider that returns the NIP-05 verification status for a pubkey.
///
/// This provider:
/// 1. Watches the user profile to get the NIP-05 claim
/// 2. Returns the verification status reactively
/// 3. Triggers verification if needed
///
/// Usage in widgets:
/// ```dart
/// final statusAsync = ref.watch(nip05VerificationProvider(pubkey));
/// final isVerified = switch (statusAsync) {
///   AsyncData(:final value) => value == Nip05VerificationStatus.verified,
///   _ => false,
/// };
/// ```

final class Nip05VerificationProvider
    extends
        $FunctionalProvider<
          AsyncValue<Nip05VerificationStatus>,
          Nip05VerificationStatus,
          FutureOr<Nip05VerificationStatus>
        >
    with
        $FutureModifier<Nip05VerificationStatus>,
        $FutureProvider<Nip05VerificationStatus> {
  /// Provider that returns the NIP-05 verification status for a pubkey.
  ///
  /// This provider:
  /// 1. Watches the user profile to get the NIP-05 claim
  /// 2. Returns the verification status reactively
  /// 3. Triggers verification if needed
  ///
  /// Usage in widgets:
  /// ```dart
  /// final statusAsync = ref.watch(nip05VerificationProvider(pubkey));
  /// final isVerified = switch (statusAsync) {
  ///   AsyncData(:final value) => value == Nip05VerificationStatus.verified,
  ///   _ => false,
  /// };
  /// ```
  Nip05VerificationProvider._({
    required Nip05VerificationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'nip05VerificationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nip05VerificationHash();

  @override
  String toString() {
    return r'nip05VerificationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Nip05VerificationStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Nip05VerificationStatus> create(Ref ref) {
    final argument = this.argument as String;
    return nip05Verification(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is Nip05VerificationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nip05VerificationHash() => r'93e2b80af173c9aef9b7c58beb6e518eebba984c';

/// Provider that returns the NIP-05 verification status for a pubkey.
///
/// This provider:
/// 1. Watches the user profile to get the NIP-05 claim
/// 2. Returns the verification status reactively
/// 3. Triggers verification if needed
///
/// Usage in widgets:
/// ```dart
/// final statusAsync = ref.watch(nip05VerificationProvider(pubkey));
/// final isVerified = switch (statusAsync) {
///   AsyncData(:final value) => value == Nip05VerificationStatus.verified,
///   _ => false,
/// };
/// ```

final class Nip05VerificationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Nip05VerificationStatus>, String> {
  Nip05VerificationFamily._()
    : super(
        retry: null,
        name: r'nip05VerificationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that returns the NIP-05 verification status for a pubkey.
  ///
  /// This provider:
  /// 1. Watches the user profile to get the NIP-05 claim
  /// 2. Returns the verification status reactively
  /// 3. Triggers verification if needed
  ///
  /// Usage in widgets:
  /// ```dart
  /// final statusAsync = ref.watch(nip05VerificationProvider(pubkey));
  /// final isVerified = switch (statusAsync) {
  ///   AsyncData(:final value) => value == Nip05VerificationStatus.verified,
  ///   _ => false,
  /// };
  /// ```

  Nip05VerificationProvider call(String pubkey) =>
      Nip05VerificationProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'nip05VerificationProvider';
}

/// Stream provider for reactive NIP-05 verification updates.
///
/// Use this when you need to reactively update UI when verification
/// status changes (e.g., after a fresh verification completes).

@ProviderFor(nip05VerificationStream)
final nip05VerificationStreamProvider = Nip05VerificationStreamFamily._();

/// Stream provider for reactive NIP-05 verification updates.
///
/// Use this when you need to reactively update UI when verification
/// status changes (e.g., after a fresh verification completes).

final class Nip05VerificationStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<Nip05VerificationStatus>,
          Nip05VerificationStatus,
          Stream<Nip05VerificationStatus>
        >
    with
        $FutureModifier<Nip05VerificationStatus>,
        $StreamProvider<Nip05VerificationStatus> {
  /// Stream provider for reactive NIP-05 verification updates.
  ///
  /// Use this when you need to reactively update UI when verification
  /// status changes (e.g., after a fresh verification completes).
  Nip05VerificationStreamProvider._({
    required Nip05VerificationStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'nip05VerificationStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nip05VerificationStreamHash();

  @override
  String toString() {
    return r'nip05VerificationStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Nip05VerificationStatus> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Nip05VerificationStatus> create(Ref ref) {
    final argument = this.argument as String;
    return nip05VerificationStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is Nip05VerificationStreamProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nip05VerificationStreamHash() =>
    r'b626adfe8d189ac30b5b1427cc022d94e2e75cfc';

/// Stream provider for reactive NIP-05 verification updates.
///
/// Use this when you need to reactively update UI when verification
/// status changes (e.g., after a fresh verification completes).

final class Nip05VerificationStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Nip05VerificationStatus>, String> {
  Nip05VerificationStreamFamily._()
    : super(
        retry: null,
        name: r'nip05VerificationStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stream provider for reactive NIP-05 verification updates.
  ///
  /// Use this when you need to reactively update UI when verification
  /// status changes (e.g., after a fresh verification completes).

  Nip05VerificationStreamProvider call(String pubkey) =>
      Nip05VerificationStreamProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'nip05VerificationStreamProvider';
}
