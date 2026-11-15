// ABOUTME: Screen-scoped Cubit for the account-wide remix setting, stored as
// ABOUTME: divine_allow_video_reuse in the signed-in account's kind 0.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_reportable_sites.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_state.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

typedef RemixProfileSaved = FutureOr<void> Function(UserProfile profile);

/// Loads and saves whether others may remix the signed-in account's videos.
///
/// A kind 0 replaces the previous one whole, and `saveProfileEvent` writes
/// the editable fields it is given over its seed, so every save re-reads the
/// strict raw kind 0 and takes those fields from that read rather than from
/// [load]. An account that confirmably has no kind 0 loads as allowed, and a
/// save then publishes its first kind 0 from the locally cached profile.
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

  /// Reads the account's raw kind 0. The switch is not shown until this
  /// succeeds, so it never offers a flip away from a value it has not read.
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
      final read = await repository.readFreshProfile(
        pubkey: pubkey,
        requireRawKind0: true,
      );
      final profile = read.profile;
      // An account that confirmably has no kind 0 has blocked nothing; it
      // loads as allowed so the creator can still turn remixing off.
      if (profile == null && read.conclusive) {
        emitIfOpen(state.copyWith(loadStatus: RemixSettingsLoadStatus.ready));
        return;
      }
      if (profile == null || profile.pubkey != pubkey) {
        final reason = profile == null
            ? 'the read was inconclusive'
            : 'the answer belonged to another account';
        Log.warning(
          'Could not read the kind 0 for ${pubkeyForLogs(pubkey)}: $reason',
          name: 'RemixSettingsCubit',
          category: LogCategory.system,
        );
        emitIfOpen(
          state.copyWith(loadStatus: RemixSettingsLoadStatus.failure),
        );
        return;
      }
      emitIfOpen(
        state.copyWith(
          loadStatus: RemixSettingsLoadStatus.ready,
          allowVideoReuse: profile.allowsVideoReuse,
        ),
      );
    } on Exception catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(state.copyWith(loadStatus: RemixSettingsLoadStatus.failure));
    } catch (error, stackTrace) {
      // Anything else is a defect; ending in failure keeps retry possible,
      // since the guard above refuses to load while still `loading`.
      if (isClosed) return;
      addError(
        Reportable(error, context: RemixSettingsReportableSites.load),
        stackTrace,
      );
      emit(state.copyWith(loadStatus: RemixSettingsLoadStatus.failure));
    }
  }

  /// Publishes [allow] to the account's kind 0, reverting the switch when
  /// the publish fails.
  Future<void> setAllowVideoReuse(bool allow) async {
    final repository = _repository;
    final pubkey = _pubkey;
    if (isClosed ||
        !state.canEdit ||
        repository == null ||
        pubkey == null ||
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
      final seed = await _readSaveSeed(repository, pubkey);
      Log.info(
        'Saving account remix setting: allowVideoReuse=$allow',
        name: 'RemixSettingsCubit',
        category: LogCategory.system,
      );
      final saved = await repository.saveProfileEvent(
        displayName: seed?.displayName ?? seed?.name ?? '',
        about: seed?.about,
        website: seed?.website,
        picture: seed?.picture,
        banner: seed?.banner,
        allowVideoReuse: allow,
        currentProfile: seed,
      );
      if (isClosed) return;
      await _onProfileSaved(saved);
      emitIfOpen(
        state.copyWith(
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
        Reportable(
          error,
          context: RemixSettingsReportableSites.setAllowVideoReuse,
        ),
        stackTrace,
      );
    }
  }

  /// The profile a save takes its editable fields from, read now.
  ///
  /// The profile [load] read may be stale by the time the switch flips: an
  /// edit made on another device since then would be published back over.
  /// A conclusive miss falls back to the locally cached profile, so a first
  /// kind 0 does not publish an empty display name over it.
  ///
  /// Throws [ProfilePublishFailedException], before anything is published,
  /// when the read is inconclusive or answers for another account.
  Future<UserProfile?> _readSaveSeed(
    ProfileRepository repository,
    String pubkey,
  ) async {
    final read = await repository.readFreshProfile(
      pubkey: pubkey,
      requireRawKind0: true,
    );
    final profile = read.profile;
    if (profile != null && profile.pubkey == pubkey) return profile;
    if (profile == null && read.conclusive) {
      return repository.getCachedProfile(pubkey: pubkey);
    }
    Log.warning(
      'Deferring the account remix save for ${pubkeyForLogs(pubkey)}: '
      'the current kind 0 could not be read',
      name: 'RemixSettingsCubit',
      category: LogCategory.system,
    );
    throw const ProfilePublishFailedException(
      'Failed to publish profile. Please try again.',
    );
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
