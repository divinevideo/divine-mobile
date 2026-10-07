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
class SearchResultsPage extends ConsumerStatefulWidget {
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
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void didUpdateWidget(SearchResultsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _controller.text = widget.initialQuery ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Query and category belong to the page, including readiness gaps.
    return BlocProvider(
      create: (_) => SearchResultsFilterCubit(),
      child: _SearchResultsScope(
        controller: _controller,
        requestFocusOnMount: widget.requestFocusOnMount,
      ),
    );
  }
}

/// Wires result BLoCs only while their account-sensitive repositories are ready.
class _SearchResultsScope extends ConsumerWidget {
  const _SearchResultsScope({
    required this.controller,
    required this.requestFocusOnMount,
  });

  final TextEditingController controller;
  final bool requestFocusOnMount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    if (profileRepository == null) {
      return ColoredBox(
        color: context.vineColors.surface,
        child: const Center(
          child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    final videosRepository = ref.watch(videosRepositoryProvider);
    final hashtagRepository = ref.watch(hashtagRepositoryProvider);
    final curatedListRepository = ref.watch(curatedListRepositoryProvider);
    final listThumbnailPolicy = ref.watch(curatedListThumbnailFilterProvider);
    final peopleListsRepository = ref.watch(peopleListsRepositoryProvider);
    final profileListFeaturesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileListFeatures),
    );
    final curatedListsEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final peopleListSearchEnabled =
        profileListFeaturesEnabled && curatedListsEnabled;

    return MultiBlocProvider(
      // Recreate the search blocs when an auth-sensitive repository or flag
      // changes so no bloc remains bound to stale dependencies or visible previews.
      // See `.claude/rules/state_management.md`.
      key: ValueKey((
        profileRepository,
        videosRepository,
        hashtagRepository,
        curatedListRepository,
        listThumbnailPolicy,
        peopleListsRepository,
        peopleListSearchEnabled,
      )),
      providers: [
        BlocProvider(
          create: (_) => VideoSearchBloc(
            videosRepository: videosRepository,
          ),
        ),
        BlocProvider(
          create: (_) => UserSearchBloc(profileRepository: profileRepository),
        ),
        BlocProvider(
          create: (_) => HashtagSearchBloc(
            hashtagRepository: hashtagRepository,
          ),
        ),
        BlocProvider(
          create: (_) => ListSearchBloc(
            curatedListRepository: curatedListRepository,
            peopleListsRepository: peopleListsRepository,
            peopleListSearchEnabled: peopleListSearchEnabled,
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
            controller: controller,
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

/// Wires the app bar and body to the page-owned [TextEditingController].
///
/// Keeping the controller above the repository-keyed BLoC scope preserves
/// typed input when policy or account changes replace the searches. Using
/// the live text rather than the route argument for the idle placeholder
/// correctly returns the view to the idle placeholder when the user clears
/// or shortens a prefilled query after landing on /search-results/:query.
class _SearchResultsBody extends StatelessWidget {
  const _SearchResultsBody({
    required this.controller,
    required this.requestFocusOnMount,
  });

  final TextEditingController controller;
  final bool requestFocusOnMount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchResultsAppBar(
          controller: controller,
          initialQuery: controller.text,
          requestFocusOnMount: requestFocusOnMount,
        ),
        Expanded(child: SearchResultsView(controller: controller)),
      ],
    );
  }
}
