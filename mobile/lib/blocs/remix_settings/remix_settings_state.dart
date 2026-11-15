// ABOUTME: State for the account-wide "Let people remix my videos" setting.
// ABOUTME: Tracks the strict kind 0 load, the switch value, and save outcome.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum RemixSettingsLoadStatus { initial, loading, ready, failure }

enum RemixSettingsSaveStatus { idle, saving, failure }

enum RemixSettingsSaveFailure { noRelays, publishFailed }

class RemixSettingsState extends Equatable {
  const RemixSettingsState({
    this.loadStatus = RemixSettingsLoadStatus.initial,
    this.currentProfile,
    this.allowVideoReuse = true,
    this.saveStatus = RemixSettingsSaveStatus.idle,
    this.failure,
  });

  final RemixSettingsLoadStatus loadStatus;

  /// The signed-in account's raw kind 0, the seed for the next publish.
  final UserProfile? currentProfile;

  /// What the switch shows. Flipped optimistically while a save is in flight
  /// and reverted when it fails.
  final bool allowVideoReuse;

  final RemixSettingsSaveStatus saveStatus;

  /// Why the last save failed. `null` unless [saveStatus] is
  /// [RemixSettingsSaveStatus.failure].
  final RemixSettingsSaveFailure? failure;

  bool get isReady => loadStatus == RemixSettingsLoadStatus.ready;
  bool get isSaving => saveStatus == RemixSettingsSaveStatus.saving;
  bool get canEdit => isReady && !isSaving && currentProfile != null;

  RemixSettingsState copyWith({
    RemixSettingsLoadStatus? loadStatus,
    UserProfile? currentProfile,
    bool? allowVideoReuse,
    RemixSettingsSaveStatus? saveStatus,
    RemixSettingsSaveFailure? failure,
    bool clearFailure = false,
  }) {
    return RemixSettingsState(
      loadStatus: loadStatus ?? this.loadStatus,
      currentProfile: currentProfile ?? this.currentProfile,
      allowVideoReuse: allowVideoReuse ?? this.allowVideoReuse,
      saveStatus: saveStatus ?? this.saveStatus,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    currentProfile,
    allowVideoReuse,
    saveStatus,
    failure,
  ];
}
