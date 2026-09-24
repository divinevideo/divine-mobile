// ABOUTME: Cubit for the creator's most reused sounds in Creator Analytics.
// ABOUTME: Loads the ranked list once per dashboard load and exposes a status.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/observability/reportable_error.dart';

part 'creator_sounds_state.dart';

class CreatorSoundsCubit extends Cubit<CreatorSoundsState>
    with CloseGuardedEmit<CreatorSoundsState> {
  CreatorSoundsCubit({
    required CreatorAnalyticsRepository repository,
    required String pubkey,
  }) : _repository = repository,
       _pubkey = pubkey,
       super(const CreatorSoundsState());

  /// How many of the creator's sounds the dashboard shows.
  static const shownSoundLimit = 5;

  final CreatorAnalyticsRepository _repository;
  final String _pubkey;

  Future<void> load() async {
    if (state.status == CreatorSoundsStatus.loading) return;

    emit(const CreatorSoundsState(status: CreatorSoundsStatus.loading));
    try {
      final sounds = await _repository.fetchCreatorSounds(_pubkey);
      emitIfOpen(
        CreatorSoundsState(
          status: CreatorSoundsStatus.success,
          sounds: sounds.take(shownSoundLimit).toList(),
        ),
      );
    } on CreatorAnalyticsLoadException catch (e, stackTrace) {
      addError(e, stackTrace);
      emitIfOpen(
        CreatorSoundsState(
          status: CreatorSoundsStatus.failure,
          failureKind: e.kind,
        ),
      );
    } catch (e, stackTrace) {
      addError(Reportable(e, context: 'CreatorSoundsCubit.load'), stackTrace);
      emitIfOpen(
        const CreatorSoundsState(
          status: CreatorSoundsStatus.failure,
          failureKind: CreatorAnalyticsFailureKind.unableToLoad,
        ),
      );
    }
  }
}
