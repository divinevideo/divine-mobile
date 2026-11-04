import 'dart:async';

import 'package:challenge_protocol/challenge_protocol.dart' as protocol;
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/l10n/l10n.dart';

/// Single selection is local; only Continue requests a fresh consent review.
class ChallengeVideoPicker extends StatefulWidget {
  const ChallengeVideoPicker({
    required this.videos,
    required this.busy,
    required this.onCancel,
    required this.onContinue,
    this.loadPreview,
    this.allowed,
    this.hasMore = false,
    this.onLoadMore,
    this.error,
    super.key,
  });
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final String? error;
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
                if (widget.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(widget.error!),
                    ),
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
                if (widget.hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DivineButton(
                        label: l10n.profileShowMore,
                        type: DivineButtonType.quiet,
                        onPressed: widget.busy ? null : widget.onLoadMore,
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

class _CandidateState extends State<_Candidate> with WidgetsBindingObserver {
  Timer? _renewal;
  protocol.NostrEvent? _video;
  bool _foreground = true;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    unawaited(_renew());
    _renewal = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_renew()),
    );
  }

  Future<void> _renew() async {
    if (!_foreground || _loading || widget.loadPreview == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _video = null;
    });
    protocol.NostrEvent? video;
    try {
      video = await widget.loadPreview!(widget.video.id);
    } on Object {
      // A failed exact read must never fall back to owner-feed metadata.
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _video =
          _foreground &&
              video?.id == widget.video.id &&
              video?.pubkey == widget.video.pubkey
          ? video
          : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _generation++;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _video = null;
      _loading = false;
    });
    if (_foreground) unawaited(_renew());
  }

  @override
  void dispose() {
    _generation++;
    _renewal?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      child: _video != null && _foreground
          ? ChallengeVideoTile(
              video: _video,
              allowed: widget.allowed ?? (_) => false,
              aspectRatio: 3 / 4,
              onTap: widget.onTap,
            )
          : AspectRatio(
              aspectRatio: 3 / 4,
              child: Center(
                child: _loading
                    ? const DivineCircularProgressIndicator()
                    : DivineButton(
                        label: context.l10n.commonRetry,
                        type: DivineButtonType.quiet,
                        onPressed: _foreground ? _renew : null,
                      ),
              ),
            ),
    ),
  );
}
