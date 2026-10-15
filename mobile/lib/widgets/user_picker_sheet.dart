// ABOUTME: Modal bottom sheet for searching and picking Nostr users
// ABOUTME: Supports filtering by mutual follows (fast local search)
// ABOUTME: or all users (network search) with mute-check validation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/follow_list_ranking.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/private_key_search_warning.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vanished_account_identity.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

/// Filter mode for user search in [UserPickerSheet].
enum UserPickerFilterMode {
  /// Only users with mutual follow (for collaborators).
  mutualFollowsOnly,

  /// All users (for Inspired By).
  allUsers,
}

/// Shows a [UserPickerSheet] as a modal bottom sheet.
///
/// Returns the selected profiles (one entry for a single-select sheet, an
/// empty list when the selection was cleared) or null if dismissed.
Future<List<UserProfile>?> showUserPickerSheet(
  BuildContext context, {
  required UserPickerFilterMode filterMode,
  required String title,
  bool autoFocus = false,
  String? searchText,
  String? searchHint,
  ValueChanged<UserProfile>? onUserToggled,
  int? maxCount,
  Set<String> excludePubkeys = const {},
  String? excludeViewerPubkey,
  List<UserProfile> initialSelectedProfiles = const [],
}) {
  return VineBottomSheet.show<List<UserProfile>?>(
    context: context,
    initialChildSize: 1,
    maxChildSize: 1,
    minChildSize: VineTheme.bottomSheetDismissFloor,
    showDragHandle: false,
    showHeader: false,
    buildScrollBody: (scrollController) => UserPickerSheet(
      filterMode: filterMode,
      scrollController: scrollController,
      autoFocus: autoFocus,
      title: title,
      searchText: searchText,
      maxCount: maxCount,
      excludePubkeys: excludePubkeys,
      excludeViewerPubkey: excludeViewerPubkey,
      searchHint: searchHint,
      onUserToggled: onUserToggled,
      initialSelectedProfiles: initialSelectedProfiles,
    ),
  );
}

/// A bottom sheet widget for searching and selecting a user.
class UserPickerSheet extends ConsumerWidget {
  /// Creates a user picker bottom sheet.
  const UserPickerSheet({
    required this.filterMode,
    required this.title,
    this.scrollController,
    this.autoFocus = false,
    this.searchText,
    this.maxCount,
    this.excludePubkeys = const {},
    this.excludeViewerPubkey,
    this.searchHint,
    this.onUserToggled,
    this.initialSelectedProfiles = const [],
    super.key,
  });

  /// How to filter search results.
  final UserPickerFilterMode filterMode;

  /// Title shown in the header.
  final String title;

  /// Optional helper text shown below the title in the header.
  final String? searchText;

  /// Optional maximum selectable count shown in the header as
  /// "selected/max title".
  final int? maxCount;

  /// Scroll controller for the draggable sheet.
  final ScrollController? scrollController;

  final bool autoFocus;

  /// Pubkeys the caller already tracks as selected. Their rows render in
  /// the checked state rather than being hidden.
  final Set<String> excludePubkeys;

  /// Hex pubkey of the signed-in viewer, compared case-insensitively.
  ///
  /// A matching row is hidden, a tap on one is ignored, and a matching entry
  /// in [initialSelectedProfiles] is dropped before it can occupy a slot. A
  /// contact list written by another client can follow itself, which would
  /// otherwise make the viewer their own mutual.
  final String? excludeViewerPubkey;

  /// Optional override for the search field hint text.
  final String? searchHint;

  /// When provided, tapping a user calls this callback instead of popping
  /// the sheet. Use this for multi-select flows where the sheet should stay
  /// open. Selected users should be tracked by the caller and reflected via
  /// [excludePubkeys] (they will appear in the checked state).
  final ValueChanged<UserProfile>? onUserToggled;

  /// Profiles pre-selected when the sheet opens.
  final List<UserProfile> initialSelectedProfiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final rankingSignalsLoader = profileRepository == null
        ? null
        : ref.watch(userRankingSignalsLoaderProvider);
    final ownerPubkey = ref.watch(
      nostrSessionProvider.select((session) => session.pubkey),
    );
    return _UserPickerSheetView(
      // A profile repository becoming ready does not start a new selection flow.
      // An owner or follow-source change must discard all captured local rows.
      key: ValueKey((ownerPubkey, followRepository)),
      configuration: this,
      profileRepository: profileRepository,
      rankingSignalsLoader: rankingSignalsLoader,
    );
  }
}

class _UserPickerSheetView extends ConsumerStatefulWidget {
  const _UserPickerSheetView({
    required this.configuration,
    required this.rankingSignalsLoader,
    required this.profileRepository,
    super.key,
  });

  final UserPickerSheet configuration;
  final UserRankingSignalsLoader? rankingSignalsLoader;
  final ProfileRepository? profileRepository;

  @override
  ConsumerState<_UserPickerSheetView> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends ConsumerState<_UserPickerSheetView> {
  static const _searchInputBorderRadius = 20.0;

  UserSearchBloc? _searchBloc;
  final _searchController = TextEditingController();

  // For mutualFollowsOnly: local follow list search
  List<UserProfile> _followProfiles = [];
  List<UserProfile> _filteredFollowProfiles = [];
  Map<String, UserRankingSignals> _rankingSignals = const {};
  List<String> _followOrder = const [];
  bool _followOrderReady = false;
  int _followLoadRevision = 0;

  /// Pubkeys carrying a NIP-62 vanish tombstone, mirrored from
  /// [vanishedProfilePubkeysProvider].
  ///
  /// One subscription keeps rendered identity and search matching consistent.
  /// Later tombstones update identity in place without changing row positions.
  Set<String> _vanishedPubkeys = const {};
  bool _followListLoaded = false;
  StreamSubscription<List<String>>? _followersSubscription;
  final _selectedProfiles = <UserProfile>[];

  /// Whether profile operations are currently unavailable.
  bool _profileRepoMissing = false;

  /// [widget.configuration.initialSelectedProfiles] without the excluded viewer.
  ///
  /// Both the initial selection and the header's clear affordance read this
  /// list, so a sheet whose only initial selection was the viewer has nothing
  /// selected and nothing to clear.
  late final List<UserProfile> _initialSelectedProfiles;

  /// Tracks selected pubkeys locally so toggling is reflected immediately.
  /// Initialised from [widget.configuration.excludePubkeys] and the viewer-filtered
  /// [widget.configuration.initialSelectedProfiles] so pre-selected users show as checked
  /// from the start.
  late Set<String> _selectedPubkeys;

  bool get _useLocalSearch =>
      widget.configuration.filterMode == UserPickerFilterMode.mutualFollowsOnly;

  /// Whether the sheet stays open while the user picks more than one person.
  ///
  /// True for both multi-select shapes: a capped selection the sheet owns
  /// ([UserPickerSheet.maxCount]) and an uncapped one the caller tracks
  /// through [UserPickerSheet.onUserToggled]. Both need a way to say "done" —
  /// without one the only way out is the close button, which reads as
  /// discarding the picks.
  bool get _isMultiSelect =>
      widget.configuration.maxCount != null ||
      widget.configuration.onUserToggled != null;

  @override
  void initState() {
    super.initState();
    _initialSelectedProfiles = widget.configuration.initialSelectedProfiles
        .where((profile) => !_isExcludedViewer(profile.pubkey))
        .toList();
    _selectedPubkeys = {
      ...widget.configuration.excludePubkeys,
      for (final profile in _initialSelectedProfiles) profile.pubkey,
    };
    if (_initialSelectedProfiles.isNotEmpty) {
      _selectedProfiles.addAll(_initialSelectedProfiles);
    }
    _configureSearchBloc();
    if (_useLocalSearch && !_profileRepoMissing) _reloadFollowProfiles();
  }

  @override
  void didUpdateWidget(covariant _UserPickerSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.profileRepository, widget.profileRepository) &&
        identical(
          oldWidget.rankingSignalsLoader,
          widget.rankingSignalsLoader,
        )) {
      return;
    }
    final searchBloc = _searchBloc;
    if (searchBloc != null) _closeSearchBloc(searchBloc);
    // Keep the search-only reset contract when the account-scoped loader changes.
    // Profile availability changes retain this same owner's query and selection.
    if (!_useLocalSearch &&
        identical(oldWidget.profileRepository, widget.profileRepository)) {
      _searchController.clear();
    }
    _configureSearchBloc();
    if (_useLocalSearch) {
      // Invalidate old preload/profile work before a new dependency can publish.
      _followLoadRevision++;
      if (!_profileRepoMissing) _reloadFollowProfiles();
    }
  }

  void _configureSearchBloc() {
    final profileRepo = widget.profileRepository;
    _profileRepoMissing = profileRepo == null;
    _searchBloc = profileRepo == null
        ? null
        : UserSearchBloc(
            profileRepository: profileRepo,
            rankingSignalsLoader: widget.rankingSignalsLoader,
            followRepository: ref.read(followRepositoryProvider),
            excludedPubkey: widget.configuration.excludeViewerPubkey,
          );
    if (!_useLocalSearch && _searchController.text.trim().isNotEmpty) {
      _searchBloc?.add(UserSearchQueryChanged(_searchController.text));
    }
  }

  void _reloadFollowProfiles() => runDetached(
    _loadFollowProfiles(),
    'load followed profiles',
    logName: 'UserPickerSheet',
    category: LogCategory.ui,
  );

  void _closeSearchBloc(UserSearchBloc bloc) => runDetached(
    bloc.close(),
    'close user search',
    logName: 'UserPickerSheet',
    category: LogCategory.ui,
  );

  void _reportRankingError(Object error, StackTrace stackTrace) => runDetached(
    Future<void>.error(error, stackTrace),
    'load user picker ranking',
    logName: 'UserPickerSheet',
    category: LogCategory.ui,
  );

  /// Loads followed profiles, then narrows them to mutuals as each follower
  /// source answers.
  ///
  /// The follower sources differ by an order of magnitude in latency (REST
  /// ~150ms, indexer relays up to ~2s) while the slow ones rarely add anyone.
  /// Rendering each emission as it arrives shows the bulk of the list roughly
  /// ten times sooner. Emissions only ever grow
  /// ([FollowRepository.streamMyFollowers]), so everyone on screen is a
  /// mutual confirmed by a live source — a late source can add rows, never
  /// invalidate one already shown.
  Future<void> _loadFollowProfiles() async {
    final revision = ++_followLoadRevision;
    bool isCurrent() => mounted && revision == _followLoadRevision;
    final followRepo = ref.read(followRepositoryProvider);
    final profileRepo = widget.profileRepository;
    final loader = widget.rankingSignalsLoader;
    if (profileRepo == null || loader == null) return;
    await _followersSubscription?.cancel();
    if (!isCurrent()) return;
    final followingPubkeys = followRepo.followingPubkeys;
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);

    final List<UserProfile> candidates;
    try {
      final cached = await profileRepo.getCachedProfiles(
        pubkeys: followingPubkeys,
      );
      if (!isCurrent()) return;
      _vanishedPubkeys =
          ref.read(vanishedProfilePubkeysProvider).value ?? const {};
      final signals = await loadFollowListRankingSignals(
        pubkeys: followingPubkeys,
        loader: loader,
        logName: 'UserPickerSheet',
        onError: (error, stackTrace) {
          if (isCurrent()) _reportRankingError(error, stackTrace);
        },
      );
      if (!isCurrent()) return;
      _rankingSignals = signals;
      final followingSet = followingPubkeys.toSet();
      // A newly ready cache may not have hydrated every visible profile yet.
      // Retain metadata only inside this owner's still-followed candidate set;
      // vanished identity is still substituted by the existing row/filter path.
      final profilesByPubkey = {
        for (final profile in _followProfiles)
          if (followingSet.contains(profile.pubkey)) profile.pubkey: profile,
        for (final profile in cached) profile.pubkey: profile,
      };
      candidates = profilesByPubkey.values
          .where(
            (profile) =>
                followingSet.contains(profile.pubkey) &&
                signals.containsKey(profile.pubkey) &&
                loader.isEligible(profile.pubkey) &&
                !blocklistRepository.shouldFilterFromFeeds(profile.pubkey) &&
                !_isExcludedViewer(profile.pubkey),
          )
          .toList();
    } catch (error, stackTrace) {
      if (!isCurrent()) return;
      _reportRankingError(error, stackTrace);
      setState(() => _followListLoaded = true);
      return;
    }
    if (!isCurrent()) return;
    if (candidates.isEmpty) {
      setState(() {
        _followProfiles = const [];
        _filteredFollowProfiles = const [];
        _followListLoaded = true;
      });
      return;
    }

    void showProfiles(List<UserProfile> profiles) {
      if (!isCurrent()) return;
      final ranked = rankFollowListSnapshot(
        pubkeys: profiles.map((profile) => profile.pubkey).toList(),
        signals: _rankingSignals,
        names: {
          for (final profile in profiles)
            profile.pubkey: _renderedName(profile),
        },
        isEligible: (key) =>
            loader.isEligible(key) &&
            !blocklistRepository.shouldFilterFromFeeds(key) &&
            !_isExcludedViewer(key),
        isSmartOrderReady: _followOrderReady,
        previousSmartOrder: _followOrder,
        now: DateTime.now(),
      );
      final byKey = {for (final profile in profiles) profile.pubkey: profile};
      final ordered = [for (final key in ranked.smartOrder) byKey[key]!];
      setState(() {
        // Keep first-visible positions even if a refresh temporarily omits a row.
        _followOrder = [
          ..._followOrder,
          ...ranked.smartOrder.where((key) => !_followOrder.contains(key)),
        ];
        _followOrderReady = true;
        _followProfiles = ordered;
        _filteredFollowProfiles = _matchingFollowProfiles(
          _searchController.text,
          ordered,
        );
        _followListLoaded = true;
      });
    }

    _followersSubscription = followRepo.streamMyFollowers().listen(
      (followers) {
        if (!isCurrent()) return;
        final followerSet = followers.toSet();
        final mutuals = candidates
            .where((profile) => followerSet.contains(profile.pubkey))
            .toList();
        if (mutuals.isEmpty && !_followListLoaded) return;
        showProfiles(mutuals);
      },
      // Preserve the existing all-sources-failed fallback, with eligibility intact.
      onError: (Object error, StackTrace stackTrace) {
        if (!isCurrent()) return;
        _reportRankingError(error, stackTrace);
        showProfiles(candidates);
      },
      onDone: () {
        if (!isCurrent() || _followListLoaded) return;
        setState(() => _followListLoaded = true);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_followersSubscription?.cancel());
    _searchController.dispose();
    final searchBloc = _searchBloc;
    if (searchBloc != null) _closeSearchBloc(searchBloc);
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_useLocalSearch) {
      _filterFollowProfiles(query);
    } else {
      if (query.trim().isEmpty) {
        _searchBloc?.add(const UserSearchCleared());
      } else {
        _searchBloc?.add(UserSearchQueryChanged(query));
      }
    }
  }

  /// Empties the search field and re-runs the search for the now-empty query.
  ///
  /// [TextEditingController.clear] does not fire [TextField.onChanged] — that
  /// only runs for platform input — so the reset has to be dispatched by hand
  /// or the results stay filtered under an empty field.
  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _filterFollowProfiles(String query) {
    setState(() {
      _filteredFollowProfiles = _matchingFollowProfiles(query, _followProfiles);
    });
  }

  /// The subset of [profiles] matching [query] by display name or NIP-05.
  ///
  /// Kept separate from [_filterFollowProfiles] because the follower stream
  /// re-applies the active query every time it adds rows.
  List<UserProfile> _matchingFollowProfiles(
    String query,
    List<UserProfile> profiles,
  ) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return profiles;

    return profiles.where((profile) {
      final isVanished = _vanishedPubkeys.contains(profile.pubkey);
      final name = _renderedName(profile).toLowerCase();
      // A vanished account's NIP-05 identifies it as surely as its name, so it
      // is neither rendered nor matchable — otherwise the row stays findable by
      // a string it no longer shows.
      final nip05 = isVanished ? '' : (profile.nip05 ?? '').toLowerCase();
      return name.contains(trimmed) || nip05.contains(trimmed);
    }).toList();
  }

  /// The substitute a vanished row shows in place of its name.
  ///
  /// An inherited-widget read, so it is unavailable until `initState` has
  /// returned — every caller below runs after that point.
  String get _deletedAccountLabel => context.l10n.profileDeletedAccountName;

  /// The name the row for [profile] renders.
  String _renderedName(UserProfile profile) => vanishedAccountNameFrom(
    isVanished: _vanishedPubkeys.contains(profile.pubkey),
    deletedAccountLabel: _deletedAccountLabel,
    fallbackName: profile.bestDisplayName,
  );

  /// Refreshes rendered identity and search matching without moving visible rows.
  void _onVanishedPubkeysChanged(Set<String> pubkeys) {
    if (!mounted) return;
    if (pubkeys.length == _vanishedPubkeys.length &&
        pubkeys.containsAll(_vanishedPubkeys)) {
      return;
    }
    setState(() {
      _vanishedPubkeys = pubkeys;
      _filteredFollowProfiles = _matchingFollowProfiles(
        _searchController.text,
        _followProfiles,
      );
    });
  }

  void _onUserSelected(UserProfile profile) {
    if (_isExcludedViewer(profile.pubkey)) return;

    if (widget.configuration.onUserToggled != null) {
      setState(() {
        if (_selectedPubkeys.remove(profile.pubkey)) {
          _selectedProfiles.removeWhere((p) => p.pubkey == profile.pubkey);
        } else {
          _selectedPubkeys.add(profile.pubkey);
          _selectedProfiles.add(profile);
        }
      });
      widget.configuration.onUserToggled!(profile);
    } else if (widget.configuration.maxCount != null) {
      setState(() {
        if (_selectedProfiles.any((p) => p.pubkey == profile.pubkey)) {
          _selectedProfiles.removeWhere((p) => p.pubkey == profile.pubkey);
          _selectedPubkeys.remove(profile.pubkey);
        } else if (_selectedProfiles.length < widget.configuration.maxCount!) {
          _selectedProfiles.add(profile);
          _selectedPubkeys.add(profile.pubkey);
        }
      });
    } else {
      Navigator.of(context).pop([profile]);
    }
  }

  bool _isExcludedViewer(String pubkey) {
    final viewerPubkey = widget.configuration.excludeViewerPubkey;
    return viewerPubkey != null && pubkeysEqual(pubkey, viewerPubkey);
  }

  void _handleDone() {
    Navigator.of(context).pop(List.of(_selectedProfiles));
  }

  void _handleClear() {
    Navigator.of(context).pop(<UserProfile>[]);
  }

  @override
  Widget build(BuildContext context) {
    if (_profileRepoMissing) {
      return const _ProfileRepoUnavailable();
    }

    // One subscription for the whole sheet rather than one per row: the rows
    // are unbounded and every one of them asks the same question.
    // The sort and the filter need the whole set; each row watches its own
    // pubkey through profileVanishedProvider, which derives from this same
    // stream — the shape every inbox row already uses.
    ref.listen(vanishedProfilePubkeysProvider, (_, next) {
      _onVanishedPubkeysChanged(next.value ?? const {});
    });

    final hintText =
        widget.configuration.searchHint ??
        (_useLocalSearch
            ? context.l10n.userPickerFilterByNameHint
            : context.l10n.userPickerSearchByNameHint);
    final disabledPubkeys = widget.configuration.onUserToggled == null
        ? widget.configuration.excludePubkeys
        : const <String>{};
    // Only the capped mode moves a pick out of the list and into the chips
    // row; the callback mode has no chips, so a picked row has to stay put
    // and just render as checked.
    final hidePubkeys = widget.configuration.maxCount == null
        ? const <String>{}
        : {for (final profile in _selectedProfiles) profile.pubkey};

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        VineBottomSheetHeader(
          showDivider: false,
          leadingAction: DivineIconButton(
            icon: .x,
            type: .secondary,
            size: .small,
            semanticLabel: context.l10n.userPickerCancelSemanticLabel,
            onPressed: context.pop,
          ),
          title: _UserPickerTitle(
            title: widget.configuration.title,
            subtitle: widget.configuration.searchText,
            selectedCount: _selectedProfiles.length,
            maxCount: widget.configuration.maxCount,
          ),
          trailingAction: _isMultiSelect
              ? DivineIconButton(
                  icon: .check,
                  size: .small,
                  semanticLabel: context.l10n.userPickerConfirmSemanticLabel,
                  onPressed: _handleDone,
                )
              : _initialSelectedProfiles.isNotEmpty
              ? DivineIconButton(
                  icon: .trash,
                  size: .small,
                  type: .error,
                  semanticLabel:
                      context.l10n.userPickerClearSelectionSemanticLabel,
                  onPressed: _handleClear,
                )
              : null,
        ),

        // Search field
        Semantics(
          textField: true,
          label: hintText,
          child: Container(
            margin: const .fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(_searchInputBorderRadius),
            ),
            child: TextField(
              autofocus: widget.configuration.autoFocus,
              controller: _searchController,
              textInputAction: .search,
              // iOS predictive text and autocorrect silently rewrite the
              // query (e.g. "liz" → "Liz"), which re-fires `onChanged` and
              // blanks the results. Search fields should always opt out.
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              cursorColor: context.vineColors.accentPositive,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
                prefixIcon: Padding(
                  padding: const .only(left: 16, right: 8),
                  child: DivineIcon(
                    icon: DivineIconName.search,
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _searchController,
                  builder: (context, value, child) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: value.text.isEmpty
                        ? const SizedBox.shrink()
                        : DivineIconButton(
                            onPressed: _clearSearch,
                            icon: .x,
                            semanticLabel:
                                context.l10n.userPickerClearSearchSemantics,
                            backgroundColor: VineTheme.transparent,
                            foregroundColor: context.vineColors.onSurfaceMuted,
                          ),
                  ),
                ),
                border: .none,
                enabledBorder: .none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: .circular(_searchInputBorderRadius),
                  borderSide: BorderSide(
                    color: context.vineColors.accentPositive,
                    width: 2,
                  ),
                ),
                disabledBorder: .none,
                filled: false,
                contentPadding: const .symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        ValueListenableBuilder(
          valueListenable: _searchController,
          builder: (context, value, _) => PrivateKeySearchWarning(
            query: value.text,
            padding: const .fromLTRB(16, 8, 16, 4),
          ),
        ),

        if (widget.configuration.maxCount != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: .topCenter,
            child: _selectedProfiles.isNotEmpty
                ? _SelectedChipsRow(
                    profiles: _selectedProfiles,
                    onRemove: (profile) => setState(() {
                      _selectedProfiles.removeWhere(
                        (p) => p.pubkey == profile.pubkey,
                      );
                      _selectedPubkeys.remove(profile.pubkey);
                    }),
                  )
                : const SizedBox.shrink(),
          ),

        // Results list
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            opacity:
                widget.configuration.maxCount != null &&
                    _selectedProfiles.length >= widget.configuration.maxCount!
                ? 0.5
                : 1.0,
            child: _useLocalSearch
                ? _LocalResults(
                    scrollController: widget.configuration.scrollController,
                    followListLoaded: _followListLoaded,
                    followProfiles: _followProfiles,
                    filteredFollowProfiles: _filteredFollowProfiles,
                    onUserSelected: _onUserSelected,
                    excludePubkeys: disabledPubkeys,
                    selectedPubkeys: _selectedPubkeys,
                    hidePubkeys: hidePubkeys,
                  )
                : _NetworkResults(
                    searchBloc: _searchBloc!,
                    scrollController: widget.configuration.scrollController,
                    onUserSelected: _onUserSelected,
                    excludePubkeys: disabledPubkeys,
                    selectedPubkeys: _selectedPubkeys,
                    hidePubkeys: hidePubkeys,
                  ),
          ),
        ),

        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}

/// A tile displaying a user profile in the search results.
/// One candidate row.
///
/// A NIP-62 vanished account must not be named or pictured here: this picker
/// feeds badge awards (kind 8, which NIP-58 calls "immutable and
/// non-transferable"), people lists (kind 30000) and video `p` tags (kind
/// 34236), so a wrong identity is published permanently and in public. The
/// `allUsers` mode reaches third-party NIP-50 relays that a vanish addressed
/// elsewhere never obliged to forget, so the pre-vanish kind 0 does come back.
class _UserSearchTile extends ConsumerWidget {
  const _UserSearchTile({
    required this.profile,
    required this.onTap,
    this.isDisabled = false,
    this.isSelected = false,
    super.key,
  });

  final UserProfile profile;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = context.vineColors.onSurface;
    final isVanished = ref.watch(profileVanishedProvider(profile.pubkey));
    final displayName = vanishedAccountName(
      context,
      isVanished: isVanished,
      fallbackName: profile.bestDisplayName,
    );
    final action = isDisabled
        ? context.l10n.userPickerAlreadyAddedSemantics(displayName)
        : context.l10n.userPickerSelectSemantics(displayName);
    // `shortDisplayNip05`, not the raw field: every other identity string here
    // is sanitized, and this one arrives from relay search results. An unpaired
    // UTF-16 surrogate in a kind 0 crashes the paragraph builder, which is what
    // `text_sanitizer` exists to prevent. It also renders `@rabble` rather than
    // the `_@rabble.divine.video` long form every other row avoids.
    final nip05 = isVanished ? null : profile.shortDisplayNip05;

    return Semantics(
      button: true,
      // The rendered nip05 is what tells two same-named users apart, so it
      // rides along with the action instead of being dropped by the
      // ExcludeSemantics below.
      label: nip05 != null && nip05.isNotEmpty ? '$action. $nip05' : action,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isDisabled ? null : onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 16,
              children: [
                Opacity(
                  opacity: isDisabled ? 0.5 : 1.0,
                  child: UserAvatar(
                    imageUrl: vanishedAccountPictureUrl(
                      isVanished: isVanished,
                      pictureUrl: profile.picture,
                    ),
                    name: displayName,
                    placeholderSeed: profile.pubkey,
                    size: 40,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: VineTheme.titleMediumFont(color: textColor),
                      ),
                      if (nip05 != null && nip05.isNotEmpty)
                        Text(
                          nip05,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: VineTheme.bodyMediumFont(color: textColor),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const .all(8),
                  decoration: ShapeDecoration(
                    color: isDisabled
                        ? context.vineColors.surfaceContainer
                        : isSelected
                        ? context.vineColors.surfaceContainer
                        : VineTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                  ),
                  child: DivineIcon(
                    icon: (isDisabled || isSelected) ? .check : .plus,
                    color: (isDisabled || isSelected)
                        ? context.vineColors.onSurfaceMuted
                        : VineTheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFollowList extends StatelessWidget {
  const _EmptyFollowList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Text(
            context.l10n.userPickerEmptyFollowListTitle,
            style: VineTheme.headlineSmallFont(
              color: context.vineColors.onSurface,
            ),
            textAlign: .center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.userPickerEmptyFollowListBody,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
            textAlign: .center,
          ),
          const SizedBox(height: 32),
          Semantics(
            button: true,
            label: context.l10n.userPickerGoBack,
            child: InkWell(
              onTap: context.pop,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const .symmetric(horizontal: 24, vertical: 12),
                decoration: ShapeDecoration(
                  color: context.vineColors.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 2,
                      color: context.vineColors.outlineMuted,
                    ),
                    borderRadius: .circular(20),
                  ),
                ),
                child: Text(
                  context.l10n.userPickerGoBack,
                  textAlign: TextAlign.center,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.userPickerTypeNameToSearch,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _ProfileRepoUnavailable extends StatelessWidget {
  const _ProfileRepoUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.userPickerUnavailable,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.userPickerSearchFailedTryAgain,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({this.onShowMore, this.isLoadingMore = false});

  final VoidCallback? onShowMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: onShowMore == null
            ? Text(
                context.l10n.userSearchNoResults,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              )
            : _ShowMoreButton(onPressed: onShowMore, isLoading: isLoadingMore),
      ),
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({required this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.profileShowMore,
      type: DivineButtonType.secondary,
      onPressed: isLoading ? null : onPressed,
      isLoading: isLoading,
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.scrollController,
    required this.results,
    required this.onUserSelected,
    this.onNearEnd,
    this.onShowMore,
    this.isLoadingMore = false,
    this.excludePubkeys = const {},
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final ScrollController? scrollController;
  final List<UserProfile> results;
  final ValueChanged<UserProfile> onUserSelected;
  final VoidCallback? onNearEnd;
  final VoidCallback? onShowMore;
  final bool isLoadingMore;
  final Set<String> excludePubkeys;
  final Set<String> selectedPubkeys;
  final Set<String> hidePubkeys;

  /// Remaining scroll extent below which a settled scroll asks for more.
  static const _loadMoreExtent = 400.0;

  @override
  Widget build(BuildContext context) {
    final visible = hidePubkeys.isEmpty
        ? results
        : results.where((p) => !hidePubkeys.contains(p.pubkey)).toList();
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical &&
            notification.metrics.extentAfter < _loadMoreExtent) {
          onNearEnd?.call();
        }
        return false;
      },
      child: ListView.separated(
        controller: scrollController,
        itemCount: visible.length + (onShowMore == null ? 0 : 1),
        padding: EdgeInsets.fromLTRB(
          0,
          32,
          0,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        separatorBuilder: (context, index) => Divider(
          height: 40,
          thickness: 1,
          color: context.vineColors.outlineDisabled,
        ),
        itemBuilder: (context, index) {
          if (index == visible.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _ShowMoreButton(
                onPressed: onShowMore,
                isLoading: isLoadingMore,
              ),
            );
          }
          final profile = visible[index];
          final isDisabled = excludePubkeys.contains(profile.pubkey);
          return _UserSearchTile(
            key: ValueKey('${profile.pubkey}_$isDisabled'),
            profile: profile,
            isDisabled: isDisabled,
            isSelected: selectedPubkeys.contains(profile.pubkey),
            onTap: () => onUserSelected(profile),
          );
        },
      ),
    );
  }
}

class _NetworkResults extends StatelessWidget {
  const _NetworkResults({
    required this.searchBloc,
    required this.scrollController,
    required this.onUserSelected,
    this.excludePubkeys = const {},
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final UserSearchBloc searchBloc;
  final ScrollController? scrollController;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;
  final Set<String> selectedPubkeys;
  final Set<String> hidePubkeys;

  @override
  Widget build(BuildContext context) {
    void loadMore() => searchBloc.add(const UserSearchLoadMore());

    return BlocBuilder<UserSearchBloc, UserSearchState>(
      bloc: searchBloc,
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.initial => const _EmptyHint(),
          // Render cached/stale results while a new query loads — prevents
          // the full-screen spinner flash (e.g. when iOS autocorrect silently
          // replaces the query and re-triggers the search).
          UserSearchStatus.loading when state.results.isNotEmpty =>
            _ResultsList(
              scrollController: scrollController,
              results: state.results,
              onUserSelected: onUserSelected,
              excludePubkeys: excludePubkeys,
              selectedPubkeys: selectedPubkeys,
              hidePubkeys: hidePubkeys,
            ),
          UserSearchStatus.loading => const Center(
            child: BrandedLoadingIndicator(),
          ),
          UserSearchStatus.failure => const _ErrorState(),
          UserSearchStatus.success when state.results.isEmpty => _NoResults(
            onShowMore: state.hasMore ? loadMore : null,
            isLoadingMore: state.isLoadingMore,
          ),
          UserSearchStatus.success => _ResultsList(
            scrollController: scrollController,
            results: state.results,
            onUserSelected: onUserSelected,
            onNearEnd: state.hasMore && !state.isLoadingMore ? loadMore : null,
            onShowMore: state.hasMore ? loadMore : null,
            isLoadingMore: state.isLoadingMore,
            excludePubkeys: excludePubkeys,
            selectedPubkeys: selectedPubkeys,
            hidePubkeys: hidePubkeys,
          ),
        };
      },
    );
  }
}

class _LocalResults extends StatelessWidget {
  const _LocalResults({
    required this.scrollController,
    required this.followListLoaded,
    required this.followProfiles,
    required this.filteredFollowProfiles,
    required this.onUserSelected,
    this.excludePubkeys = const {},
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final ScrollController? scrollController;
  final bool followListLoaded;
  final List<UserProfile> followProfiles;
  final List<UserProfile> filteredFollowProfiles;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;
  final Set<String> selectedPubkeys;
  final Set<String> hidePubkeys;

  @override
  Widget build(BuildContext context) {
    if (!followListLoaded) {
      return const Center(child: BrandedLoadingIndicator());
    }

    if (followProfiles.isEmpty) {
      return const _EmptyFollowList();
    }

    if (filteredFollowProfiles.isEmpty) {
      return const _NoResults();
    }

    final visible = filteredFollowProfiles
        .where((p) => !hidePubkeys.contains(p.pubkey))
        .toList(growable: false);

    return ListView.separated(
      controller: scrollController,
      itemCount: visible.length,
      padding: .fromLTRB(
        0,
        32,
        0,
        32 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      separatorBuilder: (context, index) => Divider(
        height: 40,
        thickness: 1,
        color: context.vineColors.outlineDisabled,
      ),
      itemBuilder: (context, index) {
        final profile = visible[index];
        final isDisabled = excludePubkeys.contains(profile.pubkey);
        return _UserSearchTile(
          key: ValueKey('${profile.pubkey}_$isDisabled'),
          profile: profile,
          isDisabled: isDisabled,
          isSelected: selectedPubkeys.contains(profile.pubkey),
          onTap: () => onUserSelected(profile),
        );
      },
    );
  }
}

class _UserPickerTitle extends StatelessWidget {
  const _UserPickerTitle({
    required this.title,
    required this.selectedCount,
    this.subtitle,
    this.maxCount,
  });

  final String title;
  final int selectedCount;
  final String? subtitle;
  final int? maxCount;

  @override
  Widget build(BuildContext context) {
    final displayTitle = maxCount != null
        ? '$selectedCount/$maxCount $title'
        : title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(
          displayTitle,
          style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SelectedChipsRow extends ConsumerWidget {
  const _SelectedChipsRow({required this.profiles, required this.onRemove});

  final List<UserProfile> profiles;
  final ValueChanged<UserProfile> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final profile in profiles)
            _SelectionChip(
              key: ValueKey(profile.pubkey),
              label: vanishedAccountName(
                context,
                isVanished: ref.watch(profileVanishedProvider(profile.pubkey)),
                fallbackName: profile.bestDisplayName,
              ),
              onRemove: () => onRemove(profile),
            ),
        ],
      ),
    );
  }
}

class _SelectionChip extends StatefulWidget {
  const _SelectionChip({
    required this.label,
    required this.onRemove,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  State<_SelectionChip> createState() => _SelectionChipState();
}

class _SelectionChipState extends State<_SelectionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = curved;
    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRemove() async {
    if (_isRemoving) return;
    _isRemoving = true;
    await _controller.reverse();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  widget.label,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.userPickerRemoveSelectionSemantics(
                  widget.label,
                ),
                child: GestureDetector(
                  onTap: _handleRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: DivineIcon(
                      icon: .x,
                      size: 16,
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
