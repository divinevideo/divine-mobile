// ABOUTME: Preloads recommendations before arming one non-video Home feed page.
// ABOUTME: Reuses account-scoped discovery state and never inserts behind a viewer.
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/find_people_providers.dart';
import 'package:openvine/screens/feed/feed_people_interstitial_cubit.dart';
import 'package:openvine/screens/find_people/widgets/find_people_recommendations.dart';

/// The optional page and its visibility/index callbacks for the native feed.
class FeedPeopleSlot {
  const FeedPeopleSlot({
    this.builder,
    this.onVisibilityChanged,
    this.onVideoChanged,
  });

  final WidgetBuilder? builder;
  final ValueChanged<bool>? onVisibilityChanged;
  final ValueChanged<int>? onVideoChanged;
  int? get index =>
      builder == null ? null : FeedPeopleInterstitialCubit.insertBeforeIndex;
}

class FeedPeopleSuggestionsHost extends ConsumerWidget {
  const FeedPeopleSuggestionsHost({
    required this.builder,
    required this.sessionKey,
    required this.initialVideoIndex,
    required this.isFeedActive,
    required this.onContinue,
    super.key,
  });

  final Widget Function(BuildContext, FeedPeopleSlot) builder;
  final Object sessionKey;
  final int initialVideoIndex;
  final bool isFeedActive;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(isFeatureEnabledProvider(FeatureFlag.findPeople)) &&
        ref.watch(isFeatureEnabledProvider(FeatureFlag.feedPeopleSuggestions));
    if (!enabled) return builder(context, const FeedPeopleSlot());
    final repository = ref.watch(findPeopleRepositoryProvider);
    final follows = ref.watch(followRepositoryProvider);
    return _PeopleSession(
      key: ValueKey((repository, follows)),
      configuration: this,
      createCubit: () {
        final cubit = FindPeopleCubit(
          repository: repository,
          followRepository: follows,
        );
        unawaited(cubit.load(limit: 3));
        return cubit;
      },
    );
  }
}

class _PeopleSession extends StatefulWidget {
  const _PeopleSession({
    required this.configuration,
    required this.createCubit,
    super.key,
  });

  final FeedPeopleSuggestionsHost configuration;
  final FindPeopleCubit Function() createCubit;

  @override
  State<_PeopleSession> createState() => _PeopleSessionState();
}

class _PeopleSessionState extends State<_PeopleSession> {
  late final FindPeopleCubit _people;
  late final FeedPeopleInterstitialCubit _policy;
  final ValueNotifier<bool> _cardVisible = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _policy = FeedPeopleInterstitialCubit(
      initialVideoIndex: widget.configuration.initialVideoIndex,
    );
    _people = widget.createCubit();
  }

  @override
  void didUpdateWidget(_PeopleSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration.sessionKey != widget.configuration.sessionKey) {
      _policy.reset(initialVideoIndex: widget.configuration.initialVideoIndex);
      _policy.availabilityChanged(_people.state.suggestions.isNotEmpty);
      _cardVisible.value = false;
    }
  }

  @override
  void dispose() {
    unawaited(_people.close());
    unawaited(_policy.close());
    _cardVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FindPeopleCubit, FindPeopleState>(
      bloc: _people,
      listenWhen: (before, after) => before.suggestions != after.suggestions,
      listener: (_, state) =>
          _policy.availabilityChanged(state.suggestions.isNotEmpty),
      child:
          BlocSelector<
            FeedPeopleInterstitialCubit,
            FeedPeopleInterstitialState,
            bool
          >(
            bloc: _policy,
            selector: (state) => state.armed,
            builder: (context, armed) => widget.configuration.builder(
              context,
              FeedPeopleSlot(
                builder: armed
                    ? (context) => _FeedPeopleCard(
                        people: _people,
                        cardVisible: _cardVisible,
                        isFeedActive: widget.configuration.isFeedActive,
                        onContinue: widget.configuration.onContinue,
                      )
                    : null,
                onVisibilityChanged: (visible) => _cardVisible.value = visible,
                onVideoChanged: _policy.videoChanged,
              ),
            ),
          ),
    );
  }
}

class _FeedPeopleCard extends StatelessWidget {
  const _FeedPeopleCard({
    required this.people,
    required this.cardVisible,
    required this.isFeedActive,
    required this.onContinue,
  });

  final FindPeopleCubit people;
  final ValueNotifier<bool> cardVisible;
  final bool isFeedActive;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.vineColors.surface,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
        child: Column(
          children: [
            Text(
              context.l10n.findPeopleTitle,
              style: VineTheme.titleLargeFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: ValueListenableBuilder<bool>(
                  valueListenable: cardVisible,
                  builder: (context, visible, _) => FindPeopleRecommendations(
                    cubit: people,
                    isActive: visible && isFeedActive,
                  ),
                ),
              ),
            ),
            DivineButton(
              label: context.l10n.findPeopleContinueWatching,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    ),
  );
}
