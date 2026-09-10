// ABOUTME: Cubit for resolving a shared DM video before opening the save sheet.
// ABOUTME: Keeps repository/profile lookups and in-flight guarding out of widgets.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

enum SharedVideoSaveStatus {
  idle,
  resolving,
  originalReady,
  watermarkReady,
  unavailable,
}

class SharedVideoSaveState extends Equatable {
  const SharedVideoSaveState({
    this.status = SharedVideoSaveStatus.idle,
    this.video,
    this.watermarkText,
  });

  final SharedVideoSaveStatus status;
  final VideoEvent? video;
  final String? watermarkText;

  @override
  List<Object?> get props => [status, video?.id, watermarkText];
}

class SharedVideoSaveCubit extends Cubit<SharedVideoSaveState> {
  SharedVideoSaveCubit({
    required VideosRepository videosRepository,
    required ProfileRepository? profileRepository,
    required String? currentPubkey,
  }) : _videosRepository = videosRepository,
       _profileRepository = profileRepository,
       _currentPubkey = currentPubkey,
       super(const SharedVideoSaveState());

  final VideosRepository _videosRepository;
  final ProfileRepository? _profileRepository;
  final String? _currentPubkey;

  Future<void> save(DmVideoTarget target) async {
    if (state.status == SharedVideoSaveStatus.resolving) return;

    emit(const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving));
    try {
      final video = await _videosRepository.fetchVideoWithStatsForRouteId(
        target.stableId,
        fallbackRouteIds: target.fallbackRouteIds,
      );
      if (isClosed) return;
      if (video == null) {
        emit(
          const SharedVideoSaveState(status: SharedVideoSaveStatus.unavailable),
        );
        return;
      }

      if (video.pubkey == _currentPubkey) {
        emit(
          SharedVideoSaveState(
            status: SharedVideoSaveStatus.originalReady,
            video: video,
          ),
        );
        return;
      }

      final profile = await _cachedProfile(video.pubkey);
      if (isClosed) return;
      emit(
        SharedVideoSaveState(
          status: SharedVideoSaveStatus.watermarkReady,
          video: video,
          watermarkText: resolveWatermarkText(
            profile: profile,
            fallbackAuthorName: video.authorName,
          ),
        ),
      );
    } catch (error) {
      Log.warning(
        'Shared DM video save resolve failed for ${target.stableId}: $error',
        name: 'SharedVideoSaveCubit',
        category: LogCategory.ui,
      );
      if (!isClosed) {
        emit(
          const SharedVideoSaveState(status: SharedVideoSaveStatus.unavailable),
        );
      }
    }
  }

  void reset() {
    if (!isClosed) emit(const SharedVideoSaveState());
  }

  Future<UserProfile?> _cachedProfile(String pubkey) async {
    try {
      return await _profileRepository?.getCachedProfile(pubkey: pubkey);
    } catch (error) {
      Log.warning(
        'Shared DM video save profile lookup failed for ${pubkeyForLogs(pubkey)}: $error',
        name: 'SharedVideoSaveCubit',
        category: LogCategory.ui,
      );
      return null;
    }
  }
}
