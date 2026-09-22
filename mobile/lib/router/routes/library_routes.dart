// ABOUTME: Library routes (drafts / clips / clips-only / sounds / scheduled
// ABOUTME: tabs, sound upload)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/sound_upload/sound_upload_screen.dart';

List<RouteBase> libraryRoutes() {
  return [
    GoRoute(
      path: LibraryScreen.draftsPath,
      name: LibraryScreen.draftsRouteName,
      pageBuilder: (_, state) =>
          fadeUpwardsPage(state: state, child: const LibraryScreen()),
    ),
    GoRoute(
      path: LibraryScreen.clipsPath,
      name: LibraryScreen.clipsRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(initialTabIndex: 1),
      ),
    ),
    GoRoute(
      path: LibraryScreen.clipsOnlyPath,
      name: LibraryScreen.clipsOnlyRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        // `type` scopes the clips to the recorder's mode (stop-motion vs normal);
        // absent → both types (the standalone default).
        child: LibraryScreen(
          initialTabIndex: 1,
          tabsMode: LibraryTabsMode.withoutSounds,
          // The recorder session owns the autosave draft, so listing it here
          // would offer the user their own live session to reopen.
          includeAutosaveDraft: false,
          clipTypeFilter: LibraryClipTypeFilter.fromQuery(
            state.uri.queryParameters['type'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: LibraryScreen.soundsPath,
      name: LibraryScreen.soundsRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(initialTabIndex: 2),
      ),
      routes: [
        // Nested so back from the upload lands on the Sounds tab, where the
        // shared sound is already listed.
        GoRoute(
          path: SoundUploadScreen.subpath,
          name: SoundUploadScreen.routeName,
          builder: (_, _) => const SoundUploadScreen(),
        ),
      ],
    ),
    GoRoute(
      path: LibraryScreen.scheduledPath,
      name: LibraryScreen.scheduledRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(
          initialTabIndex: LibraryScreen.scheduledTabIndex,
        ),
      ),
    ),
  ];
}
