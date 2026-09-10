import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';

/// App bar for the search results screen.
///
/// Receives its [TextEditingController] from the parent (so the body can
/// read the same live text) and owns the [FocusNode] and listener
/// lifecycle. Dispatches `*QueryChanged` events to the four search BLoCs
/// on text changes.
class SearchResultsAppBar extends StatefulWidget {
  const SearchResultsAppBar({
    required this.controller,
    required this.initialQuery,
    this.requestFocusOnMount = false,
    super.key,
  });

  /// Shared text controller. Owned and disposed by the parent so the body
  /// can subscribe to the same live value for its idle-placeholder gate.
  final TextEditingController controller;

  /// Pre-filled search text. The parent seeds [controller] with this value
  /// at construction; we use it here only to decide whether to (a) dispatch
  /// the initial query synchronously and (b) request focus on mount.
  final String initialQuery;

  /// When true, a prefilled search field claims focus after the first frame.
  ///
  /// Route call sites must opt in explicitly so prefilled destinations like
  /// mention taps and search deep links can keep the keyboard dismissed.
  ///
  /// Empty-query mounts still request focus by default.
  final bool requestFocusOnMount;

  @override
  State<SearchResultsAppBar> createState() => _SearchResultsAppBarState();
}

class _SearchResultsAppBarState extends State<SearchResultsAppBar> {
  late final FocusNode _focusNode;

  // Last text we dispatched to the BLoCs. The TextField's EditableText
  // mutates the controller's selection (cursor position) on attach and
  // on focus changes, which fires the same listener — without this
  // guard we'd dispatch duplicate `*QueryChanged` events for
  // selection-only updates that don't change the query at all.
  late String _lastDispatchedQuery;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _lastDispatchedQuery = widget.initialQuery;

    if (widget.initialQuery.isNotEmpty) {
      // Dispatch the prefilled query once at mount. The parent seeds the
      // controller in its own `initState` before we attach the listener
      // below, so the listener will not fire for that initial value and
      // the BLoCs would otherwise stay in `initial` for the first
      // `searchDebounceDuration` (300ms) after navigation. Each BLoC
      // applies its own `debounceRestartable` transformer, so this is
      // the only debounce in the pipeline — kicking it off here starts
      // the timer at mount time rather than 300ms later. The misleading
      // idle placeholder during Explore → Search transitions (#3802) is
      // separately suppressed by `SearchResultsView` driving its idle
      // gate from live `controller.text`, not from the BLoC status.
      _dispatchQuery(widget.initialQuery);
    }

    if (widget.requestFocusOnMount || widget.initialQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }

    // Attach the listener AFTER the initial dispatch so the controller's
    // pre-seeded text (set in the parent's initState) does not produce a
    // duplicate event.
    widget.controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSearchChanged);
    _focusNode.dispose();
    super.dispose();
  }

  // Dispatch immediately on every edit. The four search BLoCs each apply
  // `debounceRestartable` (300ms) to their `*QueryChanged` events, so
  // adding a UI-level debounce here would stack with that and double the
  // user-perceived latency on typing and clearing.
  void _onSearchChanged() {
    final query = widget.controller.text;
    if (query == _lastDispatchedQuery) return;
    _lastDispatchedQuery = query;
    _dispatchQuery(query);
  }

  void _dispatchQuery(String query) {
    context.read<VideoSearchBloc>().add(VideoSearchQueryChanged(query));
    context.read<UserSearchBloc>().add(UserSearchQueryChanged(query));
    context.read<HashtagSearchBloc>().add(HashtagSearchQueryChanged(query));
    context.read<ListSearchBloc>().add(ListSearchQueryChanged(query));
  }

  // Pop when there's a back stack; otherwise fall back to Explore. A cold-start
  // deep link can enter search with nothing to pop — a bare
  // `Navigator.maybePop()` would then silently do nothing and strand the user.
  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(ExploreScreen.path);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 8,
          children: [
            DivineIconButton(
              icon: DivineIconName.caretLeft,
              type: DivineIconButtonType.secondary,
              size: DivineIconButtonSize.small,
              onPressed: _handleBack,
              semanticLabel: context.l10n.commonBack,
              semanticIdentifier: SemanticIds.searchBackButton,
            ),
            Expanded(
              child: DivineSearchBar(
                controller: widget.controller,
                focusNode: _focusNode,
                hintText: context.l10n.exploreSearchHint,
                suffixIcon: const SearchFilterPill(),
                semanticIdentifier: SemanticIds.searchField,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
