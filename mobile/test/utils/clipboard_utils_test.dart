// ABOUTME: Tests for ClipboardUtils clipboard writes and their confirmation
// ABOUTME: Covers copyVerified detecting a clipboard the platform refused

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/clipboard_utils.dart';

void main() {
  group(ClipboardUtils, () {
    /// What a mocked platform clipboard holds, or null when it refuses writes.
    String? clipboard;
    late List<String> writes;

    setUp(() {
      clipboard = null;
      writes = <String>[];
    });

    /// Installs a platform clipboard that accepts writes only when [accepts].
    ///
    /// A refusing clipboard still answers `setData` with success, which is what
    /// both engine implementations do — Android's `setPrimaryClip` returns
    /// `void` and iOS assigns `pasteboard.string`, and neither is checked.
    void mockClipboard({required bool accepts}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            switch (call.method) {
              case 'Clipboard.setData':
                final text = (call.arguments as Map)['text'] as String;
                writes.add(text);
                if (accepts) clipboard = text;
                return null;
              case 'Clipboard.getData':
                return clipboard == null ? null : {'text': clipboard};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
    }

    Future<bool> pumpAndCopy(WidgetTester tester, String text) async {
      late bool copied;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  copied = await ClipboardUtils.copyVerified(
                    context,
                    text,
                    message: 'Copied!',
                  );
                },
                child: const Text('copy'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('copy'));
      await tester.pumpAndSettle();
      return copied;
    }

    group('copyVerified', () {
      testWidgets('reports success and confirms when the clipboard takes it', (
        tester,
      ) async {
        mockClipboard(accepts: true);

        final copied = await pumpAndCopy(tester, 'secret-value');

        expect(copied, isTrue);
        expect(clipboard, 'secret-value');
        expect(find.text('Copied!'), findsOneWidget);
      });

      testWidgets('reports failure and stays quiet when the write is refused', (
        tester,
      ) async {
        // The refusing clipboard still answers setData with success, so only
        // reading the value back distinguishes this from a real copy.
        mockClipboard(accepts: false);

        final copied = await pumpAndCopy(tester, 'secret-value');

        expect(writes, equals(['secret-value']), reason: 'the write was made');
        expect(copied, isFalse);
        expect(
          find.text('Copied!'),
          findsNothing,
          reason: 'a refused clipboard must not be confirmed as a copy',
        );
      });

      testWidgets('reports failure when the clipboard holds something else', (
        tester,
      ) async {
        mockClipboard(accepts: false);
        clipboard = 'someone-elses-value';

        final copied = await pumpAndCopy(tester, 'secret-value');

        expect(copied, isFalse);
        expect(find.text('Copied!'), findsNothing);
      });

      testWidgets('reports failure when writing to the clipboard throws', (
        tester,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                throw PlatformException(code: 'clipboard_blocked');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final copied = await pumpAndCopy(tester, 'secret-value');

        expect(copied, isFalse);
        expect(find.text('Copied!'), findsNothing);
      });

      testWidgets('reports failure when reading the clipboard throws', (
        tester,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                throw PlatformException(code: 'clipboard_blocked');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final copied = await pumpAndCopy(tester, 'secret-value');

        expect(copied, isFalse);
        expect(find.text('Copied!'), findsNothing);
      });
    });
  });
}
