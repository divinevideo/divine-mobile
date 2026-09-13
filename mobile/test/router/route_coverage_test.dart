// ABOUTME: Validates all app_router.dart routes have corresponding parseRoute cases
// ABOUTME: Prevents route definition/parsing drift that caused the relay-settings bug

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

void main() {
  test('crossposting route is nonvideo for activeVideoIdProvider', () {
    final route = parseRoute(CrosspostingSettingsScreen.path);
    final container = ProviderContainer(
      overrides: [
        pageContextProvider.overrideWithValue(AsyncValue.data(route)),
      ],
    );
    addTearDown(container.dispose);

    expect(route.type, RouteType.crosspostingSettings);
    expect(container.read(activeVideoIdProvider), isNull);
  });

  group('Route Coverage Validation', () {
    group('Settings routes parse to their own RouteTypes', () {
      // Each settings sub-route has its own RouteType to prevent
      // routeNormalizationProvider from redirecting them to /settings
      test('${SettingsScreen.path} parses to RouteType.settings', () {
        final context = parseRoute(SettingsScreen.path);
        expect(context.type, RouteType.settings);
      });

      test('${AppsDirectoryScreen.path} parses to RouteType.settings', () {
        final context = parseRoute(AppsDirectoryScreen.path);
        expect(context.type, RouteType.settings);
        expect(context.appSlug, '');
      });

      test(
        '${AppDetailScreen.pathForSlug('primal')} parses to RouteType.settings',
        () {
          final context = parseRoute(AppDetailScreen.pathForSlug('primal'));
          expect(context.type, RouteType.settings);
          expect(context.appSlug, 'primal');
        },
      );

      test('${RelaySettingsScreen.path} parses to RouteType.relaySettings', () {
        final context = parseRoute(RelaySettingsScreen.path);
        expect(context.type, RouteType.relaySettings);
      });

      test(
        '${RelayDiagnosticScreen.path} parses to RouteType.relayDiagnostic',
        () {
          final context = parseRoute(RelayDiagnosticScreen.path);
          expect(context.type, RouteType.relayDiagnostic);
        },
      );

      test(
        '${BlossomSettingsScreen.path} parses to RouteType.blossomSettings',
        () {
          final context = parseRoute(BlossomSettingsScreen.path);
          expect(context.type, RouteType.blossomSettings);
        },
      );

      test(
        '${NotificationSettingsScreen.path} parses to RouteType.notificationSettings',
        () {
          final context = parseRoute(NotificationSettingsScreen.path);
          expect(context.type, RouteType.notificationSettings);
        },
      );

      test('${KeyManagementScreen.path} parses to RouteType.keyManagement', () {
        final context = parseRoute(KeyManagementScreen.path);
        expect(context.type, RouteType.keyManagement);
      });

      test(
        '${SafetySettingsScreen.path} parses to RouteType.safetySettings',
        () {
          final context = parseRoute(SafetySettingsScreen.path);
          expect(context.type, RouteType.safetySettings);
        },
      );

      test('${BadgesScreen.path} parses to RouteType.badges', () {
        final context = parseRoute(BadgesScreen.path);
        expect(context.type, RouteType.badges);
      });

      test('${BadgesScreen.path} builds from RouteType.badges', () {
        final path = buildRoute(const RouteContext(type: RouteType.badges));
        expect(path, BadgesScreen.path);
      });

      test(
        '${MonetizationLinksSettingsScreen.path} parses to RouteType.monetizationLinksSettings',
        () {
          final context = parseRoute(MonetizationLinksSettingsScreen.path);
          expect(context.type, RouteType.monetizationLinksSettings);
        },
      );

      test(
        '${MonetizationLinksSettingsScreen.path} round-trips through buildRoute(parseRoute())',
        () {
          final canonical = buildRoute(
            parseRoute(MonetizationLinksSettingsScreen.path),
          );
          expect(canonical, MonetizationLinksSettingsScreen.path);
        },
      );

      // Regression: a nested `/settings/storage` path fell through to
      // RouteType.settings, so routeNormalizationProvider rewrote it to
      // /settings the instant the screen opened — bouncing the user off it.
      test(
        '${StorageManagementPage.path} parses to RouteType.storageManagement',
        () {
          final context = parseRoute(StorageManagementPage.path);
          expect(context.type, RouteType.storageManagement);
        },
      );

      test(
        '${StorageManagementPage.path} round-trips through buildRoute(parseRoute())',
        () {
          final canonical = buildRoute(parseRoute(StorageManagementPage.path));
          expect(canonical, StorageManagementPage.path);
        },
      );

      test('${NostrSettingsScreen.path} parses to RouteType.nostrSettings', () {
        final context = parseRoute(NostrSettingsScreen.path);
        expect(context.type, RouteType.nostrSettings);
      });

      test('${Nip05SettingsScreen.path} parses to RouteType.nip05Settings', () {
        final context = parseRoute(Nip05SettingsScreen.path);
        expect(context.type, RouteType.nip05Settings);
      });

      test(
        '${AppearanceSettingsScreen.path} parses to RouteType.appearanceSettings',
        () {
          final context = parseRoute(AppearanceSettingsScreen.path);
          expect(context.type, RouteType.appearanceSettings);
        },
      );

      test(
        '${AppearanceSettingsScreen.path} round-trips through buildRoute(parseRoute())',
        () {
          final canonical = buildRoute(
            parseRoute(AppearanceSettingsScreen.path),
          );
          expect(canonical, AppearanceSettingsScreen.path);
        },
      );

      test(
        '${CrosspostingSettingsScreen.path} parses to RouteType.crosspostingSettings',
        () {
          final context = parseRoute(CrosspostingSettingsScreen.path);
          expect(context.type, RouteType.crosspostingSettings);
        },
      );

      test(
        '${CrosspostingSettingsScreen.path} round-trips through buildRoute(parseRoute())',
        () {
          final canonical = buildRoute(
            parseRoute(CrosspostingSettingsScreen.path),
          );
          expect(canonical, CrosspostingSettingsScreen.path);
        },
      );

      test(
        '${Nip05SettingsScreen.path} round-trips through buildRoute(parseRoute())',
        () {
          final canonical = buildRoute(parseRoute(Nip05SettingsScreen.path));
          expect(canonical, Nip05SettingsScreen.path);
        },
      );
    });

    group('Profile editing routes parse to RouteType.editProfile', () {
      const profileEditRoutes = [
        ProfileSetupScreen.editPath,
        ProfileSetupScreen.setupPath,
      ];

      for (final route in profileEditRoutes) {
        test('$route parses to RouteType.editProfile', () {
          final context = parseRoute(route);
          expect(
            context.type,
            RouteType.editProfile,
            reason: '$route should parse to RouteType.editProfile',
          );
        });
      }
    });

    group('Clip routes parse to RouteType.clips', () {
      test('${LibraryScreen.clipsPath} parses to RouteType.clips', () {
        final context = parseRoute(LibraryScreen.clipsPath);
        expect(
          context.type,
          RouteType.clips,
          reason: '${LibraryScreen.clipsPath} should parse to RouteType.clips',
        );
      });
    });

    group('Draft routes parse to RouteType.drafts', () {
      test('${LibraryScreen.draftsPath} parses to RouteType.drafts', () {
        final context = parseRoute(LibraryScreen.draftsPath);
        expect(
          context.type,
          RouteType.drafts,
          reason:
              '${LibraryScreen.draftsPath} should parse to RouteType.drafts',
        );
      });
    });

    group('Apps routes build correctly', () {
      test('RouteType.settings builds to ${AppsDirectoryScreen.path}', () {
        final path = buildRoute(
          const RouteContext(type: RouteType.settings, appSlug: ''),
        );
        expect(path, AppsDirectoryScreen.path);
      });

      test('RouteType.settings builds to the slugged detail path', () {
        final path = buildRoute(
          const RouteContext(type: RouteType.settings, appSlug: 'primal'),
        );
        expect(path, AppDetailScreen.pathForSlug('primal'));
      });
    });

    group('Tab routes parse correctly', () {
      test('${VideoFeedPage.path} parses to RouteType.home with index 0', () {
        final context = parseRoute(VideoFeedPage.path);
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test(
        '${VideoFeedPage.pathForIndex(5)} parses to RouteType.home with index 5',
        () {
          final context = parseRoute(VideoFeedPage.pathForIndex(5));
          expect(context.type, RouteType.home);
          expect(context.videoIndex, 5);
        },
      );

      test('${ExploreScreen.path} parses to RouteType.explore', () {
        final context = parseRoute(ExploreScreen.path);
        expect(context.type, RouteType.explore);
        expect(context.videoIndex, isNull);
      });

      test(
        '${ExploreScreen.pathForTab('popular')} parses to RouteType.explore',
        () {
          final context = parseRoute(ExploreScreen.pathForTab('popular'));
          expect(context.type, RouteType.explore);
          expect(context.videoIndex, isNull);
        },
      );

      test(
        '${ExploreScreen.pathForIndex(3)} parses to RouteType.explore with index 3',
        () {
          final context = parseRoute(ExploreScreen.pathForIndex(3));
          expect(context.type, RouteType.explore);
          expect(context.videoIndex, 3);
        },
      );

      test(
        '${NotificationsPage.pathForIndex(0)} parses to RouteType.notifications',
        () {
          final context = parseRoute(NotificationsPage.pathForIndex(0));
          expect(context.type, RouteType.notifications);
          expect(context.videoIndex, 0);
        },
      );

      test(
        '${CategoryGalleryScreen.locationFor('animals')} parses to RouteType.categoryGallery',
        () {
          final context = parseRoute(
            CategoryGalleryScreen.locationFor('animals'),
          );
          expect(context.type, RouteType.categoryGallery);
          expect(context.categoryName, 'animals');
          expect(context.videoIndex, isNull);
        },
      );
    });

    group('Profile routes parse correctly', () {
      test(
        '${ProfileScreenRouter.pathForNpub('npub1abc')} parses to RouteType.profile (grid mode)',
        () {
          final context = parseRoute(
            ProfileScreenRouter.pathForNpub('npub1abc'),
          );
          expect(context.type, RouteType.profile);
          expect(context.npub, 'npub1abc');
          expect(context.videoIndex, isNull); // Grid mode has no index
        },
      );

      test(
        '${ProfileScreenRouter.pathForIndex('npub1abc', 2)} parses to RouteType.profile (feed mode)',
        () {
          final context = parseRoute(
            ProfileScreenRouter.pathForIndex('npub1abc', 2),
          );
          expect(context.type, RouteType.profile);
          expect(context.npub, 'npub1abc');
          expect(context.videoIndex, 2); // Feed mode has index
        },
      );

      test('${ProfileScreenRouter.path} without npub redirects to home', () {
        final context = parseRoute(ProfileScreenRouter.path);
        expect(context.type, RouteType.home);
      });
    });

    group('Hashtag routes parse correctly', () {
      test(
        '${HashtagScreenRouter.pathForTag('nostr')} parses to RouteType.hashtag',
        () {
          final context = parseRoute(HashtagScreenRouter.pathForTag('nostr'));
          expect(context.type, RouteType.hashtag);
          expect(context.hashtag, 'nostr');
          expect(context.videoIndex, isNull);
        },
      );

      test('${HashtagScreenRouter.path} without tag redirects to home', () {
        final context = parseRoute(HashtagScreenRouter.basePath);
        expect(context.type, RouteType.home);
      });
    });

    group('Video detail routes parse correctly', () {
      test(
        '${VideoDetailScreen.pathForId('abc123')} parses to RouteType.videoDetail',
        () {
          final context = parseRoute(VideoDetailScreen.pathForId('abc123'));
          expect(context.type, RouteType.videoDetail);
          expect(context.videoId, 'abc123');
        },
      );

      test('/video without id redirects to home', () {
        final context = parseRoute('/video');
        expect(context.type, RouteType.home);
      });
    });

    group('People list routes parse correctly', () {
      test(
        '${CreatePeopleListPage.path} parses to RouteType.peopleListCreate',
        () {
          final context = parseRoute(CreatePeopleListPage.path);
          expect(context.type, RouteType.peopleListCreate);
        },
      );

      test(
        '/people-lists/list%3A123 parses to RouteType.peopleListMembers',
        () {
          final context = parseRoute('/people-lists/list%3A123');
          expect(context.type, RouteType.peopleListMembers);
          expect(context.listId, 'list:123');
        },
      );

      test('/people-lists/list%3A123/add-people parses to '
          'RouteType.peopleListAddPeople', () {
        final context = parseRoute('/people-lists/list%3A123/add-people');
        expect(context.type, RouteType.peopleListAddPeople);
        expect(context.listId, 'list:123');
      });
    });

    group('Standalone routes parse correctly', () {
      test('${WelcomeScreen.path} parses to RouteType.welcome', () {
        final context = parseRoute(WelcomeScreen.path);
        expect(context.type, RouteType.welcome);
      });

      test('${KeyImportScreen.path} parses to RouteType.importKey', () {
        final context = parseRoute(KeyImportScreen.path);
        expect(context.type, RouteType.importKey);
      });

      test('/video-recorder parses to RouteType.videoRecorder', () {
        final context = parseRoute('/video-recorder');
        expect(context.type, RouteType.videoRecorder);
      });
      test('/video-editor parses to RouteType.videoEditor', () {
        final context = parseRoute('/video-editor');
        expect(context.type, RouteType.videoEditor);
      });
      test('the editor origin query does not change the route type', () {
        // The library entry point carries ?from=library (#3335). A segment
        // match that saw the query would read "video-editor?from=library",
        // match nothing, and fall through to the RouteType.home fallback —
        // which the normalizer then "corrects" by yanking the user to /home/0.
        expect(
          parseRoute(VideoEditorScreen.pathFor(fromLibrary: true)).type,
          RouteType.videoEditor,
        );
        expect(
          parseRoute(
            VideoEditorScreen.pathFor(draftId: 'draft-1', fromLibrary: true),
          ).type,
          RouteType.videoEditor,
        );
      });
      test('/video-edit parses to RouteType.videoEdit', () {
        final context = parseRoute('/video-edit');
        expect(context.type, RouteType.videoEdit);
      });
      test('/video-edit/:videoId parses videoId', () {
        final context = parseRoute(
          VideoMetadataEditScreen.pathFor('test-id-abc'),
        );
        expect(context.type, RouteType.videoEdit);
        expect(context.videoId, 'test-id-abc');
      });
      test('/subtitle-edit parses to RouteType.subtitleEdit', () {
        final context = parseRoute('/subtitle-edit');
        expect(context.type, RouteType.subtitleEdit);
      });
      test('/subtitle-edit/:videoId parses videoId', () {
        final context = parseRoute(SubtitleEditorScreen.pathFor('test-id-abc'));
        expect(context.type, RouteType.subtitleEdit);
        expect(context.videoId, 'test-id-abc');
      });
    });

    group('Edge cases', () {
      test('Empty path defaults to home/0', () {
        final context = parseRoute('');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Root path defaults to home/0', () {
        final context = parseRoute('/');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Unknown route defaults to home/0', () {
        final context = parseRoute('/unknown-route');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Unknown route is not a known normalizable route', () {
        expect(parseKnownRoute('/unknown-route'), isNull);
      });

      test('Negative index is normalized to 0', () {
        final context = parseRoute(VideoFeedPage.pathForIndex(-5));
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Incomplete following route defaults to home without throwing', () {
        expect(() => parseRoute('/following'), returnsNormally);
        final context = parseRoute('/following');
        expect(context.type, RouteType.home);
        expect(parseKnownRoute('/following'), isNull);
      });

      test('Incomplete followers route defaults to home without throwing', () {
        expect(() => parseRoute('/followers'), returnsNormally);
        final context = parseRoute('/followers');
        expect(context.type, RouteType.home);
        expect(parseKnownRoute('/followers'), isNull);
      });
    });

    group('URL encoding is handled', () {
      test('URL-encoded npub is decoded', () {
        final encoded = Uri.encodeComponent('npub1abc+test');
        final context = parseRoute(ProfileScreenRouter.pathForNpub(encoded));
        expect(context.npub, 'npub1abc+test');
      });

      test('URL-encoded hashtag is decoded', () {
        final encoded = Uri.encodeComponent('nostr+bitcoin');
        final context = parseRoute('${HashtagScreenRouter.basePath}/$encoded');
        expect(context.hashtag, 'nostr+bitcoin');
      });
    });

    group('Query and fragment handling', () {
      const videoId =
          '672c4eb9fc29adb6b505713bc6da94af2244c1de55dc6f034e2bcdaba133ebbe';
      const pubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      test('pooled feed query route parses as pooled feed', () {
        final context = parseRoute(
          PooledFullscreenVideoFeedScreen.pathForVideoId(videoId),
        );
        expect(context.type, RouteType.pooledVideoFeed);
      });

      test('people list create query route parses as create route', () {
        final context = parseRoute(
          CreatePeopleListPage.pathWithInitialPubkey(pubkey),
        );
        expect(context.type, RouteType.peopleListCreate);
      });

      test('people list create fragment route parses as create route', () {
        final context = parseRoute('${CreatePeopleListPage.path}#$pubkey');
        expect(context.type, RouteType.peopleListCreate);
      });

      test('people list IDs with malformed encoding do not throw', () {
        expect(() => parseRoute('/people-lists/foo%'), returnsNormally);
        final context = parseRoute('/people-lists/foo%');
        expect(context.type, RouteType.peopleListMembers);
        expect(context.listId, 'foo%');
      });
    });
  });

  group('Route normalization round-trip', () {
    // buildRoute(parseRoute(path)) must equal path for all routes.
    // This is exactly the check routeNormalizationProvider performs;
    // a mismatch causes an unwanted redirect (see /video/:id bug).
    final roundTripCases = {
      'video detail': VideoDetailScreen.pathForId(
        'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
      ),
      'home feed': VideoFeedPage.pathForIndex(3),
      'explore': ExploreScreen.path,
      'explore feed': ExploreScreen.pathForIndex(5),
      'profile grid': ProfileScreenRouter.pathForNpub('npub1test'),
      'profile feed': ProfileScreenRouter.pathForIndex('npub1test', 2),
      'hashtag': HashtagScreenRouter.pathForTag('nostr'),
      'category gallery': CategoryGalleryScreen.locationFor('animals'),
      'settings': SettingsScreen.path,
      'crossposting settings': CrosspostingSettingsScreen.path,
      'monetization links settings': MonetizationLinksSettingsScreen.path,
      'badges': BadgesScreen.path,
      'relay settings': RelaySettingsScreen.path,
      'video edit': VideoMetadataEditScreen.pathFor('test-id-abc'),
      'subtitle edit': SubtitleEditorScreen.pathFor('test-id-abc'),
      'people list create': CreatePeopleListPage.path,
      'people list members': '/people-lists/list%3A123',
      'people list add people': '/people-lists/list%3A123/add-people',
    };

    for (final entry in roundTripCases.entries) {
      test('${entry.key}: ${entry.value} survives normalization', () {
        final canonical = buildRoute(parseRoute(entry.value));
        expect(
          canonical,
          equals(entry.value),
          reason:
              '${entry.key} route would be redirected by normalization '
              '(canonical=$canonical, original=${entry.value})',
        );
      });
    }
  });

  group('Route Coverage Completeness', () {
    // This test documents all routes that should be handled by parseRoute()
    // If a new route is added to app_router.dart, it should be added here too
    test('All RouteTypes have corresponding parseRoute cases', () {
      // Test that each RouteType can be produced by parseRoute
      final routeTypeExamples = {
        RouteType.home: VideoFeedPage.pathForIndex(0),
        RouteType.explore: ExploreScreen.path,
        RouteType.notifications: NotificationsPage.pathForIndex(0),
        RouteType.profile: ProfileScreenRouter.pathForNpub('npub1test'),
        RouteType.hashtag: HashtagScreenRouter.pathForTag('test'),
        RouteType.categoryGallery: CategoryGalleryScreen.locationFor('animals'),
        RouteType.videoRecorder: VideoRecorderScreen.path,
        RouteType.videoEditor: VideoEditorScreen.path,
        RouteType.videoMetadata: VideoMetadataScreen.path,
        RouteType.videoEdit: VideoMetadataEditScreen.pathFor('test-id-abc'),
        RouteType.subtitleEdit: SubtitleEditorScreen.pathFor('test-id-abc'),
        RouteType.importKey: KeyImportScreen.path,
        RouteType.badges: BadgesScreen.path,
        RouteType.settings: SettingsScreen.path,
        RouteType.crosspostingSettings: CrosspostingSettingsScreen.path,
        RouteType.monetizationLinksSettings:
            MonetizationLinksSettingsScreen.path,
        RouteType.relaySettings: RelaySettingsScreen.path,
        RouteType.relayDiagnostic: RelayDiagnosticScreen.path,
        RouteType.blossomSettings: BlossomSettingsScreen.path,
        RouteType.notificationSettings: NotificationSettingsScreen.path,
        RouteType.keyManagement: KeyManagementScreen.path,
        RouteType.safetySettings: SafetySettingsScreen.path,
        RouteType.editProfile: ProfileSetupScreen.editPath,
        RouteType.clips: LibraryScreen.clipsPath,
        RouteType.drafts: LibraryScreen.draftsPath,
        RouteType.welcome: WelcomeScreen.path,
        RouteType.videoDetail: VideoDetailScreen.pathForId('test_id'),
        RouteType.peopleListCreate: CreatePeopleListPage.path,
        RouteType.peopleListMembers: '/people-lists/list%3A123',
        RouteType.peopleListAddPeople: '/people-lists/list%3A123/add-people',
      };

      for (final entry in routeTypeExamples.entries) {
        final expectedType = entry.key;
        final exampleRoute = entry.value;
        final context = parseRoute(exampleRoute);
        expect(
          context.type,
          expectedType,
          reason: 'RouteType.$expectedType should be produced by $exampleRoute',
        );
      }
    });

    // Regression tests for #3413: malformed percent-encoded deep links
    // (e.g. dangling `%`, `%2`, `%ZZ`) used to crash parseRoute when it
    // called Uri.decodeComponent unguarded. parseRoute now routes every
    // segment decode through a safe helper that returns the raw input on
    // ArgumentError. The route type and raw segment are preserved.
    group('Malformed percent-encoded segments do not throw', () {
      const malformedSegments = ['foo%', 'foo%2', 'foo%ZZ', '%'];

      for (final segment in malformedSegments) {
        test('parseRoute(/hashtag/$segment) does not throw', () {
          expect(() => parseRoute('/hashtag/$segment'), returnsNormally);
          final context = parseRoute('/hashtag/$segment');
          expect(context.type, RouteType.hashtag);
          expect(context.hashtag, segment);
        });

        test('parseRoute(/profile/$segment) does not throw', () {
          expect(() => parseRoute('/profile/$segment'), returnsNormally);
          final context = parseRoute('/profile/$segment');
          expect(context.type, RouteType.profile);
          expect(context.npub, segment);
        });

        test('parseRoute(/video/$segment) does not throw', () {
          expect(() => parseRoute('/video/$segment'), returnsNormally);
          final context = parseRoute('/video/$segment');
          expect(context.type, RouteType.videoDetail);
          expect(context.videoId, segment);
        });
      }

      test('parseRoute still decodes well-formed segments correctly', () {
        // Sanity: the safe helper must remain a no-op for valid input.
        final encoded = Uri.encodeComponent('hello world');
        final context = parseRoute('/hashtag/$encoded');
        expect(context.type, RouteType.hashtag);
        expect(context.hashtag, 'hello world');
      });
    });

    group('Curated list routes', () {
      // Both list route shapes must round-trip through
      // buildRoute(parseRoute()) or routeNormalizationProvider rewrites the
      // location the instant the screen opens — bouncing the user off it.
      const authorPubkey =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

      test('/list/:listId parses to RouteType.curatedList', () {
        final context = parseRoute(CuratedListFeedScreen.pathForId('my-list'));
        expect(context.type, RouteType.curatedList);
        expect(context.listId, 'my-list');
        expect(context.npub, isNull);
      });

      test('/list/:listId round-trips through buildRoute(parseRoute())', () {
        final path = CuratedListFeedScreen.pathForId('my-list');
        expect(buildRoute(parseRoute(path)), path);
      });

      test(
        '/list/:pubkey/:listId parses author pubkey and list id separately',
        () {
          final path = CuratedListByAuthorScreen.pathFor(
            pubkey: authorPubkey,
            listId: 'my-vines',
          );
          final context = parseRoute(path);
          expect(context.type, RouteType.curatedList);
          expect(context.npub, authorPubkey);
          expect(context.listId, 'my-vines');
        },
      );

      test(
        '/list/:pubkey/:listId round-trips through buildRoute(parseRoute())',
        () {
          final path = CuratedListByAuthorScreen.pathFor(
            pubkey: authorPubkey,
            listId: 'my-vines',
          );
          expect(buildRoute(parseRoute(path)), path);
        },
      );

      test('/list/:pubkey/:listId with an encoded list id round-trips', () {
        final path = CuratedListByAuthorScreen.pathFor(
          pubkey: authorPubkey,
          listId: 'my favorite vines',
        );
        expect(buildRoute(parseRoute(path)), path);
      });
    });

    group('query parameters do not break route parsing', () {
      // Regression: parseRoute segments the raw location string, so a query
      // parameter used to glue itself onto the last segment
      // ("clips-only?type=video" matched nothing → RouteType.home fallback),
      // and the route normalizer then yanked the user to /home/0 whenever the
      // recorder opened the scoped library.
      test('parseRoute(/clips-only?type=video) parses to clipsOnly', () {
        final context = parseRoute('/clips-only?type=video');
        expect(context.type, RouteType.clipsOnly);
      });

      test('the canonical path of a query-carrying location is stable', () {
        // buildRoute(parseRoute(path)) is the normalizer's canonical form;
        // it must match the path portion so no normalization redirect fires.
        final context = parseRoute('/clips-only?type=stop_motion');
        expect(buildRoute(context), '/clips-only');
      });

      test('parseRoute keeps path indices with a query present', () {
        final context = parseRoute('/home/2?foo=bar');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 2);
      });
    });
  });
}
