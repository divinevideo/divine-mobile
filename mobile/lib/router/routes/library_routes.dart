// ABOUTME: Library routes (drafts / clips / clips-only / sounds tabs, add sound)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/sounds/add_sound_page.dart';

part 'library_routes.g.dart';

List<RouteBase> libraryRoutes() => $appRoutes;

@TypedGoRoute<LibraryDraftsRouteData>(
  path: LibraryScreen.draftsPath,
  name: LibraryScreen.draftsRouteName,
)
class LibraryDraftsRouteData extends GoRouteData with $LibraryDraftsRouteData {
  const LibraryDraftsRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadeUpwardsPage(state: state, child: const LibraryScreen());
}

@TypedGoRoute<LibraryClipsRouteData>(
  path: LibraryScreen.clipsPath,
  name: LibraryScreen.clipsRouteName,
)
class LibraryClipsRouteData extends GoRouteData with $LibraryClipsRouteData {
  const LibraryClipsRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(initialTabIndex: 1),
      );
}

@TypedGoRoute<LibraryClipsOnlyRouteData>(
  path: LibraryScreen.clipsOnlyPath,
  name: LibraryScreen.clipsOnlyRouteName,
)
class LibraryClipsOnlyRouteData extends GoRouteData
    with $LibraryClipsOnlyRouteData {
  const LibraryClipsOnlyRouteData({
    @TypedQueryParameter(name: 'type') this.type,
  });

  /// Scopes the clips to the recorder's mode (stop-motion vs normal), as a
  /// [LibraryClipTypeFilter.queryValue]; absent lists both types, the
  /// standalone default.
  final String? type;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadeUpwardsPage(
        state: state,
        child: LibraryScreen(
          initialTabIndex: 1,
          tabsMode: LibraryTabsMode.withoutSounds,
          // The recorder session owns the autosave draft, so listing it here
          // would offer the user their own live session to reopen.
          includeAutosaveDraft: false,
          clipTypeFilter: LibraryClipTypeFilter.fromQuery(type),
        ),
      );
}

@TypedGoRoute<LibrarySoundsRouteData>(
  path: LibraryScreen.soundsPath,
  name: LibraryScreen.soundsRouteName,
  routes: [
    // Nested so back from Add sound lands on the Sounds tab, where the added
    // sound is already listed.
    TypedGoRoute<AddSoundRouteData>(
      path: AddSoundPage.subpath,
      name: AddSoundPage.routeName,
    ),
  ],
)
class LibrarySoundsRouteData extends GoRouteData with $LibrarySoundsRouteData {
  const LibrarySoundsRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(initialTabIndex: 2),
      );
}

class AddSoundRouteData extends GoRouteData with $AddSoundRouteData {
  const AddSoundRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AddSoundPage();
}
