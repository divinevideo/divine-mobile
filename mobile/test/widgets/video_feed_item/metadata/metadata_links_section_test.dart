// ABOUTME: Tests the links section of a video's info sheet: the pages its
// ABOUTME: link stickers point to are listed and open when tapped.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_links_section.dart';

VideoEvent _video(List<List<String>> tags) => VideoEvent(
  id: 'a' * 64,
  pubkey: 'b' * 64,
  createdAt: 1778120201,
  content: 'caption',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1778120201000, isUtc: true),
  nostrEventTags: tags,
);

void main() {
  group(MetadataLinksSection, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<List<String>> pump(WidgetTester tester, VideoEvent video) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MetadataLinksSection(
              video: video,
              launcher: (_, url) async => opened.add(url),
            ),
          ),
        ),
      );
      return opened;
    }

    group('renders', () {
      testWidgets('nothing for a video without links', (tester) async {
        await pump(tester, _video(const []));

        expect(find.text(l10n.metadataLinksLabel), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('opens the page of a link sticker', (tester) async {
        final opened = await pump(
          tester,
          _video([
            ['r', 'https://www.divine.video/about', videoLinkTagMarker],
          ]),
        );

        await tester.tap(find.text('divine.video/about'));
        await tester.pump();

        expect(opened, equals(['https://www.divine.video/about']));
      });
    });
  });
}
