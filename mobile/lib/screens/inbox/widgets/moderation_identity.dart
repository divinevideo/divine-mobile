// ABOUTME: Divine Moderation's avatar and closed-thread status for DM
// ABOUTME: surfaces. One place, so the inbox list, the message-requests flow
// ABOUTME: and the conversation header agree on which of its threads is dead.
// ABOUTME: The account's NAME is resolved by dmPeerName, not here.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';

/// Brand artwork for the Divine moderation account's avatar.
///
/// Pass as [UserAvatar.contentOverride] so it inherits the shared avatar
/// chrome. That slot is laid out with `StackFit.expand`, so this fills the
/// avatar box at whatever size the call site asked for and needs no size of
/// its own.
///
/// The account's kind-0 `picture` is the hosted `divine-logo.svg`, which
/// colours its paths through a `<style>` block. `vector_graphics_compiler` has
/// no `<style>` parser, so it discards the stylesheet and every path falls
/// back to opaque black — 1.1:1 against the inbox surface. The bundled
/// `logo.svg` is the same wordmark carrying presentational `fill` attributes
/// instead, so it survives the parser and renders in brand green.
///
/// `BoxFit.cover` matches how divine-web frames the same artwork: the wordmark
/// is 3.8:1, so filling a square avatar crops it to the middle "Vi". Contain
/// would letterbox the whole lockup into an illegible sliver.
class ModerationAvatar extends StatelessWidget {
  const ModerationAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.containerLow,
      child: const DivineIcon(icon: DivineIconName.logo, fit: BoxFit.cover),
    );
  }
}

/// The status line a retired moderation thread shows in place of its message
/// preview, in every list a closed thread can land in.
///
/// The row it sits in is otherwise indistinguishable from the live pinned
/// support row: [isModerationAccount] answers for retired keys too, so both
/// carry the name "Divine Moderation" and the same [ModerationAvatar]
/// wordmark, and both stamp the same relative timestamp. #6416 already put
/// `dmRetiredThreadClosedTitle` in the preview slot, but in the preview's own
/// font and colour — a sentence sitting where the eye reads "the last thing
/// they said", which is why a closed thread still had to be opened to be
/// recognised (#7847). The lock is what makes it scan as a status instead.
///
/// The ink stays `onSurfaceVariant`, the colour the preview it replaces
/// already used. Dimming it to `onSurfaceMuted` would have marked the row
/// twice over, but that token is 3.3:1 on the light surface — under the 4.5:1
/// this text needs — so the glyph carries the distinction alone.
///
/// Deliberately reuses the string the opened thread's closed-composer notice
/// puts at its top, rather than a shorter list-only variant, so the row and the
/// screen it opens make the same claim in the same words.
///
/// The glyph carries no semantics of its own — `DivineIcon` renders through
/// `SvgPicture.asset` with no `semanticsLabel` — which is correct here: the
/// sentence beside it already says "closed", and labelling the lock would make
/// assistive tech announce the status twice.
class ClosedThreadSubtitle extends StatelessWidget {
  const ClosedThreadSubtitle({this.maxLines = 1, super.key});

  /// Matches the preview this replaces, so swapping one for the other cannot
  /// change the row's height: the inbox list wraps to two lines, the request
  /// list to one.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodyMediumFont(
      color: context.vineColors.onSurfaceVariant,
    );
    return Row(
      // Top-anchored with the glyph boxed to the line height, so the lock sits
      // on the first line rather than drifting to the middle of a wrapped one.
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        DivineIcon(
          icon: DivineIconName.lockSimple,
          color: context.vineColors.onSurfaceVariant,
          size: style.fontSize! * (style.height ?? 1),
        ),
        Expanded(
          child: Text(
            context.l10n.dmRetiredThreadClosedTitle,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
