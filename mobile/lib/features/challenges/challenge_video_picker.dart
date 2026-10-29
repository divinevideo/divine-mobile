import 'package:challenge_protocol/challenge_protocol.dart' as protocol;
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';

/// Single selection is local; only Continue requests a fresh consent review.
class ChallengeVideoPicker extends StatefulWidget {
  const ChallengeVideoPicker({
    required this.videos,
    required this.busy,
    required this.onCancel,
    required this.onContinue,
    this.loadPreview,
    this.allowed,
    super.key,
  });
  final List<VideoEvent> videos;
  final bool busy;
  final VoidCallback onCancel;
  final Future<void> Function(String) onContinue;
  final Future<protocol.NostrEvent?> Function(String)? loadPreview;
  final bool Function(protocol.NostrEvent)? allowed;
  @override
  State<ChallengeVideoPicker> createState() => _ChallengeVideoPickerState();
}

class _ChallengeVideoPickerState extends State<ChallengeVideoPicker> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = widget.videos.any((v) => v.id == _selected)
        ? _selected
        : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !widget.busy) widget.onCancel();
      },
      child: Scaffold(
        backgroundColor: context.vineColors.nav,
        appBar: DiVineAppBar(
          title: l10n.challengeChoose,
          showBackButton: true,
          onBackPressed: widget.busy ? () {} : widget.onCancel,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(16) > 24
                ? 1
                : 2;
            return CustomScrollView(
              slivers: [
                if (widget.busy)
                  const SliverToBoxAdapter(
                    child: DivineLinearProgressIndicator(),
                  ),
                if (widget.videos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(l10n.challengeNoVideos)),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: (widget.videos.length / columns).ceil(),
                    itemBuilder: (context, row) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child:
                                  row * columns + column >= widget.videos.length
                                  ? const SizedBox.shrink()
                                  : _Candidate(
                                      key: ValueKey(
                                        widget
                                            .videos[row * columns + column]
                                            .id,
                                      ),
                                      video:
                                          widget.videos[row * columns + column],
                                      selected:
                                          selected ==
                                          widget
                                              .videos[row * columns + column]
                                              .id,
                                      loadPreview: widget.loadPreview,
                                      allowed: widget.allowed,
                                      onTap: widget.busy
                                          ? null
                                          : () => setState(
                                              () => _selected = widget
                                                  .videos[row * columns +
                                                      column]
                                                  .id,
                                            ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DivineButton(
                  label: l10n.listContinue,
                  onPressed: widget.busy || selected == null
                      ? null
                      : () => widget.onContinue(selected),
                ),
                DivineButton(
                  label: l10n.commonCancel,
                  type: DivineButtonType.quiet,
                  onPressed: widget.busy ? null : widget.onCancel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Candidate extends StatefulWidget {
  const _Candidate({
    required this.video,
    required this.selected,
    required this.onTap,
    this.loadPreview,
    this.allowed,
    super.key,
  });
  final VideoEvent video;
  final bool selected;
  final VoidCallback? onTap;
  final Future<protocol.NostrEvent?> Function(String)? loadPreview;
  final bool Function(protocol.NostrEvent)? allowed;
  @override
  State<_Candidate> createState() => _CandidateState();
}

class _CandidateState extends State<_Candidate> {
  late final Future<protocol.NostrEvent?> _preview =
      widget.loadPreview?.call(widget.video.id) ?? Future.value();
  @override
  Widget build(BuildContext context) => Semantics(
    selected: widget.selected,
    button: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: widget.selected
              ? context.vineColors.accentPositive
              : context.vineColors.nav,
        ),
      ),
      child: FutureBuilder<protocol.NostrEvent?>(
        future: _preview,
        builder: (context, snapshot) {
          final video = snapshot.data;
          final label = widget.video.title ?? widget.video.content;
          return video != null &&
                  video.id == widget.video.id &&
                  video.pubkey == widget.video.pubkey
              ? ChallengeVideoTile(
                  video: video,
                  allowed: widget.allowed ?? (_) => false,
                  label: label.isEmpty ? context.l10n.challengePlay : label,
                  aspectRatio: 3 / 4,
                  onTap: widget.onTap,
                )
              : InkWell(
                  onTap: widget.onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ProfileTabThumbnail(thumbnailUrl: null),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          label.isEmpty ? context.l10n.challengePlay : label,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
        },
      ),
    ),
  );
}
