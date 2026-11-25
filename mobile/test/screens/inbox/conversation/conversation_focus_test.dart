// ABOUTME: Exact focus in the reverse lazy conversation timeline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/routing/dm_message_visibility.dart';
import 'package:openvine/screens/inbox/conversation/widgets/conversation_focus_list.dart';

void main() {
  testWidgets('opens a distant mixed-height row and holds it on insertion', (
    tester,
  ) async {
    final ids = List.generate(245, (i) => 'message-$i');
    late StateSetter update;
    var unavailable = 0;
    const target = 'message-241';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => StatefulBuilder(
                    builder: (context, rebuild) {
                      update = rebuild;
                      return Scaffold(
                        body: ConversationFocusList(
                          messageId: target,
                          owner: 'owner',
                          conversation: 'room',
                          itemCount: ids.length,
                          findChildIndexCallback: (key) {
                            final index = ids.indexOf(
                              (key as ValueKey<String>).value,
                            );
                            return index == -1 ? null : index;
                          },
                          onUnavailable: () => unavailable++,
                          highlightColor: Colors.amber,
                          itemBuilder: (_, i) => SizedBox(
                            key: ValueKey(ids[i]),
                            height: 32.0 + (i % 7) * 20,
                            child: Text(ids[i]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              child: const Text('Open room'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open room'));
    await tester.pumpAndSettle();
    expect(find.text(target).hitTestable(), findsOneWidget);
    expect(find.text('message-50'), findsNothing);
    expect(DmMessageVisibility.contains('owner', 'room', target), isTrue);
    expect(DmMessageVisibility.contains('other', 'room', target), isFalse);
    expect(
      DmMessageVisibility.contains('owner', 'room', 'message-50'),
      isFalse,
    );
    expect(find.byKey(ConversationFocusList.highlightKey), findsOneWidget);
    update(() => ids.insert(0, 'newer'));
    await tester.pump();
    expect(find.text(target).hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(ConversationFocusList.highlightKey), findsNothing);
    update(() => ids.remove(target));
    await tester.pumpAndSettle();
    expect(unavailable, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open room'), findsOneWidget);
  });
}
