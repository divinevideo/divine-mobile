// ABOUTME: Full-screen grid of the viewer's NIP-51 kind 10003 bookmarked videos
// ABOUTME: Reached from the Bookmarks entry at the top of the profile Lists tab

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';

/// The viewer's bookmarked videos.
///
/// Bookmarks are a NIP-51 kind 10003 list, so this is the reading surface for
/// the same collection the share sheet's Save action writes to. It lives
/// behind an entry in the profile's Lists tab rather than a tab of its own —
/// a bookmark list is one of the viewer's lists, it just isn't a kind 30005
/// one.
class SavedVideosScreen extends ConsumerWidget {
  const SavedVideosScreen({super.key});

  static const routeName = 'savedVideos';
  static const path = '/saved-videos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.watch(videosRepositoryProvider);
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;

    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: const SavedVideosAppBar(),
      body: BlocProvider<ProfileSavedVideosBloc>(
        // Re-created when either captured dependency changes identity, so an
        // account switch cannot leave the grid reading the previous viewer's
        // bookmarks (see rules/state_management.md).
        key: ValueKey((videosRepository, currentUserPubkey)),
        create: (_) => ProfileSavedVideosBloc(
          bookmarksRepository: ref.read(bookmarksRepositoryProvider.future),
          videosRepository: videosRepository,
          currentUserPubkey: currentUserPubkey,
          removedVideoIds: videosRepository.removedVideoIds,
          deletedVideoFilter: videosRepository.isVideoKnownDeleted,
        )..add(const ProfileSavedVideosSyncRequested()),
        child: SavedVideosView(userIdHex: currentUserPubkey),
      ),
    );
  }
}

/// The screen's app bar, split out so its back affordance can be driven in
/// tests without the screen's bookmark and video dependencies.
@visibleForTesting
class SavedVideosAppBar extends StatelessWidget implements PreferredSizeWidget {
  @visibleForTesting
  const SavedVideosAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      // Explicit rather than automaticallyImplyLeading: a divine:// deep link
      // lands here with a one-entry stack, and the screen sits outside the
      // shell, so Material would render no back button and there is no bottom
      // nav either — a dead end. safePop falls back to the feed.
      leading: DivineIconButton(
        icon: DivineIconName.caretLeft,
        type: DivineIconButtonType.ghostSecondary,
        size: DivineIconButtonSize.small,
        showShadow: false,
        semanticLabel: context.l10n.commonBack,
        onPressed: context.safePop,
      ),
      title: Text(
        context.l10n.shareMenuBookmarks,
        style: VineTheme.titleMediumFont(color: context.vineColors.onNav),
      ),
    );
  }
}

/// Grid plus its pull-to-refresh, split out so it can be driven in tests
/// against a mocked [ProfileSavedVideosBloc] rather than the screen's real
/// bookmark and video dependencies.
@visibleForTesting
class SavedVideosView extends StatefulWidget {
  @visibleForTesting
  const SavedVideosView({required this.userIdHex, super.key});

  final String userIdHex;

  @override
  State<SavedVideosView> createState() => _SavedVideosViewState();
}

class _SavedVideosViewState extends State<SavedVideosView> {
  /// Owned here because [ProfileSavedGrid] paginates off the primary
  /// controller. On the profile it came from the enclosing `NestedScrollView`;
  /// this screen has to supply one.
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() {
    final completer = Completer<void>();
    context.read<ProfileSavedVideosBloc>().add(
      ProfileSavedVideosSyncRequested(completer: completer),
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _scrollController,
      child: RefreshIndicator(
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
        onRefresh: _onRefresh,
        child: ProfileSavedGrid(userIdHex: widget.userIdHex),
      ),
    );
  }
}
