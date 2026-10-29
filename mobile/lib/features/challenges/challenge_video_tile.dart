import 'dart:async';

import 'package:challenge_protocol/challenge_protocol.dart' as protocol;
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';

/// Adapts only the supplied verified revision, including all v1 video kinds.
/// This never resolves an address or confers challenge membership.
VideoEvent? challengeVideoModel(protocol.NostrEvent video) {
  try {
    return VideoEvent.fromNostrEvent(
      Event.fromJson(video.toJson()),
      permissive: true,
    );
  } on Object {
    return null;
  }
}

/// A pinned video with a current policy lease. Null videos retain result slots.
class ChallengeVideoTile extends StatefulWidget {
  const ChallengeVideoTile({
    required this.video,
    required this.allowed,
    this.onTap,
    this.label,
    this.aspectRatio,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });
  final protocol.NostrEvent? video;
  final bool Function(protocol.NostrEvent) allowed;
  final VoidCallback? onTap;
  final String? label;
  final double? aspectRatio;
  final BorderRadiusGeometry borderRadius;
  @override
  State<ChallengeVideoTile> createState() => _ChallengeVideoTileState();
}

class _ChallengeVideoTileState extends State<ChallengeVideoTile>
    with WidgetsBindingObserver {
  Timer? _policy;
  bool _foreground = true;
  bool _visible = false;
  bool get _allowed =>
      _foreground && widget.video != null && widget.allowed(widget.video!);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _visible = _allowed;
    _policy = Timer.periodic(const Duration(seconds: 1), (_) {
      final visible = _allowed;
      if (visible != _visible) setState(() => _visible = visible);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _visible = _allowed;
    });
  }

  @override
  void dispose() {
    _policy?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.video == null
        ? null
        : challengeVideoModel(widget.video!);
    final visible = _allowed && model != null;
    final ratio =
        widget.aspectRatio ??
        ((model?.width ?? 3) / (model?.height ?? 4)).clamp(0.5625, 1.778);
    final title =
        widget.label ??
        (model?.content.isNotEmpty ?? false
            ? model!.content
            : context.l10n.challengePlay);
    return Semantics(
      button: visible && widget.onTap != null,
      enabled: visible && widget.onTap != null,
      child: Material(
        color: context.vineColors.surfaceContainer,
        child: InkWell(
          onTap: !visible || widget.onTap == null
              ? null
              : () {
                  if (_allowed) widget.onTap!();
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: widget.borderRadius,
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: visible
                      ? ProfileTabThumbnail(
                          thumbnailUrl: model.thumbnailUrl,
                          blurhash: model.blurhash,
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              context.l10n.challengeWinnerUnavailable,
                              style: VineTheme.bodyMediumFont(
                                color: context.vineColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  maxLines: widget.label == null ? 2 : null,
                  overflow: widget.label == null ? TextOverflow.ellipsis : null,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
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
