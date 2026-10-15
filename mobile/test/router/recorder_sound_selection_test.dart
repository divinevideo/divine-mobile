import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/router/recorder_sound_selection.dart';

void main() {
  testWidgets('sound handoff completes before recorder child initializes', (
    tester,
  ) async {
    AudioEvent? selected;
    final sound = AudioEvent(id: 'a' * 64, pubkey: 'b' * 64, createdAt: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: RecorderSoundSelectionGate(
          selection: RecorderSoundSelection(
            sound: sound,
            ownerPubkey: 'c' * 64,
          ),
          apply: (selection) {
            selected = selection.sound;
          },
          child: Builder(
            builder: (_) {
              expect(selected, same(sound));
              return const Text('Recorder ready');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recorder ready'), findsOneWidget);
  });
}
