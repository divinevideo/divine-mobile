// ABOUTME: A poll, quiz or slider sticker on the playing video, drawn over its
// ABOUTME: frames with the votes on it, taking the viewer's own vote.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/poll_sticker/poll_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/video_editor/social_sticker/poll_sticker_card.dart';
import 'package:poll_repository/poll_repository.dart' show PollKind;
import 'package:unified_logger/unified_logger.dart';

/// The poll, quiz or slider [region] on [video], as the frames show it until
/// [isActive], and from then on with the votes on it, taking the viewer's.
///
/// Only the active video reads its poll, so the videos the feed loads ahead
/// ask the relays for nothing. [onInteraction] is called when the viewer
/// starts to vote, so the feed does not move on under them.
class PollStickerOverlay extends StatelessWidget {
  const PollStickerOverlay({
    required this.region,
    required this.video,
    required this.data,
    required this.isActive,
    this.onInteraction,
    super.key,
  });

  final VideoStickerRegion region;
  final VideoEvent video;

  /// The sticker as the region publishes it.
  final SocialStickerData data;

  final bool isActive;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context) {
    if (!isActive) return IgnorePointer(child: PollStickerCopy(data: data));
    return _PollStickerScope(
      region: region,
      video: video,
      data: data,
      onInteraction: onInteraction,
    );
  }
}

/// Provides the cubit that reads the poll for the signed-in viewer, and tells
/// them what became of their vote.
class _PollStickerScope extends ConsumerWidget {
  const _PollStickerScope({
    required this.region,
    required this.video,
    required this.data,
    required this.onInteraction,
  });

  final VideoStickerRegion region;
  final VideoEvent video;
  final SocialStickerData data;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(pollRepositoryProvider);
    final preferences = ref.watch(sharedPreferencesProvider);
    final session = ref.watch(nostrSessionProvider);
    final viewer = session.pubkey;
    return BlocProvider(
      // Another account has its own vote to show, and a read made before the
      // relays were up found nothing.
      key: ValueKey((
        repository,
        region.target,
        viewer,
        session.isReadyForActiveClient,
      )),
      create: (_) {
        final cubit = PollStickerCubit(
          repository: repository,
          preferences: preferences,
          pollId: region.target,
          authorPubkey: video.pubkey,
          kind: switch (region.kind) {
            VideoStickerKind.quiz => PollKind.quiz,
            VideoStickerKind.slider => PollKind.slider,
            _ => PollKind.poll,
          },
          question: data.pollQuestion ?? '',
          answers: data.pollOptions,
          emoji: data.sliderEmoji,
        );
        runDetached(
          cubit.load(),
          'load the poll of a poll sticker',
          logName: 'PollStickerOverlay',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: BlocListener<PollStickerCubit, PollStickerState>(
        listenWhen: (previous, current) =>
            previous.voteStatus != current.voteStatus,
        listener: (context, state) {
          final l10n = context.l10n;
          final message = switch (state.voteStatus) {
            PollVoteStatus.failed => l10n.videoStickerPollVoteFailed,
            PollVoteStatus.sent when state.isFirstVote =>
              l10n.videoStickerPollVotesArePublic,
            _ => null,
          };
          if (state.voteStatus == PollVoteStatus.sent &&
              state.poll?.kind == PollKind.quiz) {
            announceDetached(
              context,
              state.ownAnswerIndex == state.rightAnswerIndex
                  ? l10n.videoStickerQuizRightAnswer
                  : l10n.videoStickerQuizWrongAnswer,
              description: 'announce how a quiz answer did',
              logName: 'PollStickerOverlay',
            );
          }
          if (message == null) return;
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(DivineSnackbarContainer.snackBar(message));
        },
        child: _PollStickerView(
          data: data,
          isAuthor: viewer != null && viewer == video.pubkey.toLowerCase(),
          isSignedIn: viewer != null,
          canVote: session.isReadyForActiveClient,
          onInteraction: onInteraction,
        ),
      ),
    );
  }
}

/// The sticker with the votes once there are any to show: the viewer's own
/// once they voted, or straight away for the creator, who does not vote.
class _PollStickerView extends StatefulWidget {
  const _PollStickerView({
    required this.data,
    required this.isAuthor,
    required this.isSignedIn,
    required this.canVote,
    required this.onInteraction,
  });

  final SocialStickerData data;
  final bool isAuthor;
  final bool isSignedIn;
  final bool canVote;
  final VoidCallback? onInteraction;

  @override
  State<_PollStickerView> createState() => _PollStickerViewState();
}

class _PollStickerViewState extends State<_PollStickerView> {
  /// Where the viewer is dragging a slider's emoji, while they drag it.
  double? _dragValue;

  /// Whether a vote can be cast now; tells the viewer why not when it
  /// cannot.
  bool _mayVote() {
    final l10n = context.l10n;
    final reason = !widget.isSignedIn
        ? l10n.videoStickerPollSignInToVote
        : !widget.canVote
        ? l10n.videoStickerPollNotReady
        : null;
    if (reason == null) return true;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(DivineSnackbarContainer.snackBar(reason));
    return false;
  }

  void _answer(PollStickerState state, int index) {
    final options = state.poll?.options;
    if (options == null || index >= options.length || !_mayVote()) return;
    widget.onInteraction?.call();
    _vote(options[index].id);
  }

  void _vote(String optionId) => runDetached(
    context.read<PollStickerCubit>().voted(optionId),
    'vote on a poll sticker',
    logName: 'PollStickerOverlay',
    category: LogCategory.ui,
  );

  void _slide(double value) {
    if (_dragValue == null) widget.onInteraction?.call();
    setState(() => _dragValue = value);
  }

  void _slideEnd(PollStickerState state, double value) {
    // The last move may not be drawn yet, so the card's value can lag it.
    final end = _dragValue ?? value;
    setState(() => _dragValue = null);
    final poll = state.poll;
    if (poll == null || !_mayVote()) return;
    widget.onInteraction?.call();
    _vote(poll.sliderOptionAt(end));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PollStickerCubit>().state;
    final ready = state.status == PollStickerStatus.ready;
    final hasVoted = state.results.hasVoted;
    final showsResults = ready && (hasVoted || widget.isAuthor);
    final isQuiz = state.poll?.kind == PollKind.quiz;
    final takesVotes = ready && !widget.isAuthor && !(isQuiz && hasVoted);
    final isSlider = widget.data.kind == SocialStickerKind.slider;
    final copy = PollStickerCopy(
      data: widget.data,
      results: showsResults
          ? PollStickerResults(
              shares: state.shares,
              ownAnswer: state.ownAnswerIndex,
              rightAnswer: state.rightAnswerIndex,
              average: state.sliderAverage,
            )
          : null,
      onAnswer: takesVotes && !isSlider
          ? (index) => _answer(state, index)
          : null,
      sliderValue: _dragValue ?? state.ownSliderValue ?? 0,
      onSlide: takesVotes && isSlider ? _slide : null,
      onSlideEnd: takesVotes && isSlider
          ? (value) => _slideEnd(state, value)
          : null,
    );
    if (!ready || !widget.isAuthor) return copy;
    // Under the card rather than in it, which keeps the size of the copy in
    // the frames.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        copy,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FractionalTranslation(
            translation: const Offset(0, 1.25),
            child: Center(child: _VoteCount(count: state.results.total)),
          ),
        ),
      ],
    );
  }
}

/// How many people voted, under the creator's own poll, quiz or slider.
class _VoteCount extends StatelessWidget {
  const _VoteCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: VineTheme.scrim56,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          context.l10n.videoStickerPollVoteCount(count),
          style: VineTheme.labelMediumFont(color: VineTheme.whiteText),
        ),
      ),
    );
  }
}
