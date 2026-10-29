import 'dart:async';
import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart' hide ChallengeView;
import 'package:challenges_repository/challenges_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_deadline.dart';
import 'package:openvine/features/challenges/challenge_detail_view.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_playback.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/list_owner_action_tile.dart';

class ChallengeView extends StatefulWidget {
  const ChallengeView({
    required this.onRecord,
    this.ownerName,
    this.organizerName,
    this.onOrganizerTap,
    super.key,
  });
  final String? organizerName;
  final VoidCallback? onOrganizerTap;
  final String? ownerName;
  final Future<void> Function(BuildContext, String) onRecord;
  @override
  State<ChallengeView> createState() => _ChallengeViewState();
}

class _ChallengeViewState extends State<ChallengeView>
    with WidgetsBindingObserver {
  Timer? _refresh;
  String? _previewedVideo;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    // Policy leases expire after 30s. Rechecking also advances the deadline.
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) => _reload());
  }

  void _reload() {
    final cubit = context.read<ChallengeParticipationCubit>();
    if (_foreground && !cubit.state.busy && !cubit.state.picking) {
      unawaited(
        cubit.state.review == null ? cubit.load() : cubit.refreshReview(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _previewedVideo = null;
    });
    if (_foreground) {
      final cubit = context.read<ChallengeParticipationCubit>();
      if (cubit.state.review != null) {
        unawaited(cubit.refreshReview());
      } else {
        _reload();
      }
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _showEntrySources() async {
    final cubit = context.read<ChallengeParticipationCubit>();
    final l10n = context.l10n;
    final source = await VineBottomSheet.show<_EntrySource>(
      context: context,
      scrollable: false,
      showHeader: false,
      children: [
        ListOwnerActionTile(
          identifier: 'challenge-record',
          label: l10n.challengeRecord,
          icon: DivineIconName.videoCamera,
          action: _EntrySource.record,
        ),
        ListOwnerActionTile(
          identifier: 'challenge-choose',
          label: l10n.challengeChoose,
          icon: DivineIconName.filmSlate,
          action: _EntrySource.existing,
        ),
      ],
    );
    if (!mounted ||
        source == null ||
        cubit.state.busy ||
        cubit.state.read?.view.state != 'open') {
      return;
    }
    switch (source) {
      case _EntrySource.record:
        final id = await cubit.record();
        if (mounted && id != null) await widget.onRecord(context, id);
      case _EntrySource.existing:
        await cubit.chooseVideo();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ChallengeParticipationCubit, ChallengeParticipationState>(
    listenWhen: (previous, current) =>
        previous.review != current.review ||
        current.busy ||
        previous.previewGeneration != current.previewGeneration,
    listener: (_, _) => setState(() => _previewedVideo = null),
    builder: (context, state) {
      final l10n = context.l10n;
      final cubit = context.read<ChallengeParticipationCubit>();
      final view = state.read?.view;
      final definition = view?.definition;
      final review = state.review;
      if (review == null && !state.picking && definition != null) {
        return ChallengeDetailView(
          state: state,
          organizerName: widget.organizerName,
          onOrganizerTap: widget.onOrganizerTap,
          viewerPubkey: cubit.submissions.currentOwner(),
          onEnter: _showEntrySources,
          onRefresh: cubit.load,
          onPlay: cubit.playEntry,
          onWithdraw: (entry) => cubit.withdraw(jsonEncode(entry.toJson())),
          allowed: cubit.submissions.reads.isVisible,
          deliveryActions: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.status case final status?)
                Text(
                  challengeStatusText(l10n, status),
                  key: const ValueKey('challenge-status'),
                ),
              for (final id in state.handoffs)
                DivineButton(
                  type: DivineButtonType.quiet,
                  onPressed: state.busy ? null : () => cubit.recover(id),
                  label: l10n.challengeRecover,
                ),
              for (final action in state.actions)
                _ActionCard(action: action, busy: state.busy),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: DiVineAppBar(
          showBackButton: Navigator.of(context).canPop(),
          title: review != null
              ? (review.withdrawalEntry == null
                    ? l10n.challengeReview
                    : l10n.challengeWithdrawReview)
              : l10n.challengeTitle,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: review == null ? cubit.load : cubit.refreshReview,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (review == null)
                  Text(
                    l10n.challengeTestNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                if (state.busy) const DivineLinearProgressIndicator(),
                if (state.status case final status?) ...[
                  Text(
                    challengeStatusText(l10n, status),
                    key: const ValueKey('challenge-status'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (review != null) ...[
                  Text(
                    (parseChallengeEvent(review.definition).value!
                            as ChallengeDefinition)
                        .title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.challengeOwner}: ${widget.ownerName ?? l10n.challengeYourAccount}',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child:
                        !_foreground ||
                            state.busy ||
                            !state.reviewPreviewAllowed
                        ? Center(child: Text(l10n.challengePreviewUnavailable))
                        : ChallengePlayback(
                            key: ValueKey((
                              'review',
                              review.video.id,
                              state.previewGeneration,
                            )),
                            video: review.video,
                            allowed: (video) =>
                                cubit.submissions.currentOwner() ==
                                    review.owner &&
                                cubit.submissions.reads.isVisible(video),
                            onAvailabilityChanged: (available) {
                              if (mounted &&
                                  _foreground &&
                                  !cubit.state.busy &&
                                  cubit.state.reviewPreviewAllowed &&
                                  cubit.state.previewGeneration ==
                                      state.previewGeneration &&
                                  cubit.state.review == review) {
                                setState(
                                  () => _previewedVideo = available
                                      ? review.video.id
                                      : null,
                                );
                              }
                            },
                          ),
                  ),
                  if (review.withdrawalEntry == null &&
                      _previewedVideo != review.video.id)
                    DivineButton(
                      type: DivineButtonType.quiet,
                      label: l10n.commonRetry,
                      onPressed: !_foreground || state.busy
                          ? null
                          : cubit.refreshReview,
                    ),
                  if (review.video.content.isNotEmpty)
                    Text(
                      review.video.content,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.challengeRules,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(review.definition.content),
                  Text(
                    _deadline(
                      context,
                      (parseChallengeEvent(review.definition).value!
                              as ChallengeDefinition)
                          .end,
                    ),
                  ),
                  Text(
                    review.withdrawalEntry == null
                        ? l10n.challengePublicConsent
                        : l10n.challengeWithdrawExplanation,
                  ),
                  ExpansionTile(
                    title: Text(l10n.challengeDetails),
                    children: [
                      _Revision(
                        label: l10n.challengeOwner,
                        value: review.owner,
                      ),
                      _Revision(
                        label: l10n.challengeRulesRevision,
                        value: review.definition.id,
                      ),
                      _Revision(
                        label: l10n.challengeVideoRevision,
                        value: review.video.id,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DivineButton(
                    label: review.withdrawalEntry == null
                        ? l10n.challengeEnterVideo
                        : l10n.challengeWithdrawConfirm,
                    onPressed:
                        !_foreground ||
                            state.busy ||
                            (review.withdrawalEntry == null &&
                                (!state.reviewPreviewAllowed ||
                                    cubit.submissions.currentOwner() !=
                                        review.owner ||
                                    _previewedVideo != review.video.id ||
                                    !cubit.submissions.reads.isVisible(
                                      review.video,
                                    )))
                        ? null
                        : cubit.confirm,
                  ),
                  DivineButton(
                    type: DivineButtonType.quiet,
                    onPressed: state.busy ? null : cubit.cancelReview,
                    label: l10n.commonCancel,
                  ),
                ] else if (state.picking) ...[
                  Text(
                    l10n.challengeChoose,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (state.candidates.isEmpty) Text(l10n.challengeNoVideos),
                  for (final video in state.candidates)
                    ListTile(
                      title: Text(
                        video.title ?? video.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        video.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: state.busy
                          ? null
                          : () => cubit.selectVideo(video.id),
                    ),
                  DivineButton(
                    type: DivineButtonType.quiet,
                    onPressed: state.busy ? null : cubit.cancelReview,
                    label: l10n.commonCancel,
                  ),
                ] else ...[
                  Text(l10n.challengeUnavailable),
                  DivineButton(
                    type: DivineButtonType.quiet,
                    onPressed: state.busy ? null : cubit.load,
                    label: l10n.commonRetry,
                  ),
                  for (final id in state.handoffs)
                    DivineButton(
                      type: DivineButtonType.quiet,
                      onPressed: state.busy ? null : () => cubit.recover(id),
                      label: l10n.challengeRecover,
                    ),
                  for (final action in state.actions)
                    _ActionCard(action: action, busy: state.busy),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Revision extends StatelessWidget {
  const _Revision({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        SelectableText(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.busy});
  final PendingChallengeAction action;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChallengeParticipationCubit>();
    final l10n = context.l10n;
    final withdrawal = action.review.withdrawalEntry != null;
    final eventId =
        (jsonDecode(action.signedBody) as Map<String, dynamic>)['id'];
    final withdrawalPending = cubit.state.actions.any(
      (a) => a.review.withdrawalEntry?.id == eventId,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action.submitted
                  ? (withdrawal
                        ? l10n.challengeWithdrawn
                        : l10n.challengeSubmitted)
                  : l10n.challengePending,
            ),
            Text(
              action.indexed ? l10n.challengeIndexed : l10n.challengeIndexing,
            ),
            _Revision(
              label: l10n.challengeVideoRevision,
              value: action.review.video.id,
            ),
            if (!action.submitted && !withdrawalPending)
              DivineButton(
                type: DivineButtonType.quiet,
                onPressed: busy ? null : () => cubit.retry(action.review.id),
                label: l10n.challengeRetry,
              ),
            if (!withdrawal && !withdrawalPending)
              DivineButton(
                type: DivineButtonType.quiet,
                onPressed: busy
                    ? null
                    : () => cubit.withdraw(action.signedBody),
                label: l10n.challengeWithdraw,
              ),
          ],
        ),
      ),
    );
  }
}

String challengeLifecycleText(AppLocalizations l10n, String state) =>
    switch (state) {
      'open' => l10n.challengeOpen,
      'scheduled' => l10n.challengeScheduled,
      'closed' => l10n.challengeClosed,
      'cancelled' => l10n.challengeCancelled,
      'result' => l10n.challengeResult,
      _ => l10n.challengeUnavailable,
    };
String challengeStatusText(AppLocalizations l10n, SubmissionStatus status) =>
    switch (status) {
      SubmissionStatus.submitted => l10n.challengeSubmitted,
      SubmissionStatus.retryable => l10n.challengePending,
      SubmissionStatus.deliveryPaused => l10n.challengePaused,
      SubmissionStatus.ownerChanged => l10n.challengeOwnerChanged,
      SubmissionStatus.blocked => l10n.challengeBlocked,
      SubmissionStatus.readUnavailable => l10n.challengeUnavailable,
      SubmissionStatus.reviewRequired => l10n.challengeReviewRequired,
      SubmissionStatus.eventTooLarge => l10n.challengeTooLarge,
      _ => l10n.challengeFailed,
    };

String _deadline(BuildContext context, int end) => challengeDeadlineText(
  context.l10n,
  DateTime.fromMillisecondsSinceEpoch(end * 1000, isUtc: true).toLocal(),
);

enum _EntrySource { record, existing }
