// ABOUTME: Tests the list share helper: the link it hands the share sheet
// ABOUTME: and the snackbar it shows when the sheet cannot open.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/share_list_link.dart';

import '../helpers/test_provider_overrides.dart';

const _listOwner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  group('shareListLink', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late List<Map<Object?, Object?>> shareCalls;
    late bool sheetOpens;

    setUp(() {
      shareCalls = <Map<Object?, Object?>>[];
      sheetOpens = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            if (call.method != 'share') return null;
            if (!sheetOpens) {
              throw PlatformException(code: 'share_unavailable');
            }
            shareCalls.add(call.arguments as Map<Object?, Object?>);
            return 'com.apple.UIKit.activity.CopyToPasteboard';
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, null);
    });

    Future<BuildContext> pumpHost(WidgetTester tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: SizedBox(key: key, width: 120, height: 48)),
        ),
      );
      return key.currentContext!;
    }

    testWidgets('shares the list link under the web origin, named', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      await shareListLink(
        context,
        name: 'Skate',
        path: '/people-lists/$_listOwner/skate',
      );
      await tester.pump();

      expect(shareCalls, hasLength(1));
      const url = '${AppConstants.webOrigin}/people-lists/$_listOwner/skate';
      expect(url, startsWith('https://divine.video/'));
      expect(
        shareCalls.single['text'],
        equals(l10n.listShareText('Skate', url)),
      );
      expect(
        shareCalls.single['subject'],
        equals(l10n.listShareSubject('Skate')),
      );
      expect(find.text(l10n.listShareFailed), findsNothing);
    });

    testWidgets('ignores a share failure after the messenger is disposed', (
      tester,
    ) async {
      final shareResult = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (_) => shareResult.future);
      final context = await pumpHost(tester);
      final sharing = shareListLink(
        context,
        name: 'Skate',
        path: '/people-lists/$_listOwner/skate',
      );
      await tester.pumpWidget(const SizedBox.shrink());

      shareResult.completeError(PlatformException(code: 'share_unavailable'));
      await sharing;
      expect(tester.takeException(), isNull);
    });

    for (final replace in [false, true]) {
      testWidgets(
        'ignores late failure after ${replace ? 'pushReplacement' : 'push with origin mounted'}',
        (tester) async {
          final shareResult = Completer<String>();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                _shareChannel,
                (_) => shareResult.future,
              );
          final context = await pumpHost(tester);
          final originRoute = ModalRoute.of(context)!;
          final sharing = shareListLink(
            context,
            name: 'Skate',
            path: '/people-lists/$_listOwner/skate',
          );
          final target = MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Destination')),
          );
          final navigator = Navigator.of(context);
          if (replace) {
            navigator.pushReplacement(target);
          } else {
            navigator.push(target);
          }
          await tester.pumpAndSettle();
          expect(originRoute.isCurrent, isFalse);
          expect(context.mounted, !replace);
          shareResult.completeError(
            PlatformException(code: 'share_unavailable'),
          );
          await sharing;
          await tester.pump();
          expect(find.text('Destination'), findsOneWidget);
          expect(find.text(l10n.listShareFailed), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'reports late failure after returning to the originating route',
      (tester) async {
        final shareResult = Completer<String>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_shareChannel, (_) => shareResult.future);
        final context = await pumpHost(tester);
        final sharing = shareListLink(
          context,
          name: 'Skate',
          path: '/people-lists/$_listOwner/skate',
        );
        final navigator = Navigator.of(context);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Destination')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        expect(ModalRoute.of(context)!.isCurrent, isTrue);
        shareResult.completeError(PlatformException(code: 'share_unavailable'));
        await sharing;
        await tester.pump();
        expect(find.text(l10n.listShareFailed), findsOneWidget);
      },
    );

    testWidgets('reports a sheet that cannot open in a snackbar', (
      tester,
    ) async {
      sheetOpens = false;
      final context = await pumpHost(tester);

      await shareListLink(
        context,
        name: 'Skate',
        path: '/people-lists/$_listOwner/skate',
      );
      await tester.pump();

      expect(shareCalls, isEmpty);
      expect(find.text(l10n.listShareFailed), findsOneWidget);
    });
  });
}
