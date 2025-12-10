import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/vine_recording_provider.dart';

void main() {
  group('VineRecordingNotifier AspectRatio', () {
    test('initial state includes square aspect ratio', () {
      final container = ProviderContainer();

      final state = container.read(vineRecordingProvider);

      expect(state.aspectRatio, equals(AspectRatio.square));
    });

    test('setAspectRatio updates state', () {
      final container = ProviderContainer();

      final notifier = container.read(vineRecordingProvider.notifier);

      notifier.setAspectRatio(AspectRatio.vertical);

      final state = container.read(vineRecordingProvider);
      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });
  });
}
