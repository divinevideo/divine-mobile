// ABOUTME: Unit tests for VoiceOverState's placement getters: where completed
// ABOUTME: takes land on the video and where the next take starts.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';

AudioEvent _take(String id, {required double seconds}) =>
    AudioEvent.fromLocalImport(
      id: 'local_import_voice_over_$id',
      filePath: '/tmp/$id.m4a',
      createdAt: 0,
      title: id,
      mimeType: 'audio/mp4',
      duration: seconds,
    );

void main() {
  const available = Duration(seconds: 6);

  group(VoiceOverState, () {
    group('placedTakes', () {
      test('lays completed takes back to back from the start', () {
        final state = VoiceOverState(
          takes: [_take('a', seconds: 2), _take('b', seconds: 1.5)],
          availableDuration: available,
        );

        final placed = state.placedTakes;

        expect(placed, hasLength(2));
        expect(placed[0].startTime, Duration.zero);
        expect(placed[0].endTime, const Duration(seconds: 2));
        expect(placed[1].startTime, const Duration(seconds: 2));
        expect(placed[1].endTime, const Duration(milliseconds: 3500));
      });

      test('clamps a take that outgrows the video to its end', () {
        final state = VoiceOverState(
          takes: [_take('a', seconds: 9)],
          availableDuration: available,
        );

        final placed = state.placedTakes;

        expect(placed, hasLength(1));
        expect(placed.single.endTime, available);
      });

      test('is empty while nothing has been recorded', () {
        const state = VoiceOverState(availableDuration: available);
        expect(state.placedTakes, isEmpty);
      });
    });

    group('nextTakeStart', () {
      test('is the start of the video before the first take', () {
        const state = VoiceOverState(availableDuration: available);
        expect(state.nextTakeStart, Duration.zero);
      });

      test('follows the end of the last completed take', () {
        final state = VoiceOverState(
          takes: [_take('a', seconds: 2), _take('b', seconds: 1.5)],
          availableDuration: available,
        );
        expect(state.nextTakeStart, const Duration(milliseconds: 3500));
      });

      test('stays put while a take records', () {
        final state = VoiceOverState(
          status: VoiceOverStatus.recording,
          takes: [_take('a', seconds: 2)],
          currentDuration: const Duration(seconds: 1),
          availableDuration: available,
        );
        expect(state.nextTakeStart, const Duration(seconds: 2));
      });

      test('wraps to the start once the takes fill the video', () {
        final state = VoiceOverState(
          takes: [_take('a', seconds: 4), _take('b', seconds: 3)],
          availableDuration: available,
        );
        expect(state.nextTakeStart, Duration.zero);
      });

      test('ignores a take with no duration', () {
        final state = VoiceOverState(
          takes: [_take('a', seconds: 2), _take('b', seconds: 0)],
          availableDuration: available,
        );
        expect(state.nextTakeStart, const Duration(seconds: 2));
      });

      test('is zero when there is no video to place takes on', () {
        final state = VoiceOverState(takes: [_take('a', seconds: 2)]);
        expect(state.nextTakeStart, Duration.zero);
      });
    });
  });
}
