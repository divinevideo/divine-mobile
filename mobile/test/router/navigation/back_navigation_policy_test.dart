// ABOUTME: Table-driven tests for the one shared back-navigation decision
// ABOUTME: Covers the three defects #3337 found across its divergent copies

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/navigation/back_action.dart';
import 'package:openvine/router/navigation/back_navigation_policy.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';

const _npub = 'npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mhnm87echrgufzsevkk5s';

BackAction resolve(
  RouteContext? context, {
  bool canPop = false,
  int? previousTab,
  int? lastIndexForPreviousTab,
  String? currentUserNpub,
}) => resolveBackAction(
  context: context,
  canPop: canPop,
  previousTab: previousTab,
  lastIndexForPreviousTab: lastIndexForPreviousTab,
  currentUserNpub: currentUserNpub,
);

void main() {
  group('resolveBackAction', () {
    group('no route context', () {
      test('is unhandled when the context has not resolved yet', () {
        expect(resolve(null, canPop: true), equals(const BackUnhandled()));
      });
    });

    group('campaign landing', () {
      const campaignLanding = RouteContext(
        type: RouteType.following,
        npub: RoutePaths.followingNewSubject,
      );

      test('goes home on a cold start instead of closing the app', () {
        // /following/new is a cold-start destination with nothing beneath it,
        // so reporting the press unhandled would finish the Android activity.
        expect(
          resolve(campaignLanding),
          equals(BackGoTo(RoutePaths.videoFeedForIndex(0))),
        );
      });

      test('pops when the landing is pushed over another route', () {
        expect(
          resolve(campaignLanding, canPop: true),
          equals(const BackPop()),
        );
      });

      test('leaves a following people list unhandled at base', () {
        expect(
          resolve(const RouteContext(type: RouteType.following, npub: _npub)),
          equals(const BackUnhandled()),
        );
      });
    });

    group('pushed editor flows', () {
      for (final type in const [
        RouteType.videoRecorder,
        RouteType.videoEditor,
        RouteType.videoMetadata,
        RouteType.videoEdit,
        RouteType.subtitleEdit,
      ]) {
        test('pops $type', () {
          expect(
            resolve(RouteContext(type: type), canPop: true),
            equals(const BackPop()),
          );
        });
      }
    });

    group('pushed editor flows with nothing beneath them', () {
      // Not reachable through any link the deep-link parser produces — it
      // emits no editor DeepLinkType — but returning "unhandled" here would
      // close the app on Android, which is the exact failure this policy
      // exists to prevent. Raised in review on #8083.
      for (final type in const [
        RouteType.videoRecorder,
        RouteType.videoEditor,
        RouteType.videoMetadata,
        RouteType.videoEdit,
        RouteType.subtitleEdit,
      ]) {
        test('sends $type home rather than off the end of the stack', () {
          expect(
            resolve(RouteContext(type: type)),
            equals(const BackGoTo('/home/0')),
          );
        });
      }
    });

    group('category gallery', () {
      test('pops when there is a stack to pop', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.categoryGallery),
            canPop: true,
          ),
          equals(const BackPop()),
        );
      });

      test('falls back to explore when deep-linked', () {
        expect(
          resolve(const RouteContext(type: RouteType.categoryGallery)),
          equals(const BackGoTo('/explore')),
        );
      });
    });

    group('hashtag', () {
      // #3337 P2: the two live copies disagreed here — one popped, the other
      // replaced the stack with /explore. Popping keeps the user where they
      // actually came from.
      test('pops the grid rather than jumping to explore', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.hashtag, hashtag: 'flutter'),
            canPop: true,
          ),
          equals(const BackPop()),
        );
      });

      test('falls back to explore when the grid was deep-linked', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.hashtag, hashtag: 'flutter'),
          ),
          equals(const BackGoTo('/explore')),
        );
      });

      // This arm existed only in main.dart's copy, which never ran. The live
      // Android copy had no hashtag arm at all and dumped the user on /explore.
      test('returns a hashtag video to that hashtag grid', () {
        expect(
          resolve(
            const RouteContext(
              type: RouteType.hashtag,
              hashtag: 'flutter',
              videoIndex: 4,
            ),
            canPop: true,
          ),
          equals(const BackGoTo('/hashtag/flutter')),
        );
      });

      test('percent-encodes the tag on the way back to the grid', () {
        expect(
          resolve(
            const RouteContext(
              type: RouteType.hashtag,
              hashtag: 'a b',
              videoIndex: 1,
            ),
          ),
          equals(const BackGoTo('/hashtag/a%20b')),
        );
      });

      test('falls back to explore when the tag is missing', () {
        expect(
          resolve(const RouteContext(type: RouteType.hashtag, videoIndex: 1)),
          equals(const BackGoTo('/explore')),
        );
      });
    });

    group('feed mode returns to the route base state first', () {
      test('explore video index 0 still returns to the grid', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.explore, videoIndex: 0),
            canPop: true,
          ),
          equals(const BackGoTo('/explore')),
        );
      });

      test('profile video returns to that profile grid', () {
        expect(
          resolve(
            const RouteContext(
              type: RouteType.profile,
              npub: _npub,
              videoIndex: 2,
            ),
          ),
          equals(const BackGoTo('/profile/$_npub')),
        );
      });

      test('profile video with no npub returns to the own-profile grid', () {
        expect(
          resolve(const RouteContext(type: RouteType.profile, videoIndex: 2)),
          equals(const BackGoTo('/profile/me')),
        );
      });

      test('notification video returns to notification index 0', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.notifications, videoIndex: 3),
          ),
          equals(const BackGoTo('/notifications/0')),
        );
      });

      test('notification index 0 is the base state, not feed mode', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.notifications, videoIndex: 0),
            previousTab: 0,
          ),
          equals(const BackGoTo('/home/0', consumesTabHistory: true)),
        );
      });

      test('home video returns to home index 0', () {
        expect(
          resolve(const RouteContext(type: RouteType.home, videoIndex: 6)),
          equals(const BackGoTo('/home/0')),
        );
      });

      test('home index 0 is the base state, not feed mode', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.home, videoIndex: 0),
            previousTab: 1,
          ),
          equals(const BackGoTo('/explore', consumesTabHistory: true)),
        );
      });
    });

    group('pushed routes pop before tab history is consulted', () {
      test('pops a pushed settings screen instead of switching tabs', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.settings),
            canPop: true,
            previousTab: 0,
          ),
          equals(const BackPop()),
        );
      });

      test('pops another user profile grid back to where it was opened', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.profile, npub: _npub),
            canPop: true,
          ),
          equals(const BackPop()),
        );
      });
    });

    group('returning to the previous tab', () {
      test('resumes home at its remembered index', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.explore),
            previousTab: 0,
            lastIndexForPreviousTab: 7,
          ),
          equals(const BackGoTo('/home/7', consumesTabHistory: true)),
        );
      });

      test('resumes explore at its grid when nothing is remembered', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.inbox),
            previousTab: 1,
          ),
          equals(const BackGoTo('/explore', consumesTabHistory: true)),
        );
      });

      test('resumes explore at its remembered index', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.inbox),
            previousTab: 1,
            lastIndexForPreviousTab: 3,
          ),
          equals(const BackGoTo('/explore/3', consumesTabHistory: true)),
        );
      });

      test('resumes tab 2 at the inbox, its bottom-nav destination', () {
        expect(
          resolve(const RouteContext(type: RouteType.explore), previousTab: 2),
          equals(const BackGoTo('/inbox', consumesTabHistory: true)),
        );
      });

      test('resumes tab 2 in the notification feed the user had open', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.explore),
            previousTab: 2,
            lastIndexForPreviousTab: 4,
          ),
          equals(const BackGoTo('/notifications/4', consumesTabHistory: true)),
        );
      });

      test('resumes the profile tab for the signed-in user', () {
        expect(
          resolve(
            const RouteContext(type: RouteType.explore),
            previousTab: 3,
            currentUserNpub: _npub,
          ),
          equals(const BackGoTo('/profile/$_npub', consumesTabHistory: true)),
        );
      });

      // The shell's copy had no `else` here and silently did nothing.
      test('falls back to home when there is no signed-in profile', () {
        expect(
          resolve(const RouteContext(type: RouteType.explore), previousTab: 3),
          equals(const BackGoTo('/home/0', consumesTabHistory: true)),
        );
      });
    });

    group('no tab history left', () {
      // The #3337 regression: /inbox reached this point with no tab of its
      // own, returned unhandled, and Android closed the app.
      test('sends the inbox tab home rather than exiting the app', () {
        expect(
          resolve(const RouteContext(type: RouteType.inbox)),
          equals(const BackGoTo('/home/0')),
        );
      });

      test('sends the explore tab home', () {
        expect(
          resolve(const RouteContext(type: RouteType.explore)),
          equals(const BackGoTo('/home/0')),
        );
      });

      test('leaves home itself to the platform', () {
        expect(
          resolve(const RouteContext(type: RouteType.home, videoIndex: 0)),
          equals(const BackUnhandled()),
        );
      });
    });
  });
}
