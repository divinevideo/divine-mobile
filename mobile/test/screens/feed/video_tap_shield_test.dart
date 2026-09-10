// ABOUTME: Tests for VideoTapShield — the transparent overlay that
// ABOUTME: claims taps on the fullscreen video area while a text
// ABOUTME: input has primary focus, so dismissing the keyboard does
// ABOUTME: not also toggle video playback.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

void main() {
  group(VideoTapShield, () {
    // The shield's contract: while a text input has primary focus,
    // taps on its child are claimed by an overlay GestureDetector
    // instead of reaching the child's own gesture recognizers. The
    // setup below stands in for the real "video + composer" layout
    // with two minimal widgets — a tap-counting box where the video
    // would sit, plus a TextField that drives focus.

    Widget buildSubject({
      required FocusNode textFieldFocus,
      required void Function() onVideoTap,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: VideoTapShield(
                  child: GestureDetector(
                    onTap: onVideoTap,
                    behavior: HitTestBehavior.opaque,
                    child: const ColoredBox(
                      key: ValueKey('fake-video'),
                      color: Color(0xFF222222),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              TextField(focusNode: textFieldFocus),
            ],
          ),
        ),
      );
    }

    testWidgets(
      'passes taps through to the video when no text input is focused',
      (tester) async {
        final textFieldFocus = FocusNode();
        addTearDown(textFieldFocus.dispose);
        var videoTapCount = 0;

        await tester.pumpWidget(
          buildSubject(
            textFieldFocus: textFieldFocus,
            onVideoTap: () => videoTapCount++,
          ),
        );

        await tester.tap(find.byKey(const ValueKey('fake-video')));
        expect(videoTapCount, 1);
      },
    );

    testWidgets(
      'absorbs taps on the video while a text input has focus, '
      'so playback does not toggle',
      (tester) async {
        final textFieldFocus = FocusNode();
        addTearDown(textFieldFocus.dispose);
        var videoTapCount = 0;

        await tester.pumpWidget(
          buildSubject(
            textFieldFocus: textFieldFocus,
            onVideoTap: () => videoTapCount++,
          ),
        );

        textFieldFocus.requestFocus();
        await tester.pump();

        // `warnIfMissed: false` because the *intent* is that the
        // inner recognizer doesn't receive the tap — the overlay
        // claims it before the gesture arena resolves on the child.
        await tester.tap(
          find.byKey(const ValueKey('fake-video')),
          warnIfMissed: false,
        );
        expect(videoTapCount, 0);
      },
    );

    testWidgets(
      'releases taps back to the video once focus moves away',
      (tester) async {
        final textFieldFocus = FocusNode();
        addTearDown(textFieldFocus.dispose);
        var videoTapCount = 0;

        await tester.pumpWidget(
          buildSubject(
            textFieldFocus: textFieldFocus,
            onVideoTap: () => videoTapCount++,
          ),
        );

        textFieldFocus.requestFocus();
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('fake-video')),
          warnIfMissed: false,
        );
        expect(videoTapCount, 0);

        textFieldFocus.unfocus();
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('fake-video')));
        expect(videoTapCount, 1);
      },
    );
  });
}
