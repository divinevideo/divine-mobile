// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfileState _$UserProfileStateFromJson(Map<String, dynamic> json) =>
    UserProfileState(
      pendingRequests:
          (json['pendingRequests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
      knownMissingProfiles:
          (json['knownMissingProfiles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
      missingProfileRetryAfter:
          (json['missingProfileRetryAfter'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, DateTime.parse(e as String)),
          ) ??
          const {},
      pendingBatchPubkeys:
          (json['pendingBatchPubkeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
      isLoading: json['isLoading'] as bool? ?? false,
      isInitialized: json['isInitialized'] as bool? ?? false,
      error: json['error'] as String?,
      totalProfilesRequested:
          (json['totalProfilesRequested'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UserProfileStateToJson(UserProfileState instance) =>
    <String, dynamic>{
      'pendingRequests': instance.pendingRequests.toList(),
      'knownMissingProfiles': instance.knownMissingProfiles.toList(),
      'missingProfileRetryAfter': instance.missingProfileRetryAfter.map(
        (k, e) => MapEntry(k, e.toIso8601String()),
      ),
      'pendingBatchPubkeys': instance.pendingBatchPubkeys.toList(),
      'isLoading': instance.isLoading,
      'isInitialized': instance.isInitialized,
      'error': instance.error,
      'totalProfilesRequested': instance.totalProfilesRequested,
    };
