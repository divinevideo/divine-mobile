// ABOUTME: State for the account-wide "Let people remix my videos" setting.
// ABOUTME: Tracks the strict kind 0 load, the switch value, and save outcome.

import 'package:equatable/equatable.dart';

enum RemixSettingsLoadStatus { initial, loading, ready, failure }

/// Where the last save stands. A failed save carries its cause in the value,
/// so a failure cannot exist without one.
enum RemixSettingsSaveStatus {
  idle,
  saving,
  failedRead,
  failedNoRelays,
  failedPublish,
}

class RemixSettingsState extends Equatable {
  const RemixSettingsState({
    this.loadStatus = RemixSettingsLoadStatus.initial,
    this.allowVideoReuse = true,
    this.saveStatus = RemixSettingsSaveStatus.idle,
  });

  final RemixSettingsLoadStatus loadStatus;

  /// What the switch shows. Flipped optimistically while a save is in flight
  /// and reverted when it fails.
  final bool allowVideoReuse;

  final RemixSettingsSaveStatus saveStatus;

  bool get isReady => loadStatus == RemixSettingsLoadStatus.ready;
  bool get isSaving => saveStatus == RemixSettingsSaveStatus.saving;
  bool get canEdit => isReady && !isSaving;

  RemixSettingsState copyWith({
    RemixSettingsLoadStatus? loadStatus,
    bool? allowVideoReuse,
    RemixSettingsSaveStatus? saveStatus,
  }) {
    return RemixSettingsState(
      loadStatus: loadStatus ?? this.loadStatus,
      allowVideoReuse: allowVideoReuse ?? this.allowVideoReuse,
      saveStatus: saveStatus ?? this.saveStatus,
    );
  }

  @override
  List<Object?> get props => [loadStatus, allowVideoReuse, saveStatus];
}
