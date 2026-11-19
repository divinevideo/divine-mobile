import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/owner_video_actions_tile.dart';

import '../helpers/semantics_nodes.dart';

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final _video = VideoEvent(
  id: 'video-by-owner',
  pubkey: _ownerPubkey,
  content: 'A video',
  createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
  timestamp: DateTime(2026),
);

void main() {
  group(OwnerVideoActionsTile, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final tileLabel = l10n.profileVideoThumbnailLabel(3);

    var taps = 0;
    var ownerLongPresses = 0;

    setUp(() {
      taps = 0;
      ownerLongPresses = 0;
    });

    Widget buildSubject({
      String? viewerPubkey = _ownerPubkey,
      bool ownerActionsEnabled = true,
      bool? selected,
      String? value,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox.square(
            dimension: 200,
            child: OwnerVideoActionsTile(
              video: _video,
              viewerPubkey: viewerPubkey,
              index: 2,
              onTap: () => taps++,
              onOwnerLongPress: () => ownerLongPresses++,
              ownerActionsEnabled: ownerActionsEnabled,
              selected: selected,
              value: value,
              child: const ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      );
    }

    SemanticsNode tileNode(WidgetTester tester) =>
        tester.getSemantics(find.bySemanticsLabel(tileLabel));

    group('semantics', () {
      testWidgets(
        'exposes an owned video as one labelled button with tap, long-press '
        'and the options hint',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(buildSubject());

            final node = tileNode(tester);
            expect(
              node,
              isSemantics(
                label: tileLabel,
                identifier: SemanticIds.videoThumbnail(2),
                isButton: true,
                hasTapAction: true,
                hasLongPressAction: true,
                onLongPressHint: l10n.videoGridOptionsTitle,
              ),
            );
            expect(
              countSemanticsNodesWithAction(node, SemanticsAction.tap),
              equals(1),
              reason: 'A second tap node would be an unlabelled twin.',
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'advertises no long-press action on a video the viewer does not own',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(buildSubject(viewerPubkey: _otherPubkey));

            final data = tileNode(tester).getSemanticsData();
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            expect(data.hasAction(SemanticsAction.longPress), isFalse);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('advertises no long-press action when no one is signed in', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(buildSubject(viewerPubkey: null));

          expect(
            tileNode(
              tester,
            ).getSemanticsData().hasAction(SemanticsAction.longPress),
            isFalse,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets(
        'advertises no long-press action while owner actions are disabled',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(buildSubject(ownerActionsEnabled: false));

            expect(
              tileNode(
                tester,
              ).getSemanticsData().hasAction(SemanticsAction.longPress),
              isFalse,
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('carries the selected state and value it is given', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            buildSubject(selected: true, value: l10n.profileVideoPinnedValue),
          );

          expect(
            tileNode(tester),
            isSemantics(
              isSelected: true,
              value: l10n.profileVideoPinnedValue,
            ),
          );
        } finally {
          handle.dispose();
        }
      });
    });

    group('interactions', () {
      testWidgets('tapping the tile calls onTap', (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.tap(find.byType(OwnerVideoActionsTile));

        expect(taps, equals(1));
        expect(ownerLongPresses, isZero);
      });

      testWidgets('long-pressing an owned video calls onOwnerLongPress', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        await tester.longPress(find.byType(OwnerVideoActionsTile));

        expect(ownerLongPresses, equals(1));
      });

      testWidgets(
        'long-pressing a video the viewer does not own never calls '
        'onOwnerLongPress',
        (tester) async {
          await tester.pumpWidget(buildSubject(viewerPubkey: _otherPubkey));

          await tester.longPress(find.byType(OwnerVideoActionsTile));

          expect(ownerLongPresses, isZero);
        },
      );

      testWidgets(
        'the semantics tap and long-press actions run the same callbacks',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(buildSubject());

            tester.semantics.tap(find.semantics.byLabel(tileLabel));
            tester.semantics.longPress(find.semantics.byLabel(tileLabel));

            expect(taps, equals(1));
            expect(ownerLongPresses, equals(1));
          } finally {
            handle.dispose();
          }
        },
      );
    });
  });
}
