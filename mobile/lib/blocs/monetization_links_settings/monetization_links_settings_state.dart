// ABOUTME: State for the profile monetization links settings screen.
// ABOUTME: Tracks editable provider values plus save lifecycle and outcomes.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum MonetizationLinksSettingsLoadStatus { initial, loading, ready, failure }

enum MonetizationLinksSettingsSaveStatus { idle, saving, success, failure }

enum MonetizationLinksSettingsSaveFailure { noRelays, publishFailed }

class MonetizationLinksSettingsState extends Equatable {
  const MonetizationLinksSettingsState({
    required this.currentProfile,
    required this.visibleProviders,
    this.loadStatus = MonetizationLinksSettingsLoadStatus.initial,
    this.values = const {},
    this.enabled = const {},
    this.errors = const {},
    this.status = MonetizationLinksSettingsSaveStatus.idle,
    this.failure,
    this.savedProfile,
    this.savedVisibleLinks = const [],
  });

  final MonetizationLinksSettingsLoadStatus loadStatus;
  final UserProfile? currentProfile;
  final List<MonetizationLinkProvider> visibleProviders;
  final Map<MonetizationLinkProvider, String> values;
  final Map<MonetizationLinkProvider, bool> enabled;
  final Map<MonetizationLinkProvider, MonetizationLinkInputInvalidReason>
  errors;
  final MonetizationLinksSettingsSaveStatus status;
  final MonetizationLinksSettingsSaveFailure? failure;
  final UserProfile? savedProfile;
  final List<MonetizationLink> savedVisibleLinks;

  bool get isSaving => status == MonetizationLinksSettingsSaveStatus.saving;
  bool get isLoading =>
      loadStatus == MonetizationLinksSettingsLoadStatus.loading;
  bool get isReady => loadStatus == MonetizationLinksSettingsLoadStatus.ready;
  bool get canEdit => isReady && !isSaving;
  bool get canSave => canEdit && currentProfile != null;

  String valueFor(MonetizationLinkProvider provider) => values[provider] ?? '';
  bool isEnabled(MonetizationLinkProvider provider) =>
      enabled[provider] ?? false;
  MonetizationLinkInputInvalidReason? errorFor(
    MonetizationLinkProvider provider,
  ) => errors[provider];

  MonetizationLinksSettingsState copyWith({
    MonetizationLinksSettingsLoadStatus? loadStatus,
    UserProfile? currentProfile,
    List<MonetizationLinkProvider>? visibleProviders,
    Map<MonetizationLinkProvider, String>? values,
    Map<MonetizationLinkProvider, bool>? enabled,
    Map<MonetizationLinkProvider, MonetizationLinkInputInvalidReason>? errors,
    MonetizationLinksSettingsSaveStatus? status,
    MonetizationLinksSettingsSaveFailure? failure,
    bool clearFailure = false,
    UserProfile? savedProfile,
    bool clearSavedProfile = false,
    List<MonetizationLink>? savedVisibleLinks,
  }) {
    return MonetizationLinksSettingsState(
      loadStatus: loadStatus ?? this.loadStatus,
      currentProfile: currentProfile ?? this.currentProfile,
      visibleProviders: visibleProviders ?? this.visibleProviders,
      values: values ?? this.values,
      enabled: enabled ?? this.enabled,
      errors: errors ?? this.errors,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      savedProfile: clearSavedProfile
          ? null
          : savedProfile ?? this.savedProfile,
      savedVisibleLinks: savedVisibleLinks ?? this.savedVisibleLinks,
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    currentProfile,
    visibleProviders,
    values,
    enabled,
    errors,
    status,
    failure,
    savedProfile,
    savedVisibleLinks,
  ];
}
