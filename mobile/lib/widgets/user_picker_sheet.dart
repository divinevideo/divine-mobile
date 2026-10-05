// ABOUTME: Modal bottom sheet for searching and picking Nostr users
// ABOUTME: Supports filtering by mutual follows (fast local search)
// ABOUTME: or all users (network search) with mute-check validation

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/local_user_picker/local_user_picker_cubit.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/people_picker_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/user_identifier_line_resolver.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/private_key_search_warning.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_indicator_line.dart';
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
  bool showSelectedProfiles = false,
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
      showSelectedProfiles: showSelectedProfiles,
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
class UserPickerSheet extends ConsumerStatefulWidget {
  /// Creates a user picker bottom sheet.
  const UserPickerSheet({
    required this.filterMode,
    required this.title,
    this.scrollController,
    this.autoFocus = false,
    this.showSelectedProfiles = false,
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

  /// Keeps existing picks removable even when the mutual search does not offer them.
  final bool showSelectedProfiles;

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
  ConsumerState<UserPickerSheet> createState() => _UserPickerScopeState();
}

class _UserPickerScopeState extends ConsumerState<UserPickerSheet> {
  late final String? _owner;
  bool _retired = false;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(nostrSessionProvider).pubkey;
  }

  bool _owns(NostrSessionReadiness session) =>
      session.pubkey == _owner &&
      session.phase != NostrSessionPhase.tearingDown;

  bool get _canSelect =>
      mounted && !_retired && _owns(ref.read(nostrSessionProvider));

  @override
  Widget build(BuildContext context) {
    ref.listen(nostrSessionProvider, (_, next) {
      if (!_owns(next)) _retired = true;
    });
    if (!_owns(ref.watch(nostrSessionProvider))) _retired = true;
    if (_retired) return const SizedBox.shrink();
    final profileRepository = ref.watch(profileRepositoryProvider);
    final factory = ref.watch(
      userPickerCubitFactoryProvider(
        widget.filterMode == UserPickerFilterMode.mutualFollowsOnly,
      ),
    );
    return _UserPickerSheetView(
      configuration: widget,
      profileRepository: profileRepository,
      factory: factory,
      canSelect: () => _canSelect,
    );
  }
}

class _UserPickerSheetView extends ConsumerStatefulWidget {
  const _UserPickerSheetView({
    required this.configuration,
    required this.factory,
    required this.profileRepository,
    required this.canSelect,
  });

  final UserPickerSheet configuration;
  final UserPickerCubitFactory factory;
  final ProfileRepository? profileRepository;
  final bool Function() canSelect;

  @override
  ConsumerState<_UserPickerSheetView> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends ConsumerState<_UserPickerSheetView> {
  static const _searchInputBorderRadius = 20.0;

  UserSearchBloc? _searchBloc;
  final _searchController = TextEditingController();

  LocalUserPickerCubit? _localCubit;

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
    if (_useLocalSearch) _configureLocalCubit();
  }

  @override
  void didUpdateWidget(covariant _UserPickerSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.factory, widget.factory)) {
      return;
    }
    final searchBloc = _searchBloc;
    if (searchBloc != null) _closeSearchBloc(searchBloc);
    _configureSearchBloc(searchBloc?.state);
    if (_useLocalSearch) {
      final previous = _localCubit;
      _configureLocalCubit(previous?.state);
      if (previous != null) _closeLocalCubit(previous);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLocalIdentity(
      ref.read(vanishedProfilePubkeysProvider).value ?? const {},
    );
  }

  void _configureLocalCubit([LocalUserPickerState? initialState]) {
    final cubit = widget.factory.createLocal(
      excludedPubkey: widget.configuration.excludeViewerPubkey,
      initialState: initialState,
    );
    _localCubit = cubit;
    runDetached(
      cubit.started(),
      'load followed profiles',
      logName: 'UserPickerSheet',
      category: LogCategory.ui,
    );
  }

  void _closeLocalCubit(LocalUserPickerCubit cubit) => runDetached(
    cubit.close(),
    'close local user picker',
    logName: 'UserPickerSheet',
    category: LogCategory.ui,
  );

  void _updateLocalIdentity(Set<String> pubkeys) =>
      _localCubit?.identityChanged(
        vanishedPubkeys: pubkeys,
        deletedAccountLabel: context.l10n.profileDeletedAccountName,
      );

  void _configureSearchBloc([UserSearchState? snapshot]) {
    final profileRepo = widget.profileRepository;
    _profileRepoMissing = profileRepo == null;
    _searchBloc = widget.factory.createSearch(
      excludedPubkey: widget.configuration.excludeViewerPubkey,
      initialState: snapshot,
    );
    if (!_useLocalSearch &&
        !_profileRepoMissing &&
        _searchController.text.trim().isNotEmpty &&
        (snapshot == null ||
            snapshot.query != _searchController.text.trim() ||
            snapshot.status == UserSearchStatus.loading)) {
      _searchBloc?.add(UserSearchQueryChanged(_searchController.text));
    }
  }

  void _closeSearchBloc(UserSearchBloc bloc) => runDetached(
    bloc.close(),
    'close user search',
    logName: 'UserPickerSheet',
    category: LogCategory.ui,
  );

  @override
  void dispose() {
    final localCubit = _localCubit;
    if (localCubit != null) _closeLocalCubit(localCubit);
    _searchController.dispose();
    final searchBloc = _searchBloc;
    if (searchBloc != null) _closeSearchBloc(searchBloc);
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_useLocalSearch) {
      _localCubit?.queryChanged(query);
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

  void _onUserSelected(UserProfile profile) {
    if (!mounted || !widget.canSelect() || _isExcludedViewer(profile.pubkey)) {
      return;
    }

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
    if (!mounted || !widget.canSelect()) return;
    Navigator.of(context).pop(List.of(_selectedProfiles));
  }

  void _handleClear() {
    if (!mounted || !widget.canSelect()) return;
    Navigator.of(context).pop(<UserProfile>[]);
  }

  @override
  Widget build(BuildContext context) {
    // Keep identity current through profile unavailability: a replacement
    // Cubit inherits this snapshot when the same owner's profiles return.
    // One subscription for the whole sheet rather than one per row: the rows
    // are unbounded and every one of them asks the same question.
    // The sort and the filter need the whole set; each row watches its own
    // pubkey through profileVanishedProvider, which derives from this same
    // stream — the shape every inbox row already uses.
    ref.listen(vanishedProfilePubkeysProvider, (_, next) {
      _updateLocalIdentity(next.value ?? const {});
    });

    if (_profileRepoMissing) {
      return const _ProfileRepoUnavailable();
    }

    final hintText =
        widget.configuration.searchHint ??
        (_useLocalSearch
            ? context.l10n.userPickerFilterByNameHint
            : context.l10n.userPickerSearchByNameHint);
    final disabledPubkeys = widget.configuration.onUserToggled == null
        ? widget.configuration.excludePubkeys
        : const <String>{};
    // Capped picks move into the chips row and leave the candidate list.
    // Callback picks may also show removable chips, but keep their candidate
    // rows visible so the same user can still be toggled from either place
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

        if (widget.configuration.maxCount != null || widget.showSelectedProfiles)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: .topCenter,
            child: _selectedProfiles.isNotEmpty
                ? _SelectedChipsRow(
                    profiles: _selectedProfiles,
                    onRemove: (profile) {
                      setState(() {
                        _selectedProfiles.removeWhere(
                          (p) => p.pubkey == profile.pubkey,
                        );
                        _selectedPubkeys.remove(profile.pubkey);
                      });
                      widget.onUserToggled?.call(profile);
                    },
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
                ? BlocBuilder<LocalUserPickerCubit, LocalUserPickerState>(
                    bloc: _localCubit,
                    builder: (context, state) => _LocalResults(
                      scrollController: widget.configuration.scrollController,
                      followListLoaded: state.loaded,
                      rankingSignals: state.rankingSignals,
                      followProfiles: state.profiles,
                      filteredFollowProfiles: state.visibleProfiles,
                      onUserSelected: _onUserSelected,
                      excludePubkeys: disabledPubkeys,
                      selectedPubkeys: _selectedPubkeys,
                      hidePubkeys: hidePubkeys,
                    ),
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
    this.signals,
    this.isDisabled = false,
    this.isSelected = false,
    super.key,
  });

  final UserProfile profile;
  final UserRankingSignals? signals;
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

    final relationship = switch ((signals?.youFollow, signals?.followsYou)) {
      (true, true) => FollowRelationship.mutual,
      (true, _) => FollowRelationship.youFollow,
      (_, true) => FollowRelationship.followsYou,
      _ => FollowRelationship.none,
    };
    final identifier = isVanished
        ? null
        : resolveUserIdentifierLine(
            l10n: context.l10n,
            locale: Localizations.localeOf(context).toLanguageTag(),
            handle: nip05,
          );
    final indicators = UserIndicatorLine(
      identifier: identifier,
      relationship: isVanished ? FollowRelationship.none : relationship,
      videoCount: isVanished ? null : signals?.videoCount,
      lastPostedAt: isVanished ? null : signals?.lastPostedAt,
      now: clock.now(),
      style: VineTheme.bodyMediumFont(color: textColor),
    );

    return Semantics(
      button: true,
      // Preserve every visible account fact while suppressing duplicate
      // avatar/name announcements inside the row.
      label: indicators.hasContent
          ? '$action. ${indicators.labelFor(context)}'
          : action,
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
                      if (indicators.hasContent) indicators,
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
    this.rankingSignals = const {},
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
  final Map<String, UserRankingSignals> rankingSignals;
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
            signals: rankingSignals[profile.pubkey],
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
              rankingSignals: state.rankingSignals,
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
            rankingSignals: state.rankingSignals,
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
    this.rankingSignals = const {},
    this.excludePubkeys = const {},
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final ScrollController? scrollController;
  final bool followListLoaded;
  final List<UserProfile> followProfiles;
  final List<UserProfile> filteredFollowProfiles;
  final ValueChanged<UserProfile> onUserSelected;
  final Map<String, UserRankingSignals> rankingSignals;
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
          signals: rankingSignals[profile.pubkey],
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
