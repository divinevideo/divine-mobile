// ABOUTME: Cubit for the standalone sound upload — imports a picked audio file,
// ABOUTME: holds its public credit, and publishes it as a reusable Kind 1063.

import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/sound_upload/sound_upload_state.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';

export 'sound_upload_state.dart';

/// Drives `SoundUploadScreen`.
///
/// The published sound always carries `allow_audio_reuse=true`: a sound
/// uploaded on its own exists to be reused, so there is no remix toggle here.
/// Credit-only publication stays on the video path, where a provider license
/// can forbid derivatives.
class SoundUploadCubit extends Cubit<SoundUploadState>
    with CloseGuardedEmit<SoundUploadState> {
  SoundUploadCubit({
    required LocalAudioImportService importService,
    required LocalAudioEventPublisher publisher,
    required String publisherName,
    String? publisherPubkey,
  }) : _importService = importService,
       _publisher = publisher,
       _publisherName = publisherName,
       _publisherPubkey = publisherPubkey,
       super(const SoundUploadState());

  final LocalAudioImportService _importService;
  final LocalAudioEventPublisher _publisher;

  /// The signed-in user's display name, prefilled as the credited creator.
  final String _publisherName;

  /// The signed-in user's pubkey, credited on the `p` tag while the sound is
  /// confirmed as their own work.
  final String? _publisherPubkey;

  /// Copies the picked file into library storage and seeds its credit.
  ///
  /// The credit opens as the publisher's own work: that is the case this flow
  /// exists for, and turning it off is one tap.
  Future<void> importFile({
    required String sourcePath,
    required String displayName,
  }) async {
    if (state.isBusy) return;
    emitIfOpen(
      state.copyWith(status: SoundUploadStatus.importing, failure: null),
    );
    try {
      final imported = await _importService.importAudioFile(
        sourcePath: sourcePath,
        displayName: displayName,
      );
      emitIfOpen(
        state.copyWith(
          status: SoundUploadStatus.ready,
          sound: imported,
          attribution: AudioShareAttribution(
            title: imported.title ?? '',
            creatorName: _publisherName,
            creatorPubkey: _publisherPubkey,
            publicTags: const [],
            confirmedOwnWork: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      // A LocalAudioImportException is the expected shape here (unreadable or
      // unsupported file); the observer only forwards invariant violations.
      addError(error, stackTrace);
      _failImport();
    }
  }

  void _failImport() {
    emitIfOpen(
      state.copyWith(
        status: state.sound == null
            ? SoundUploadStatus.idle
            : SoundUploadStatus.ready,
        failure: SoundUploadFailure.importFailed,
      ),
    );
  }

  /// Applies an edit from the credit editor.
  ///
  /// The `p` tag follows ownership: confirmed own work credits the publisher's
  /// pubkey, anything else carries none, so the feed row can say "Shared by"
  /// when the credited creator is somebody else.
  void updateAttribution(AudioShareAttribution attribution) {
    if (state.sound == null) return;
    emit(
      state.copyWith(
        attribution: attribution.copyWith(
          creatorPubkey: attribution.confirmedOwnWork ? _publisherPubkey : null,
        ),
      ),
    );
  }

  /// Uploads the picked file and publishes it as a reusable Kind 1063.
  Future<void> publish() async {
    final sound = state.sound;
    final attribution = state.attribution;
    if (!state.canPublish || sound == null || attribution == null) return;
    emit(state.copyWith(status: SoundUploadStatus.publishing, failure: null));
    try {
      final result = await _publisher.publish(
        audio: sound,
        attribution: attribution,
        allowAudioReuse: true,
      );
      switch (result) {
        case LocalAudioPublished(:final audio):
          emitIfOpen(
            state.copyWith(
              status: SoundUploadStatus.published,
              publishedSound: audio,
            ),
          );
        case LocalAudioPublishFailed(:final failure):
          _failPublish(switch (failure) {
            LocalAudioPublishFailure.notAuthenticated =>
              SoundUploadFailure.notSignedIn,
            LocalAudioPublishFailure.invalidAttribution ||
            LocalAudioPublishFailure.fileUnavailable ||
            LocalAudioPublishFailure.uploadFailed ||
            LocalAudioPublishFailure.signingFailed ||
            LocalAudioPublishFailure.relayRejected =>
              SoundUploadFailure.publishFailed,
          });
      }
    } on AccountRestrictedPublishException catch (error, stackTrace) {
      addError(error, stackTrace);
      _failPublish(SoundUploadFailure.accountRestricted);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _failPublish(SoundUploadFailure.publishFailed);
    }
  }

  void _failPublish(SoundUploadFailure failure) {
    emitIfOpen(
      state.copyWith(status: SoundUploadStatus.ready, failure: failure),
    );
  }
}
