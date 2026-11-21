import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/collab_room/view/collab_room_flow_scopes.dart';
import 'package:openvine/collab_room/view/collab_room_page.dart';
import 'package:openvine/l10n/l10n.dart';

import 'collab_room_test_fixtures.dart';

class _MockCollabRoomService extends Mock implements CollabRoomService {}

void main() {
  group(CollabRoomPage, () {
    testWidgets("ends the room's post flow with the room's route", (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          collabRoomServiceProvider.overrideWithValue(_MockCollabRoomService()),
        ],
      );
      addTearDown(container.dispose);
      late Widget built;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                built = const CollabRoomPage(roomId: roomId).build(
                  context,
                  ref,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        built,
        isA<CollabRoomPostFlowScope>().having(
          (scope) => scope.roomId,
          'roomId',
          roomId,
        ),
      );
    });
  });
}
