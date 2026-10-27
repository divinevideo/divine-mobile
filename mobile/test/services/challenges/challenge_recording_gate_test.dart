import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/challenge_recording_gate.dart';

void main() {
  group('ChallengeRecordingGate navigation', () {
    testWidgets('recorder is built only after durable context preparation', (
      tester,
    ) async {
      final ready = Completer<void>();
      const recorder = Key('recorder');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChallengeRecordingGate(
            prepare: () => ready.future,
            child: const SizedBox(key: recorder),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(recorder), findsNothing);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(recorder), findsOneWidget);
    });
  });
}
