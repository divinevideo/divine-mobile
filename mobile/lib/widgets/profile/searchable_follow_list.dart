// ABOUTME: Search field plus filtered user list for followers/following screens
// ABOUTME: Reads the query from FollowListSearchBloc and renders the matches

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Builds the row rendered for [pubkey] at [index] in a follow list.
typedef FollowListItemBuilder = Widget Function(
  BuildContext context,
  String pubkey,
  int index,
);

/// A pull-to-refresh user list with the design's search field pinned above it.
///
/// Expects an ambient [FollowListSearchBloc] and a non-empty [pubkeys]. The
/// screen keeps ownership of the list and of its own "nobody follows you yet"
/// empty state; this widget only narrows what is shown to the query matches.
class SearchableFollowList extends StatefulWidget {
  /// Creates the searchable list.
  const SearchableFollowList({
    required this.pubkeys,
    required this.itemBuilder,
    required this.onRefresh,
    super.key,
  });

  /// The full, already blocklist-filtered list to render and search.
  final List<String> pubkeys;

  /// Builds one row of the list.
  final FollowListItemBuilder itemBuilder;

  /// Invoked when the user pulls to refresh.
  final Future<void> Function() onRefresh;

  @override
  State<SearchableFollowList> createState() => _SearchableFollowListState();
}

class _SearchableFollowListState extends State<SearchableFollowList> {
  final _controller = TextEditingController();
  late List<String> _visiblePubkeys;

  @override
  void initState() {
    super.initState();
    _visiblePubkeys = widget.pubkeys;
  }

  @override
  void didUpdateWidget(SearchableFollowList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh can add rows while a query is on screen. The BLoC resolves
    // names for the list it was handed with the query, so without this the new
    // rows could only ever match their generated fallback name.
    if (!listEquals(oldWidget.pubkeys, widget.pubkeys)) {
      _visiblePubkeys = context.read<FollowListSearchBloc>().state.visibleFrom(
        widget.pubkeys,
      );
      if (_controller.text.isNotEmpty) {
        _onQueryChanged(_controller.text);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    context.read<FollowListSearchBloc>().add(
      FollowListSearchQueryChanged(query, widget.pubkeys),
    );
  }

  void _syncVisiblePubkeys(FollowListSearchState state) {
    final visible = state.visibleFrom(widget.pubkeys);
    if (listEquals(visible, _visiblePubkeys)) return;
    setState(() {
      _visiblePubkeys = visible;
    });
    if (state.query.isNotEmpty && visible.isEmpty) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.searchNoResultsFound(state.query),
        Directionality.of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: DivineSearchBar(
            controller: _controller,
            hintText: context.l10n.exploreSearchHint,
            onChanged: _onQueryChanged,
          ),
        ),
        Expanded(
          child: BlocConsumer<FollowListSearchBloc, FollowListSearchState>(
            listener: (context, state) => _syncVisiblePubkeys(state),
            builder: (context, state) {
              return RefreshIndicator(
                color: VineTheme.onPrimary,
                backgroundColor: VineTheme.vineGreen,
                onRefresh: widget.onRefresh,
                // Wraps the no-match case too: a stale list is exactly when a
                // user reaches for pull-to-refresh, and losing the gesture
                // there would strand them until they clear the field.
                child: _visiblePubkeys.isEmpty
                    ? _NoMatches(query: state.query)
                    : ListView.builder(
                        itemCount: _visiblePubkeys.length,
                        itemBuilder: (context, index) => widget.itemBuilder(
                          context,
                          _visiblePubkeys[index],
                          index,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    // Scrollable rather than a bare Center so the enclosing RefreshIndicator
    // still has a gesture to attach to when nothing matches.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.searchNoResultsFound(query),
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
