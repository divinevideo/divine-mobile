// ABOUTME: Widget tests for the "by {author}" byline under a list's title
// ABOUTME: Covers the link-styled name, its fallback, semantics and the tap

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/list_author_byline.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:riverpod/misc.dart' show Override;

import '../helpers/test_provider_overrides.dart';

// Full-length 64-char pubkey — never truncate.
final String _author = 'a' * 64;

UserProfile _profile({String? picture}) => UserProfile(
  pubkey: _author,
  displayName: 'Mackardigan',
  picture: picture,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'e' * 64,
);

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onTap,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    testProviderScope(
      additionalOverrides: overrides,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListAuthorByline(authorPubkey: _author, onTap: onTap ?? () {}),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The span of the byline that carries [text].
TextSpan _spanWith(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byType(ListAuthorByline),
      matching: find.byType(RichText),
    ),
  );
  TextSpan? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == text) found = span;
    return found == null;
  });
  expect(found, isNotNull, reason: 'no span with "$text"');
  return found!;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ListAuthorByline, () {
    group('renders', () {
      testWidgets("the author's name as a link after the localized prefix", (
        tester,
      ) async {
        await _pump(
          tester,
          overrides: [
            userProfileReactiveProvider(
              _author,
            ).overrideWith((ref) => Stream.value(_profile())),
          ],
        );

        final element = tester.element(find.byType(ListAuthorByline));
        final colors = element.vineColors;
        final name = _spanWith(tester, 'Mackardigan');
        expect(name.style?.color, colors.link);
        expect(name.style?.decoration, TextDecoration.underline);
        final prefix = l10n.listByAuthor('\u0000').split('\u0000').first;
        expect(_spanWith(tester, prefix).style, isNull);
        expect(
          find.textContaining(
            l10n.listByAuthor('Mackardigan'),
            findRichText: true,
          ),
          findsOneWidget,
        );
      });

      testWidgets('a generated name before the profile arrives', (
        tester,
      ) async {
        await _pump(
          tester,
          overrides: [
            userProfileReactiveProvider(
              _author,
            ).overrideWith((ref) => const Stream.empty()),
          ],
        );

        _spanWith(tester, UserProfile.defaultDisplayNameFor(_author));
      });

      testWidgets("a 24pt avatar of the author's picture", (tester) async {
        await _pump(
          tester,
          overrides: [
            userProfileReactiveProvider(_author).overrideWith(
              (ref) => Stream.value(
                _profile(picture: 'https://example.invalid/a.png'),
              ),
            ),
            profileVanishedProvider(_author).overrideWith((ref) => false),
          ],
        );

        final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(avatar.size, kListAuthorAvatarSize);
        expect(avatar.imageUrl, 'https://example.invalid/a.png');
      });

      testWidgets("hides a vanished account's picture", (tester) async {
        await _pump(
          tester,
          overrides: [
            userProfileReactiveProvider(_author).overrideWith(
              (ref) => Stream.value(
                _profile(picture: 'https://example.invalid/a.png'),
              ),
            ),
            profileVanishedProvider(_author).overrideWith((ref) => true),
          ],
        );

        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).imageUrl,
          isNull,
        );
      });

      testWidgets('announces itself as one button naming the author', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            overrides: [
              userProfileReactiveProvider(
                _author,
              ).overrideWith((ref) => Stream.value(_profile())),
            ],
          );

          final semantics = tester.getSemantics(
            find.byType(ListAuthorByline),
          );
          expect(semantics.label, l10n.listByAuthor('Mackardigan'));
          expect(semantics.flagsCollection.isButton, isTrue);
        } finally {
          handle.dispose();
        }
      });
    });

    group('interactions', () {
      testWidgets('tapping the row opens the author', (tester) async {
        var taps = 0;
        await _pump(tester, onTap: () => taps++);

        await tester.tap(find.byType(UserAvatar));
        await tester.tap(find.byType(RichText).last);
        expect(taps, 2);
      });
    });
  });
}
