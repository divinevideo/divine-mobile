import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';

void main() {
  VideoEvent classic({bool verified = true}) => VideoEvent(
    id: '2' * 64,
    pubkey: '1' * 64,
    createdAt: 100,
    timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
    videoUrl: 'https://example.com/classic.mp4',
    title: 'The tiny puppet show',
    content: 'The tiny puppet show',
    authorName: 'Alex',
    rawTags: const {'platform': 'vine', 'd': 'puppet-show'},
    isVerifiedArchive: verified,
    archiveAudioReuseEnabled: verified,
  );

  Future<void> showChip(
    WidgetTester tester,
    VideoEvent video, {
    required Future<bool> permission,
    void Function()? onPermissionRead,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: AudioAttributionRow(video: video),
          ),
        ),
        GoRoute(
          path: '/sound/:id',
          builder: (_, state) {
            final extra = state.extra! as Map<String, dynamic>;
            final sound = extra['sound'] as AudioEvent;
            return Scaffold(body: Text('${sound.title} library page'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioReuseConsentProvider.overrideWith((ref, sound) {
            onPermissionRead?.call();
            return permission;
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
        ),
      ),
    );
    await tester.pump();
  }

  group('Classic audio chip', () {
    testWidgets('classic sound is named and opens the existing library flow', (
      tester,
    ) async {
      await showChip(tester, classic(), permission: Future.value(true));
      await tester.pumpAndSettle();

      expect(find.textContaining('The tiny puppet show'), findsOneWidget);
      await tester.tap(find.textContaining('The tiny puppet show'));
      await tester.pumpAndSettle();

      expect(find.text('The tiny puppet show library page'), findsOneWidget);
    });

    testWidgets(
      'checks policy only on tap and does not navigate while pending or denied',
      (
        tester,
      ) async {
        final permission = Completer<bool>();
        var reads = 0;
        await showChip(
          tester,
          classic(),
          permission: permission.future,
          onPermissionRead: () => reads++,
        );

        expect(find.textContaining('The tiny puppet show'), findsOneWidget);
        expect(reads, 0);
        await tester.tap(find.textContaining('The tiny puppet show'));
        await tester.pump();
        expect(reads, 1);
        expect(find.text('The tiny puppet show library page'), findsNothing);
        permission.complete(false);
        await tester.pumpAndSettle();

        expect(find.textContaining('The tiny puppet show'), findsOneWidget);
        expect(find.text('The tiny puppet show library page'), findsNothing);
      },
    );

    testWidgets('platform tag alone does not grant reuse', (tester) async {
      await showChip(
        tester,
        classic(verified: false),
        permission: Future.value(false),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('The tiny puppet show'), findsOneWidget);
      await tester.tap(find.textContaining('The tiny puppet show'));
      await tester.pumpAndSettle();
      expect(find.text('The tiny puppet show library page'), findsNothing);
    });
  });
}
