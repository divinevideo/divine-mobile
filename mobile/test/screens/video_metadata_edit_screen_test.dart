import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/services/video_event_resolver.dart';

class _MockVideoEventResolver extends Mock implements VideoEventResolver {}

void main() {
  group(VideoMetadataEditScreen, () {
    testWidgets(
      'raw-tagless prefetch resolves a complete event before editing',
      (
        tester,
      ) async {
        final resolver = _MockVideoEventResolver();
        final pending = Completer<VideoEvent?>();
        when(
          () => resolver.resolveById(
            'event-id',
            allowOwnContentBypass: true,
            requireRawTags: true,
          ),
        ).thenAnswer((_) => pending.future);

        final incomplete = VideoEvent(
          id: 'event-id',
          pubkey: 'author-pubkey',
          createdAt: 1700000000,
          content: 'Description',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            1700000000 * 1000,
            isUtc: true,
          ),
          videoUrl: 'https://example.com/video.mp4',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoEventResolverProvider.overrideWithValue(resolver),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoMetadataEditScreen(
                videoId: incomplete.id,
                prefetched: incomplete,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        verify(
          () => resolver.resolveById(
            'event-id',
            allowOwnContentBypass: true,
            requireRawTags: true,
          ),
        ).called(1);

        pending.complete();
        await tester.pump();
      },
    );
  });
}
