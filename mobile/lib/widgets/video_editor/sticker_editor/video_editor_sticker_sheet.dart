// ABOUTME: Bottom sheet for sticker selection in the video editor.
// ABOUTME: Features search functionality and a responsive grid of stickers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

/// A bottom sheet that displays a searchable grid of stickers.
///
/// Returns the selected [StickerData] via [context.pop] when a sticker is
/// tapped.
class VideoEditorStickerSheet extends StatelessWidget {
  const VideoEditorStickerSheet({
    this.enableSearchBar = false,
    super.key,
    this.scrollController,
  });

  final ScrollController? scrollController;
  final bool enableSearchBar;

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          // Floating Search Bar Header
          if (enableSearchBar) const _SearchBar(),

          SliverToBoxAdapter(
            child: Padding(
              padding: const .all(16),
              child: Text(
                context.l10n.videoEditorStickersDivineOriginals,
                style: VineTheme.titleSmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
          // Grid with Sticker Icons
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            sliver:
                BlocBuilder<VideoEditorStickerBloc, VideoEditorStickerState>(
                  builder: (context, state) {
                    return switch (state) {
                      VideoEditorStickerInitial() ||
                      VideoEditorStickerLoading() => const SliverToBoxAdapter(
                        child: Center(child: DivineCircularProgressIndicator()),
                      ),
                      VideoEditorStickerLoaded(:final stickers)
                          when stickers.isNotEmpty =>
                        _StickerGrid(stickers: stickers),
                      VideoEditorStickerLoaded(:final hasSearchQuery) =>
                        _EmptyState(
                          message: hasSearchQuery
                              ? context.l10n.videoEditorNoStickersFound
                              : context.l10n.videoEditorNoStickersAvailable,
                        ),
                      VideoEditorStickerError() => _EmptyState(
                        message: context.l10n.videoEditorFailedLoadStickers,
                      ),
                    };
                  },
                ),
          ),
        ],
      ),
    );
  }
}

/// A responsive grid displaying stickers with tap-to-select functionality.
class _StickerGrid extends StatelessWidget {
  const _StickerGrid({required this.stickers});

  /// The list of stickers to display in the grid.
  final List<StickerData> stickers;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final sticker = stickers[index];
        return VideoEditorSticker(
          onTap: () => context.pop(sticker),
          sticker: sticker,
        );
      }, childCount: stickers.length),
    );
  }
}

/// Empty state widget shown when no stickers are available or found.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  /// The message to display (e.g., "No stickers found").
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Text(
        message,
        style: VineTheme.bodyLargeFont(
          color: context.vineColors.onSurfaceMuted,
        ),
        textAlign: .center,
      ),
    );
  }
}

/// A floating search bar for filtering stickers by name or tags.
class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
    _setQuery('');
  }

  void _setQuery(String value) {
    context.read<VideoEditorStickerBloc>().add(VideoEditorStickerSearch(value));
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      backgroundColor: context.vineColors.surface,
      surfaceTintColor: VineTheme.transparent,
      toolbarHeight: 64,
      flexibleSpace: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          keyboardType: .text,
          textInputAction: .search,
          style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
          onChanged: _setQuery,
          onSubmitted: (_) => _focusNode.unfocus(),
          decoration: InputDecoration(
            hintText: context.l10n.videoEditorStickerSearchHint,
            hintStyle: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            filled: true,
            fillColor: context.vineColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: .circular(20),
              borderSide: .none,
            ),
            contentPadding: const .symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Padding(
              padding: const .only(left: 16, right: 12),
              child: DivineIcon(
                icon: .search,
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            suffixIcon:
                BlocSelector<
                  VideoEditorStickerBloc,
                  VideoEditorStickerState,
                  bool
                >(
                  selector: (state) =>
                      state is VideoEditorStickerLoaded && state.hasSearchQuery,
                  builder: (context, hasSearchQuery) {
                    return hasSearchQuery
                        ? IconButton(
                            icon: DivineIcon(
                              icon: .x,
                              color: context.vineColors.onSurfaceMuted,
                            ),
                            onPressed: _clearSearch,
                          )
                        : const SizedBox.shrink();
                  },
                ),
          ),
        ),
      ),
    );
  }
}
