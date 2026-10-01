// ABOUTME: Tests the shell app bar title and back button without a shell
// ABOUTME: Both were private instance methods before #3337

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/shell/shell_title_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

const _otherUserHex =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
const _viewerHex =
    'aaaa1f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final otherUserNpub = NostrKeyUtils.encodePubKey(_otherUserHex);

  String title(RouteContext? context, {String? tab, String? displayName}) =>
      resolveShellTitle(
        l10n: l10n,
        context: context,
        exploreTabName: tab,
        profileDisplayName: displayName,
      );

  group('resolveShellTitle', () {
    test('titles the home tab', () {
      expect(
        title(const RouteContext(type: RouteType.home)),
        equals(l10n.navHome),
      );
    });

    test('titles the explore grid', () {
      expect(
        title(const RouteContext(type: RouteType.explore)),
        equals(l10n.navExplore),
      );
    });

    test('names the source tab while watching an explore video', () {
      expect(
        title(
          const RouteContext(type: RouteType.explore, videoIndex: 3),
          tab: explorePopularTabName,
        ),
        equals(l10n.navExploreTrending),
      );
    });

    test('falls back to explore when the tab name has not resolved', () {
      expect(
        title(const RouteContext(type: RouteType.explore, videoIndex: 3)),
        equals(l10n.navExplore),
      );
    });

    test('titles a category gallery as explore', () {
      expect(
        title(const RouteContext(type: RouteType.categoryGallery)),
        equals(l10n.navExplore),
      );
    });

    test('titles notifications', () {
      expect(
        title(const RouteContext(type: RouteType.notifications)),
        equals(l10n.navNotifications),
      );
    });

    test('titles the inbox', () {
      expect(
        title(const RouteContext(type: RouteType.inbox)),
        equals(l10n.navInbox),
      );
    });

    test('titles the own-profile shorthand route', () {
      expect(
        title(const RouteContext(type: RouteType.profile, npub: 'me')),
        equals(l10n.navMyProfile),
      );
    });

    test("shows another user's display name", () {
      expect(
        title(
          RouteContext(type: RouteType.profile, npub: otherUserNpub),
          displayName: 'Ada',
        ),
        equals('Ada'),
      );
    });

    test('ignores an npub-shaped display name, which is the placeholder', () {
      expect(
        title(
          RouteContext(type: RouteType.profile, npub: otherUserNpub),
          displayName: otherUserNpub,
        ),
        equals(l10n.navProfile),
      );
    });

    test('falls back to Profile before the display name arrives', () {
      expect(
        title(RouteContext(type: RouteType.profile, npub: otherUserNpub)),
        equals(l10n.navProfile),
      );
    });

    test('renders no title for routes that own their header', () {
      expect(title(const RouteContext(type: RouteType.settings)), isEmpty);
      expect(title(null), isEmpty);
    });
  });

  group('shellTitleProfilePubkeyHex', () {
    test('resolves the pubkey whose name the title needs', () {
      expect(
        shellTitleProfilePubkeyHex(
          RouteContext(type: RouteType.profile, npub: otherUserNpub),
        ),
        equals(_otherUserHex),
      );
    });

    test('is null for the own-profile shorthand, which needs no lookup', () {
      expect(
        shellTitleProfilePubkeyHex(
          const RouteContext(type: RouteType.profile, npub: 'me'),
        ),
        isNull,
      );
    });

    test('is null off a profile route', () {
      expect(
        shellTitleProfilePubkeyHex(const RouteContext(type: RouteType.explore)),
        isNull,
      );
    });

    test('is null for an unparseable npub', () {
      expect(
        shellTitleProfilePubkeyHex(
          const RouteContext(type: RouteType.profile, npub: 'not-an-npub'),
        ),
        isNull,
      );
    });
  });

  group('shellShowsBackButton', () {
    bool showsFor(RouteContext? context) =>
        shellShowsBackButton(context: context, currentUserHex: _viewerHex);

    test('hides before the route context resolves', () {
      expect(showsFor(null), isFalse);
    });

    test('hides on the explore grid', () {
      expect(showsFor(const RouteContext(type: RouteType.explore)), isFalse);
    });

    test('shows on an explore video, including index 0', () {
      expect(
        showsFor(const RouteContext(type: RouteType.explore, videoIndex: 0)),
        isTrue,
      );
    });

    test('hides on the notifications base state, which is index 0', () {
      expect(
        showsFor(
          const RouteContext(type: RouteType.notifications, videoIndex: 0),
        ),
        isFalse,
      );
    });

    test('shows on a notification video past the base state', () {
      expect(
        showsFor(
          const RouteContext(type: RouteType.notifications, videoIndex: 2),
        ),
        isTrue,
      );
    });

    test("shows on another user's profile grid", () {
      expect(
        showsFor(RouteContext(type: RouteType.profile, npub: otherUserNpub)),
        isTrue,
      );
    });

    test('hides on the viewer own profile grid, which owns its header', () {
      expect(
        showsFor(
          RouteContext(
            type: RouteType.profile,
            npub: NostrKeyUtils.encodePubKey(_viewerHex),
          ),
        ),
        isFalse,
      );
    });

    test('shows on the viewer own profile in feed mode', () {
      expect(
        showsFor(
          RouteContext(
            type: RouteType.profile,
            npub: NostrKeyUtils.encodePubKey(_viewerHex),
            videoIndex: 1,
          ),
        ),
        isTrue,
      );
    });
  });

  group('shellSuppressesAppBar', () {
    bool suppressedFor(RouteContext? context, {int currentIndex = 2}) =>
        shellSuppressesAppBar(
          context: context,
          currentIndex: currentIndex,
          currentUserHex: _viewerHex,
        );

    test('suppresses on home, which uses the feed overlay instead', () {
      expect(
        suppressedFor(
          const RouteContext(type: RouteType.home),
          currentIndex: 0,
        ),
        isTrue,
      );
    });

    test('suppresses on the inbox, which owns its segmented header', () {
      expect(suppressedFor(const RouteContext(type: RouteType.inbox)), isTrue);
    });

    test('suppresses on a conversation pushed from the inbox', () {
      expect(
        suppressedFor(const RouteContext(type: RouteType.conversation)),
        isTrue,
      );
    });

    test('suppresses on the explore grid, which owns its search header', () {
      expect(
        suppressedFor(
          const RouteContext(type: RouteType.explore),
          currentIndex: 1,
        ),
        isTrue,
      );
    });

    test('shows the app bar on an explore video', () {
      expect(
        suppressedFor(
          const RouteContext(type: RouteType.explore, videoIndex: 2),
          currentIndex: 1,
        ),
        isFalse,
      );
    });

    test('suppresses on the viewer own profile grid', () {
      expect(
        suppressedFor(
          RouteContext(
            type: RouteType.profile,
            npub: NostrKeyUtils.encodePubKey(_viewerHex),
          ),
          currentIndex: 3,
        ),
        isTrue,
      );
    });

    test('shows the app bar on the viewer own profile in feed mode', () {
      expect(
        suppressedFor(
          RouteContext(
            type: RouteType.profile,
            npub: NostrKeyUtils.encodePubKey(_viewerHex),
            videoIndex: 0,
          ),
          currentIndex: 3,
        ),
        isFalse,
      );
    });

    test("shows the app bar on another user's profile grid", () {
      expect(
        suppressedFor(
          RouteContext(type: RouteType.profile, npub: otherUserNpub),
          currentIndex: 3,
        ),
        isFalse,
      );
    });

    test('shows the app bar on the notifications feed', () {
      expect(
        suppressedFor(
          const RouteContext(type: RouteType.notifications, videoIndex: 0),
        ),
        isFalse,
      );
    });
  });
}
