// ABOUTME: State for the account-wide "Let people remix my videos" setting.
// ABOUTME: Tracks the strict kind 0 load, the switch value, and save outcome.

import 'package:equatable/equatable.dart';

enum RemixSettingsLoadStatus { initial, loading, ready, failure }

enum RemixSettingsSaveStatus { idle, saving, failure }

enum RemixSettingsSaveFailure { noRelays, publishFailed }

class RemixSettingsState extends Equatable {
  const RemixSettingsState({
    this.loadStatus = RemixSettingsLoadStatus.initial,
    this.allowVideoReuse = true,
    this.saveStatus = RemixSettingsSaveStatus.idle,
    this.failure,
  });

  final RemixSettingsLoadStatus loadStatus;

  /// What the switch shows. Flipped optimistically while a save is in flight
  /// and reverted when it fails.
  final bool allowVideoReuse;

  final RemixSettingsSaveStatus saveStatus;

  /// Why the last save failed. `null` unless [saveStatus] is
  /// [RemixSettingsSaveStatus.failure].
  final RemixSettingsSaveFailure? failure;

  bool get isReady => loadStatus == RemixSettingsLoadStatus.ready;
  bool get isSaving => saveStatus == RemixSettingsSaveStatus.saving;
  bool get canEdit => isReady && !isSaving;

  RemixSettingsState copyWith({
    RemixSettingsLoadStatus? loadStatus,
    bool? allowVideoReuse,
    RemixSettingsSaveStatus? saveStatus,
    RemixSettingsSaveFailure? failure,
    bool clearFailure = false,
  }) {
    return RemixSettingsState(
      loadStatus: loadStatus ?? this.loadStatus,
      allowVideoReuse: allowVideoReuse ?? this.allowVideoReuse,
      saveStatus: saveStatus ?? this.saveStatus,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    allowVideoReuse,
    saveStatus,
    failure,
  ];
}
