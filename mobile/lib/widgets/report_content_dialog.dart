// ABOUTME: Report content bottom sheet for Apple-compliant content reporting.
// ABOUTME: Replaces the legacy AlertDialog with a VineBottomSheet-based flow.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/report/report_submission_cubit.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/content_moderation.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/report_content_confirmation.dart';
import 'package:openvine/widgets/support_capped_text_field.dart';

/// The kinds of list that can be reported, with their NIP-51 event kinds.
enum ReportedListKind {
  /// A people list: a NIP-51 follow set.
  people(30000),

  /// A video list: a NIP-51 curation set of videos.
  videos(30005);

  const ReportedListKind(this.nostrKind);

  final int nostrKind;
}

/// What the report form's heading names as the thing being reported.
enum ReportedSubject {
  /// A video, list, message, or account: the general wording.
  content,

  /// A comment.
  comment,
}

/// Shows a [VineBottomSheet] for reporting content or a user.
///
/// Usage:
/// ```dart
/// await ReportContentDialog.show(context, video: video);
/// await ReportContentDialog.showForMessage(
///   context,
///   messageId: message.id,
///   senderPubkey: message.senderPubkey,
/// );
/// await ReportContentDialog.showForUser(
///   context,
///   userPubkey: pubkey,
/// );
/// await ReportContentDialog.showForComment(
///   context,
///   commentId: comment.id,
///   authorPubkey: comment.authorPubkey,
/// );
/// ```
class ReportContentDialog extends ConsumerWidget {
  ReportContentDialog({
    super.key,
    this.video,
    this.eventId,
    this.authorPubkey,
    this.userPubkey,
    this.moderationKindLabel = 'Content Report',
    this.moderationEventLabel = 'Event',
    this.reasons = ContentFilterReason.values,
    this.additionalContext,
    this.addressableCoordinate,
    this.subject = ReportedSubject.content,
    this.isFromShareMenu = false,
    this.draggableController,
    this.scrollController,
  }) {
    final hasVideo = video != null;
    final hasContent = eventId != null && authorPubkey != null;
    final hasUser = userPubkey != null;
    if (!hasVideo && !hasContent && !hasUser) {
      throw ArgumentError(
        'Provide a video, both eventId and authorPubkey, or a userPubkey.',
      );
    }
  }

  /// The video being reported. When non-null, [eventId] / [authorPubkey]
  /// fall back to `video.id` / `video.pubkey`.
  final VideoEvent? video;

  /// Event id of the content being reported. Required when [video] is null
  /// and this is not a user-targeted report.
  final String? eventId;

  /// Author pubkey of the content being reported. Required when [video]
  /// is null and this is not a user-targeted report.
  final String? authorPubkey;

  /// Pubkey of the user being reported.
  ///
  /// When non-null, the report targets the user (no specific event) and
  /// [ReportSubmissionCubit] routes it through
  /// `ContentReportingService.reportUser` instead of `reportContent`.
  final String? userPubkey;

  /// Header used in the moderation DM (e.g. "Content Report", "DM
  /// Message Report"). Internal-only — not user-visible.
  final String moderationKindLabel;

  /// Label preceding the event id in the moderation DM body (e.g.
  /// "Event", "Message ID"). Internal-only — not user-visible.
  final String moderationEventLabel;

  /// The reasons offered, in display order. Every reason by default; a list
  /// offers [listReportReasons].
  final List<ContentFilterReason> reasons;

  /// Extra text for the report, such as a reported list's title.
  final String? additionalContext;

  /// Coordinate of a reported addressable event, such as a list, published
  /// as an `a` tag beside the NIP-56 targets.
  final String? addressableCoordinate;

  /// What the heading names as the thing being reported.
  final ReportedSubject subject;

  final bool isFromShareMenu;

  /// Optional controller used to programmatically expand the bottom sheet
  /// to full height when the details field takes focus (so it is reachable
  /// above the keyboard).
  final DraggableScrollableController? draggableController;

  /// Scroll controller handed down by the enclosing [VineBottomSheet].
  ///
  /// The sheet's [DraggableScrollableSheet] only reacts to a downward drag
  /// when its own controller drives the scroll view inside it — with a
  /// foreign controller the drag is swallowed by the content and the sheet
  /// can no longer be pulled closed. Null when the dialog is shown outside a
  /// draggable sheet, where an internal controller stands in.
  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required VideoEvent video,
    bool isFromShareMenu = false,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: VineTheme.bottomSheetDismissFloor,
          draggableController: controller,
          buildScrollBody: (scrollController) => ReportContentDialog(
            video: video,
            isFromShareMenu: isFromShareMenu,
            draggableController: controller,
            scrollController: scrollController,
          ),
        )
        .whenComplete(controller.dispose);
  }

  /// Shows the bottom sheet for reporting a DM message. Uses the same UX
  /// as the video flow; differs only in the moderation-DM body labels.
  static Future<void> showForMessage(
    BuildContext context, {
    required String messageId,
    required String senderPubkey,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: VineTheme.bottomSheetDismissFloor,
          draggableController: controller,
          buildScrollBody: (scrollController) => ReportContentDialog(
            eventId: messageId,
            authorPubkey: senderPubkey,
            moderationKindLabel: 'DM Message Report',
            moderationEventLabel: 'Message ID',
            draggableController: controller,
            scrollController: scrollController,
          ),
        )
        .whenComplete(controller.dispose);
  }

  /// Shows the bottom sheet for reporting a comment.
  ///
  /// The same form, reasons, and note rules as every other report; only the
  /// heading and the moderation-DM labels name a comment.
  static Future<void> showForComment(
    BuildContext context, {
    required String commentId,
    required String authorPubkey,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: VineTheme.bottomSheetDismissFloor,
          draggableController: controller,
          buildScrollBody: (scrollController) => ReportContentDialog(
            eventId: commentId,
            authorPubkey: authorPubkey,
            moderationKindLabel: 'Comment Report',
            moderationEventLabel: 'Comment ID',
            subject: ReportedSubject.comment,
            draggableController: controller,
            scrollController: scrollController,
          ),
        )
        .whenComplete(controller.dispose);
  }

  /// Shows the bottom sheet for reporting a user account (e.g. for
  /// harassment, impersonation, or underage account claims).
  ///
  /// Routes submission through `ContentReportingService.reportUser`, which
  /// emits a NIP-56 report with the synthetic `user_<pubkey>` event id.
  static Future<void> showForUser(
    BuildContext context, {
    required String userPubkey,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: VineTheme.bottomSheetDismissFloor,
          draggableController: controller,
          buildScrollBody: (scrollController) => ReportContentDialog(
            userPubkey: userPubkey,
            moderationKindLabel: 'User Report',
            moderationEventLabel: 'User Pubkey',
            draggableController: controller,
            scrollController: scrollController,
          ),
        )
        .whenComplete(controller.dispose);
  }

  /// Shows the bottom sheet for reporting someone else's video or people
  /// list.
  ///
  /// [eventId] is the list's current event and [authorPubkey] its author.
  /// The report also names the list's NIP-01 address,
  /// `<kind>:<author>:<dTag>`, which stays the same when an edit republishes
  /// the list under a new event id. The [title] goes into the report so a
  /// moderator can tell which list it is.
  static Future<void> showForList(
    BuildContext context, {
    required ReportedListKind kind,
    required String eventId,
    required String authorPubkey,
    required String dTag,
    required String title,
  }) {
    final coordinate = '${kind.nostrKind}:$authorPubkey:$dTag';
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: VineTheme.bottomSheetDismissFloor,
          draggableController: controller,
          buildScrollBody: (scrollController) => ReportContentDialog(
            eventId: eventId,
            authorPubkey: authorPubkey,
            moderationKindLabel: 'List Report',
            moderationEventLabel: 'List Event',
            reasons: listReportReasons,
            additionalContext: 'Reported list: "$title" ($coordinate)',
            addressableCoordinate: coordinate,
            draggableController: controller,
            scrollController: scrollController,
          ),
        )
        .whenComplete(controller.dispose);
  }

  /// What this report targets, derived from the mutually exclusive
  /// constructor shapes the `show*` factories use.
  ReportTarget get _target {
    final userPubkey = this.userPubkey;
    return ReportTarget(
      eventId: userPubkey != null ? 'user_$userPubkey' : (eventId ?? video!.id),
      authorPubkey: userPubkey ?? authorPubkey ?? video!.pubkey,
      userPubkey: userPubkey,
      sourceRelay: video?.sourceRelay,
      sha256: video?.sha256,
      videoUrl: video?.videoUrl,
      moderationKindLabel: moderationKindLabel,
      moderationEventLabel: moderationEventLabel,
      additionalContext: additionalContext,
      addressableCoordinate: addressableCoordinate,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider<ReportSubmissionCubit>(
      create: (_) => ReportSubmissionCubit(
        // Account-scoped dependencies are resolved late rather than watched
        // here. The primary report service is read per submit so account
        // switches use the current account's durable reporting queue.
        resolveContentReportingService: () =>
            ref.read(contentReportingServiceProvider.future),
        target: _target,
      ),
      child: _ReportContentView(
        reasons: reasons,
        subject: subject,
        isFromShareMenu: isFromShareMenu,
        draggableController: draggableController,
        scrollController: scrollController,
      ),
    );
  }
}

/// The report form and its confirmation. Owns form state only — the
/// submission itself lives in [ReportSubmissionCubit].
class _ReportContentView extends StatefulWidget {
  const _ReportContentView({
    required this.reasons,
    required this.subject,
    required this.isFromShareMenu,
    this.draggableController,
    this.scrollController,
  });

  final List<ContentFilterReason> reasons;
  final ReportedSubject subject;
  final bool isFromShareMenu;
  final DraggableScrollableController? draggableController;
  final ScrollController? scrollController;

  @override
  State<_ReportContentView> createState() => _ReportContentViewState();
}

class _ReportContentViewState extends State<_ReportContentView> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  final FocusNode _detailsFocusNode = FocusNode();
  final GlobalKey _detailsFieldKey = GlobalKey();

  /// One key per reason card, kept for the form's life, so picking a reason
  /// leaves every card the same element: the selection border animates and a
  /// screen reader stays on the card it tapped. The selected one is the
  /// anchor the note scrolls under.
  final Map<ContentFilterReason, GlobalKey> _cardKeys = {};
  GlobalKey _cardKey(ContentFilterReason reason) =>
      _cardKeys.putIfAbsent(reason, GlobalKey.new);

  final GlobalKey _detailsBoxKey = GlobalKey();
  final ScrollController _fallbackScrollController = ScrollController();

  /// The inline error for a failed submit, shown in the footer. Widget-local:
  /// it is already-localized display text, which is exactly what must not
  /// live in cubit state.
  String? _errorMessage;

  /// Whether Report was tapped under Other with no note. Shown inside the
  /// note box, beside the field it asks the reporter to fill in.
  bool _noteRequired = false;

  /// Whether the reporter just tried to insert an image the report cannot
  /// carry. Held here, beside the other form state, so the one-shot notice
  /// does not depend on the field's own State surviving. The notice renders
  /// above the field (see [_ReportFormBody]) so the keyboard cannot cover it.
  bool _imageInsertionRejected = false;

  bool _scrollWhenKeyboardOpens = false;

  /// The scroll viewport's height when its metrics last changed, so a change
  /// can be told apart as the view shrinking (keyboard opening) or growing.
  double? _lastViewportHeight;
  double _previousViewInsetsBottom = 0;

  ScrollController get _scrollController =>
      widget.scrollController ?? _fallbackScrollController;

  /// Submission needs a reason; "Other" additionally needs details, but that
  /// stays a tap-time inline error so the reason for the block is explained.
  bool _canSubmit(bool isSubmitting) =>
      _selectedReason != null && !isSubmitting;

  @override
  void initState() {
    super.initState();
    _detailsFocusNode.addListener(_onDetailsFocusChanged);
  }

  /// The details field shows for every reason, so whichever way it takes
  /// focus (tapped, or focused for the reporter on picking Other) the sheet
  /// grows and the field is scrolled clear of the keyboard once it opens.
  void _onDetailsFocusChanged() {
    if (!_detailsFocusNode.hasFocus) return;
    final controller = widget.draggableController;
    if (controller != null && controller.isAttached) {
      runDetached(
        controller.animateTo(
          0.95,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
        'expand report sheet for details',
        logName: 'ReportContentDialog',
        category: LogCategory.ui,
      );
    }
    _scrollWhenKeyboardOpens = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (_scrollWhenKeyboardOpens &&
        currentBottom > _previousViewInsetsBottom &&
        currentBottom > 100) {
      _scrollWhenKeyboardOpens = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollNoteIntoView();
      });
    }
    _previousViewInsetsBottom = currentBottom;
  }

  /// Scrolls the note into view. Normally the chosen card goes to the top,
  /// with its note right under it, so the reason stays in view above the
  /// field it qualifies. While the missing-note error shows, the end of the
  /// note box, where that error is, is kept visible instead: the box sits
  /// low enough that pinning the card can push the error behind the footer.
  void _scrollNoteIntoView({bool animate = true}) {
    final selected = _selectedReason;
    final (anchor, policy) = _noteRequired
        ? (_detailsBoxKey, ScrollPositionAlignmentPolicy.keepVisibleAtEnd)
        : (
            selected == null ? null : _cardKey(selected),
            ScrollPositionAlignmentPolicy.explicit,
          );
    final ctx = anchor?.currentContext;
    if (ctx == null) return;
    runDetached(
      Scrollable.ensureVisible(
        ctx,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOut,
        alignmentPolicy: policy,
      ),
      'scroll report details into view',
      logName: 'ReportContentDialog',
      category: LogCategory.ui,
    );
  }

  void _onReasonSelected(ContentFilterReason reason) {
    final wasOther = _selectedReason == ContentFilterReason.other;
    setState(() {
      _selectedReason = reason;
      _errorMessage = null;
      _noteRequired = false;
    });

    // Other is the one reason whose note is required, so it takes the
    // reporter straight to the field. The focus listener does the rest.
    if (reason == ContentFilterReason.other && !wasOther) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _detailsFocusNode.requestFocus();
      });
    }
  }

  void _onImageInsertionRejected() {
    // Reports are text only; there is no attachment path, so a keyboard-
    // inserted image is intentionally dropped and never touches the field or
    // any report state (#8210). Android-only: the engine implements
    // commitContent nowhere else. Surface the drop so the reporter uses words.
    if (!mounted) return;
    if (!_imageInsertionRejected) {
      setState(() => _imageInsertionRejected = true);
    }
    // Announce on every attempt, not via liveRegion (which fires once per
    // appearance): each commit is a discrete action, and the spoken notice is
    // the channel that still lands when the visual one is briefly behind the
    // keyboard.
    announceDetached(
      context,
      context.l10n.reportDetailsImageNotAttached,
      description: 'announce dropped report attachment',
      logName: 'ReportContentDialog',
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (ReportSubmissionCubit cubit) => cubit.state.status,
    );
    final submitted = status == ReportSubmissionStatus.submitted;
    final isSubmitting = status == ReportSubmissionStatus.submitting;

    // One scroll view across both states so the sheet's scroll controller
    // stays attached to a single position when the form is swapped for the
    // confirmation — the actions ride in the pinned footer instead.
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            // The keyboard, the footer riding it, and the sheet growing for
            // the note all shrink the viewport over several frames, after a
            // scroll aimed at the old size has run. While the missing-note
            // error shows, follow each shrink so it stays in view. Only this
            // view's own changes count, not the note field's inner scroll,
            // and only shrinking: a view that grows, as when the keyboard
            // closes, gives the reporter room and is no reason to move them.
            // A reporter's own scrolling does not send this notification.
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              final height = notification.metrics.viewportDimension;
              final last = _lastViewportHeight;
              _lastViewportHeight = height;
              if (_noteRequired && last != null && height < last) {
                _scrollNoteIntoView(animate: false);
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
              child: submitted
                  ? const ReportConfirmationBody()
                  : _ReportFormBody(
                      reasons: widget.reasons,
                      subject: widget.subject,
                      selectedReason: _selectedReason,
                      onReasonSelected: _onReasonSelected,
                      detailsController: _detailsController,
                      detailsFocusNode: _detailsFocusNode,
                      detailsFieldKey: _detailsFieldKey,
                      cardKey: _cardKey,
                      detailsBoxKey: _detailsBoxKey,
                      onDetailsChanged: _onDetailsChanged,
                      imageInsertionRejected: _imageInsertionRejected,
                      noteRequired: _noteRequired,
                      onImageInserted: _onImageInsertionRejected,
                    ),
            ),
          ),
        ),
        // A failed submit's error rides the footer rather than the end of the
        // scroll content: with the submit action pinned, the user can submit
        // from any scroll offset, and an error appended below eleven reason
        // cards lands off-screen — the tap would look like it did nothing.
        // Other's missing note is the exception: its error sits in the note
        // box, which is scrolled into view instead (see
        // [_scrollNoteIntoView]).
        VineKeyboardAwareFooter(
          includeSafeArea: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: submitted
                ? ReportConfirmationActions(
                    isFromShareMenu: widget.isFromShareMenu,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      if (_errorMessage case final message?)
                        _InlineError(message: message),
                      DivineButton(
                        label: context.l10n.reportSubmit,
                        expanded: true,
                        onPressed: _canSubmit(isSubmitting)
                            ? _handleSubmitReport
                            : null,
                        isLoading: isSubmitting,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _onDetailsChanged() {
    if (_errorMessage == null && !_noteRequired && !_imageInsertionRejected) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _noteRequired = false;
      _imageInsertionRejected = false;
    });
  }

  void _handleSubmitReport() {
    final cubit = context.read<ReportSubmissionCubit>();
    if (cubit.state.isSubmitting) return;
    if (_selectedReason == ContentFilterReason.other &&
        _detailsController.text.trim().isEmpty) {
      if (_noteRequired) {
        // Already on screen, so its live region stays quiet. Say it again
        // or a screen-reader user's repeat tap gets no answer at all.
        announceDetached(
          context,
          context.l10n.reportOtherRequiresDetails,
          description: 'announce the required report note again',
          logName: 'ReportContentDialog',
        );
      } else {
        setState(() => _noteRequired = true);
      }
      _detailsFocusNode.requestFocus();
      // The note box can sit behind the footer, so bring the error into view
      // and the Report tap visibly did something.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollNoteIntoView();
      });
      return;
    }
    unawaited(_submitReport(cubit));
  }

  Future<void> _submitReport(ReportSubmissionCubit cubit) async {
    final reason = _selectedReason;
    if (reason == null) return;

    // One reason serves this whole submit, captured before the first await
    // and handed to the cubit. The kind-1984 publish and the moderation DM
    // are a relay round trip apart, and nothing freezes the selection in
    // between — the reason cards stay tappable while the submit is in flight.
    // Re-reading the selection on the far side let the two channels label the
    // same report differently, which is the divergence these tags exist to
    // prevent.
    setState(() => _errorMessage = null);
    final l10n = context.l10n;
    final selectedReasonTitle = l10n.reportReasonTitle(reason);
    // Sent as typed, and empty when nothing was: the reason already travels
    // in its own field and tags, and a filled-in label would read to a
    // moderator as words the reporter wrote (#10003). The field shows for
    // every reason, so what is sent is always what the reporter can see.
    final details = _detailsController.text.trim();

    await cubit.submit(
      reason: reason,
      reasonTitle: selectedReasonTitle,
      details: details,
    );
    if (!mounted) return;

    final status = cubit.state.status;
    setState(() {
      _errorMessage = switch (status) {
        ReportSubmissionStatus.failure => l10n.reportFailed,
        _ => null,
      };
    });

    if (status == ReportSubmissionStatus.submitted) {
      final controller = widget.draggableController;
      if (controller != null && controller.isAttached) {
        runDetached(
          controller.animateTo(
            0.65,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
          'collapse report sheet after submission',
          logName: 'ReportContentDialog',
          category: LogCategory.ui,
        );
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _detailsFocusNode
      ..removeListener(_onDetailsFocusChanged)
      ..dispose();
    _fallbackScrollController.dispose();
    super.dispose();
  }
}

// =============================================================================
// Report form
// =============================================================================

class _ReportFormBody extends StatelessWidget {
  const _ReportFormBody({
    required this.reasons,
    required this.subject,
    required this.selectedReason,
    required this.onReasonSelected,
    required this.detailsController,
    required this.detailsFocusNode,
    required this.detailsFieldKey,
    required this.cardKey,
    required this.detailsBoxKey,
    required this.onDetailsChanged,
    required this.imageInsertionRejected,
    required this.noteRequired,
    required this.onImageInserted,
  });

  final List<ContentFilterReason> reasons;
  final ReportedSubject subject;
  final ContentFilterReason? selectedReason;
  final ValueChanged<ContentFilterReason> onReasonSelected;
  final TextEditingController detailsController;
  final FocusNode detailsFocusNode;
  final GlobalKey detailsFieldKey;

  /// The stable key of each reason card; the selected one is scrolled back
  /// into view once the keyboard pushes the details field up.
  final GlobalKey Function(ContentFilterReason reason) cardKey;

  /// Keeps the note box one element as it moves under a newly picked
  /// reason, so its state, such as the limit-reached notice, moves with it.
  final GlobalKey detailsBoxKey;

  /// Clears a pending validation error (and the image-rejection notice) as
  /// soon as the user edits the details.
  final VoidCallback onDetailsChanged;

  /// Whether the reporter tried to insert an image; drives the not-attached
  /// notice shown above the field.
  final bool imageInsertionRejected;

  /// Whether Report was tapped under Other with no note; drives the error
  /// shown under the field.
  final bool noteRequired;

  /// Forwarded to the details field's content-insertion handler.
  final VoidCallback onImageInserted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detailsLabel = selectedReason == ContentFilterReason.other
        ? l10n.reportDetailsRequired
        : l10n.reportDetailsOptional;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          switch (subject) {
            ReportedSubject.content => l10n.reportWhyReporting,
            ReportedSubject.comment => l10n.reportWhyReportingComment,
          },
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.reportPolicyNotice,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        for (final reason in reasons) ...[
          Padding(
            key: cardKey(reason),
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReasonCard(
              title: l10n.reportReasonTitle(reason),
              subtitle: l10n.reportReasonSubtitle(reason),
              isSelected: selectedReason == reason,
              onTap: () => onReasonSelected(reason),
            ),
          ),
          // Opens under whichever reason is picked, so every reporter sees
          // they can say why without scrolling for it. The note is optional
          // except under Other, which has no meaning without one. The text
          // lives in the shared controller, so a note typed under one reason
          // is still on screen, and is what gets sent, after switching.
          if (reason == selectedReason)
            Padding(
              key: detailsBoxKey,
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      // The field announces this label itself (see
                      // [_CappedDetailsField]), so the visible copy is kept
                      // out of the tree rather than read twice.
                      ExcludeSemantics(
                        child: Text(
                          detailsLabel,
                          style: VineTheme.labelSmallFont(
                            color: context.vineColors.accentPositive,
                          ),
                        ),
                      ),
                      Text(
                        l10n.reportDetailsTextOnly,
                        style: VineTheme.labelSmallFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                      ),
                      if (imageInsertionRejected)
                        const _ImageNotAttachedNotice(),
                      _CappedDetailsField(
                        label: detailsLabel,
                        fieldKey: detailsFieldKey,
                        controller: detailsController,
                        focusNode: detailsFocusNode,
                        onChanged: onDetailsChanged,
                        onImageInserted: onImageInserted,
                      ),
                      if (noteRequired)
                        _InlineError(
                          message: l10n.reportOtherRequiresDetails,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // `container` makes this its own node and absorbs the Text below, so the
    // live region already reads [message]. Repeating it as a `label:` here
    // would prepend a second copy.
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.error.withValues(alpha: 0.1),
          border: Border.all(color: VineTheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.warningCircle,
                color: VineTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: VineTheme.bodySmallFont(color: VineTheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Reason card
// =============================================================================

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? context.vineColors.accentPositive
                  : context.vineColors.surfaceContainer,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _RadioIndicator(isSelected: isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VineTheme.bodyLargeFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Fill and ring resolve from the same token: a raw-green fill under
          // an `accentPositive` ring reads two-tone in light (2.92:1 between
          // them), and it left the white check at 2.11:1 on the fill.
          color: isSelected
              ? context.vineColors.accentPositive
              : VineTheme.transparent,
          border: Border.all(
            color: context.vineColors.accentPositive,
            width: 2,
          ),
        ),
        child: isSelected
            ? Center(
                child: DivineIcon(
                  icon: DivineIconName.check,
                  size: 14,
                  color: context.vineColors.surface,
                ),
              )
            : null,
      ),
    );
  }
}

/// The report details field, capped like the other support forms and saying so
/// when the cap dropped part of a paste.
///
/// Its own widget because the notice needs state: whether the limiter actually
/// truncated, which cannot be derived by comparing `String.length` to the cap.
class _CappedDetailsField extends StatefulWidget {
  const _CappedDetailsField({
    required this.label,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onImageInserted,
  });

  /// The box's visible label (required or optional), announced as the
  /// field's own label. The field has no decoration label of its own, so
  /// without this a screen reader reaches an unnamed text field.
  final String label;

  final GlobalKey fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  /// Called when the keyboard commits image content, so the durable parent
  /// records the rejection and announces it.
  final VoidCallback onImageInserted;

  @override
  State<_CappedDetailsField> createState() => _CappedDetailsFieldState();
}

class _CappedDetailsFieldState extends State<_CappedDetailsField> {
  bool _truncated = false;

  void _onTruncated() {
    if (_truncated || !mounted) return;
    setState(() => _truncated = true);
    announceDetached(
      context,
      context.l10n.supportFieldLimitReached,
      description: 'announce report details field limit',
      logName: 'ReportContentDialog',
    );
  }

  void _onChanged(String value) {
    widget.onChanged();
    if (_truncated &&
        value.characters.length < BugReportConfig.maxFreeTextFieldLength) {
      setState(() => _truncated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        // Merged so the label lands on the text field's own node: a parent
        // label alone becomes a separate node a screen reader reads apart
        // from the field.
        MergeSemantics(
          child: Semantics(
            label: widget.label,
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: widget.focusNode,
              enableInteractiveSelection: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onChanged,
              // Without a configuration Flutter advertises an empty mime-type
              // list, so Android refuses the insert itself and shows a system
              // toast that vanishes and never mentions the report. Declaring
              // the default image types moves that moment into the app, where
              // the handler can answer it in our own words. #8223 chose not to
              // hide the keyboard's image button, so it stays live.
              contentInsertionConfiguration: ContentInsertionConfiguration(
                onContentInserted: (_) => widget.onImageInserted(),
              ),
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.primaryText,
              ),
              minLines: 3,
              maxLines: 5,
              inputFormatters: [
                ReportingLengthLimiter(
                  BugReportConfig.maxFreeTextFieldLength,
                  _onTruncated,
                ),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ),
        if (_truncated)
          Text(
            context.l10n.supportFieldLimitReached,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The one-shot notice shown when the keyboard tries to insert an image the
/// report cannot carry. Rendered above the field (in [_ReportFormBody]) so it
/// is not occluded by the keyboard's media panel at the moment it fires
/// (measured on device in #8511's review).
class _ImageNotAttachedNotice extends StatelessWidget {
  const _ImageNotAttachedNotice();

  @override
  Widget build(BuildContext context) {
    final palette = context.vineColors;
    return Text(
      context.l10n.reportDetailsImageNotAttached,
      style: VineTheme.labelSmallFont(color: palette.onSurfaceVariant),
    );
  }
}
