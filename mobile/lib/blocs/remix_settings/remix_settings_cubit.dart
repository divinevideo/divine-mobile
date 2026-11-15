// ABOUTME: Screen-scoped Cubit for the account-wide remix setting, stored as
// ABOUTME: divine_allow_video_reuse in the signed-in account's kind 0.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_state.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

typedef RemixProfileSaved = FutureOr<void> Function(UserProfile profile);

/// Loads and saves whether others may remix the signed-in account's videos.
///
/// Follows `MonetizationLinksSettingsCubit`: a kind 0 replaces the previous
/// one whole, so only a strict raw kind 0 read can seed the publish.
class RemixSettingsCubit extends Cubit<RemixSettingsState>
    with CloseGuardedEmit<RemixSettingsState> {
  RemixSettingsCubit({
    required ProfileRepository? repository,
    required String? pubkey,
    required RemixProfileSaved onProfileSaved,
  }) : _repository = repository,
       _pubkey = pubkey,
       _onProfileSaved = onProfileSaved,
       super(const RemixSettingsState());

  final ProfileRepository? _repository;
  final String? _pubkey;
  final RemixProfileSaved _onProfileSaved;

  /// Reads the account's raw kind 0. The switch stays disabled until this
  /// succeeds, so it never offers a flip away from a value it has not shown.
  Future<void> load() async {
    final repository = _repository;
    final pubkey = _pubkey;
    if (repository == null ||
        pubkey == null ||
        state.loadStatus == RemixSettingsLoadStatus.loading ||
        state.isReady) {
      return;
    }
    emit(state.copyWith(loadStatus: RemixSettingsLoadStatus.loading));
    try {
      final profile = await repository.fetchFreshProfile(
        pubkey: pubkey,
        requireRawKind0: true,
      );
      if (profile == null || profile.pubkey != pubkey) {
        emitIfOpen(
          state.copyWith(loadStatus: RemixSettingsLoadStatus.failure),
        );
        return;
      }
      emitIfOpen(
        state.copyWith(
          loadStatus: RemixSettingsLoadStatus.ready,
          currentProfile: profile,
          allowVideoReuse: profile.allowsVideoReuse,
        ),
      );
    } on Exception catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(state.copyWith(loadStatus: RemixSettingsLoadStatus.failure));
    }
  }

  /// Publishes [allow] to the account's kind 0, reverting the switch when
  /// the publish fails.
  Future<void> setAllowVideoReuse(bool allow) async {
    final repository = _repository;
    final currentProfile = state.currentProfile;
    if (isClosed ||
        !state.canEdit ||
        repository == null ||
        currentProfile == null ||
        allow == state.allowVideoReuse) {
      return;
    }
    final previous = state.allowVideoReuse;
    emit(
      state.copyWith(
        allowVideoReuse: allow,
        saveStatus: RemixSettingsSaveStatus.saving,
        clearFailure: true,
      ),
    );

    try {
      Log.info(
        'Saving account remix setting: allowVideoReuse=$allow',
        name: 'RemixSettingsCubit',
        category: LogCategory.system,
      );
      final saved = await repository.saveProfileEvent(
        displayName: currentProfile.displayName ?? currentProfile.name ?? '',
        about: currentProfile.about,
        website: currentProfile.website,
        picture: currentProfile.picture,
        banner: currentProfile.banner,
        allowVideoReuse: allow,
        currentProfile: currentProfile,
      );
      if (isClosed) return;
      await _onProfileSaved(saved);
      emitIfOpen(
        state.copyWith(
          currentProfile: saved,
          allowVideoReuse: saved.allowsVideoReuse,
          saveStatus: RemixSettingsSaveStatus.idle,
        ),
      );
    } on NoRelaysConnectedException catch (error, stackTrace) {
      _revert(previous, RemixSettingsSaveFailure.noRelays, error, stackTrace);
    } on ProfilePublishFailedException catch (error, stackTrace) {
      _revert(
        previous,
        RemixSettingsSaveFailure.publishFailed,
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      _revert(
        previous,
        RemixSettingsSaveFailure.publishFailed,
        Reportable(error, context: 'setAllowVideoReuse'),
        stackTrace,
      );
    }
  }

  void _revert(
    bool previous,
    RemixSettingsSaveFailure failure,
    Object error,
    StackTrace stackTrace,
  ) {
    if (isClosed) return;
    addError(error, stackTrace);
    emit(
      state.copyWith(
        allowVideoReuse: previous,
        saveStatus: RemixSettingsSaveStatus.failure,
        failure: failure,
      ),
    );
  }
}
