import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';

/// Page that creates and wires the search BLoCs, then renders
/// [SearchResultsView].
class SearchResultsPage extends ConsumerWidget {
  const SearchResultsPage({
    this.initialQuery,
    this.requestFocusOnMount = false,
    super.key,
  });

  /// Optional pre-filled search query from the route.
  final String? initialQuery;

  /// Whether the search field should claim keyboard focus on first paint.
  final bool requestFocusOnMount;

  /// Base path prefix (used for route matching and normalization skips).
  static const pathPrefix = '/search-results';

  /// Route path pattern for opening search without a prefilled query.
  static const String emptyPath = pathPrefix;

  /// Route path pattern for GoRouter.
  static const path = '$pathPrefix/:query';

  /// Query parameter used to opt a prefilled route into mount focus.
  static const requestFocusQueryParameter = 'focus';

  /// Build a path with the given query and explicit mount-focus intent.
  static String pathForQuery(
    String query, {
    required bool requestFocusOnMount,
  }) {
    final encodedQuery = Uri.encodeComponent(query);
    if (!requestFocusOnMount) return '$pathPrefix/$encodedQuery';
    return '$pathPrefix/$encodedQuery?$requestFocusQueryParameter=1';
  }

  /// Build a path that opens search without a prefilled query.
  static String pathForEmptyQuery({required bool requestFocusOnMount}) {
    if (!requestFocusOnMount) return emptyPath;
    return '$emptyPath?$requestFocusQueryParameter=1';
  }

  /// Returns whether a routed prefilled search should claim keyboard focus.
  static bool requestFocusOnMountForRoute(Uri uri) =>
      uri.queryParameters[requestFocusQueryParameter] == '1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.read(profileRepositoryProvider);
    if (profileRepository == null) return const SizedBox.shrink();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => VideoSearchBloc(
            videosRepository: ref.read(videosRepositoryProvider),
          ),
        ),
        BlocProvider(
          create: (_) => UserSearchBloc(profileRepository: profileRepository),
        ),
        BlocProvider(create: (_) => SearchResultsFilterCubit()),
        BlocProvider(
          create: (_) => HashtagSearchBloc(
            hashtagRepository: ref.read(hashtagRepositoryProvider),
          ),
        ),
        BlocProvider(
          create: (_) => ListSearchBloc(
            curatedListRepository: ref.read(curatedListRepositoryProvider),
            peopleListsRepository: ref.read(peopleListsRepositoryProvider),
            peopleListSearchEnabled: ref.read(
              isFeatureEnabledProvider(FeatureFlag.profileListFeatures),
            ),
          ),
        ),
      ],
      child: _BlocklistRefreshListener(
        child: Scaffold(
          // bg/surface — matches SearchResultsView's body background so the
          // app bar area (which doesn't paint its own background) doesn't
          // show through to the root scaffold's darker default.
          backgroundColor: context.vineColors.surface,
          body: _SearchResultsBody(
            initialQuery: initialQuery ?? '',
            requestFocusOnMount: requestFocusOnMount,
          ),
        ),
      ),
    );
  }
}

/// Re-runs the active searches when the blocklist changes, so an author
/// blocked from a result's profile disappears from still-open search
/// results without a manual re-search (and reappears after an unblock).
///
/// Re-dispatching the current query is safe: every search bloc debounces
/// and uses a restartable transformer, and results are re-fetched through
/// repository paths that apply the block filter.
class _BlocklistRefreshListener extends ConsumerWidget {
  const _BlocklistRefreshListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(blocklistVersionProvider, (previous, next) {
      if (previous == next) return;
      context.read<VideoSearchBloc>().add(const VideoSearchBlocklistChanged());
      context.read<HashtagSearchBloc>().add(
        const HashtagSearchBlocklistChanged(),
      );
      context.read<ListSearchBloc>().add(const ListSearchBlocklistChanged());
      // UserSearchBloc has no same-query guard (see its _onQueryChanged),
      // so re-dispatching the current query re-runs the search as-is.
      final userQuery = context.read<UserSearchBloc>().state.query;
      if (userQuery.isNotEmpty) {
        context.read<UserSearchBloc>().add(UserSearchQueryChanged(userQuery));
      }
    });
    return child;
  }
}

/// Wires the app bar and body together, owning the search field's
/// [TextEditingController] so both children read the same live value.
///
/// The controller is hoisted here (rather than created inside the app bar)
/// so [SearchResultsView] can drive its idle-placeholder decision from the
/// user's current input. Using the live text — not the route arg —
/// correctly returns the view to the idle placeholder when the user clears
/// or shortens a prefilled query after landing on /search-results/:query.
class _SearchResultsBody extends StatefulWidget {
  const _SearchResultsBody({
    required this.initialQuery,
    required this.requestFocusOnMount,
  });

  final String initialQuery;
  final bool requestFocusOnMount;

  @override
  State<_SearchResultsBody> createState() => _SearchResultsBodyState();
}

class _SearchResultsBodyState extends State<_SearchResultsBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchResultsAppBar(
          controller: _controller,
          initialQuery: widget.initialQuery,
          requestFocusOnMount: widget.requestFocusOnMount,
        ),
        Expanded(child: SearchResultsView(controller: _controller)),
      ],
    );
  }
}
