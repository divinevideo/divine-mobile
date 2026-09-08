// ABOUTME: User profile state model for managing profile cache and loading states
// ABOUTME: Used by Riverpod UserProfileProvider to manage reactive profile state

import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:openvine/state/copy_with_sentinel.dart';

part 'user_profile_state.g.dart';

@JsonSerializable()
class UserProfileState extends Equatable {
  const UserProfileState({
    Set<String> pendingRequests = const {},
    Set<String> knownMissingProfiles = const {},
    Map<String, DateTime> missingProfileRetryAfter = const {},
    Set<String> pendingBatchPubkeys = const {},
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.totalProfilesRequested = 0,
  }) : _pendingRequests = pendingRequests,
       _knownMissingProfiles = knownMissingProfiles,
       _missingProfileRetryAfter = missingProfileRetryAfter,
       _pendingBatchPubkeys = pendingBatchPubkeys;

  factory UserProfileState.fromJson(Map<String, dynamic> json) =>
      _$UserProfileStateFromJson(json);

  /// Create initial state
  static const UserProfileState initial = UserProfileState();

  // Pending profile requests
  final Set<String> _pendingRequests;
  Set<String> get pendingRequests => UnmodifiableSetView(_pendingRequests);

  // Missing profiles to avoid spam
  final Set<String> _knownMissingProfiles;
  Set<String> get knownMissingProfiles =>
      UnmodifiableSetView(_knownMissingProfiles);
  final Map<String, DateTime> _missingProfileRetryAfter;
  Map<String, DateTime> get missingProfileRetryAfter =>
      UnmodifiableMapView(_missingProfileRetryAfter);

  // Batch fetching state
  final Set<String> _pendingBatchPubkeys;
  Set<String> get pendingBatchPubkeys =>
      UnmodifiableSetView(_pendingBatchPubkeys);

  // Loading and error state
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  // Stats
  final int totalProfilesRequested;

  /// Check if profile request is pending
  bool isRequestPending(String pubkey) => pendingRequests.contains(pubkey);

  /// Check if we should skip fetching (known missing)
  bool shouldSkipFetch(String pubkey) {
    if (!knownMissingProfiles.contains(pubkey)) return false;

    final retryAfter = missingProfileRetryAfter[pubkey];
    if (retryAfter == null) return false;

    return DateTime.now().isBefore(retryAfter);
  }

  Map<String, dynamic> toJson() => _$UserProfileStateToJson(this);

  UserProfileState copyWith({
    Set<String>? pendingRequests,
    Set<String>? knownMissingProfiles,
    Map<String, DateTime>? missingProfileRetryAfter,
    Set<String>? pendingBatchPubkeys,
    bool? isLoading,
    bool? isInitialized,
    Object? error = unsetCopyWithArgument,
    int? totalProfilesRequested,
  }) {
    return UserProfileState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      knownMissingProfiles: knownMissingProfiles ?? this.knownMissingProfiles,
      missingProfileRetryAfter:
          missingProfileRetryAfter ?? this.missingProfileRetryAfter,
      pendingBatchPubkeys: pendingBatchPubkeys ?? this.pendingBatchPubkeys,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: identical(error, unsetCopyWithArgument)
          ? this.error
          : error as String?,
      totalProfilesRequested:
          totalProfilesRequested ?? this.totalProfilesRequested,
    );
  }

  @override
  List<Object?> get props => [
    pendingRequests,
    knownMissingProfiles,
    missingProfileRetryAfter,
    pendingBatchPubkeys,
    isLoading,
    isInitialized,
    error,
    totalProfilesRequested,
  ];
}
