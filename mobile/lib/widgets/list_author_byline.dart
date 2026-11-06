// ABOUTME: "by {author}" row under a list's title, with the author's avatar
// ABOUTME: and their name as a text link that opens their profile.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vanished_account_identity.dart';

/// Edge of the author avatar beside the byline.
const kListAuthorAvatarSize = 24.0;

/// Stands in for the name while splitting the localized byline, so each
/// locale can put the name where its grammar wants it.
const _nameMarker = '\u0000';

/// The author of a list, credited under its title.
///
/// The whole row is one tap target, announced as a button, and [onTap]
/// opens the author's profile.
class ListAuthorByline extends ConsumerWidget {
  const ListAuthorByline({
    required this.authorPubkey,
    required this.onTap,
    super.key,
  });

  /// The author as lowercase hex.
  final String authorPubkey;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(authorPubkey)).value;
    final isVanished = ref.watch(profileVanishedProvider(authorPubkey));
    final name = vanishedAccountName(
      context,
      isVanished: isVanished,
      fallbackName:
          profile?.betterDisplayName(null) ??
          UserProfile.defaultDisplayNameFor(authorPubkey),
    );
    final pictureUrl = vanishedAccountPictureUrl(
      isVanished: isVanished,
      pictureUrl: profile?.picture,
    );
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.listByAuthor(name),
      // excludeSemantics drops the GestureDetector's own tap action, so the
      // row has to carry it for a screen reader to open the author.
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          spacing: 8,
          children: [
            UserAvatar(
              imageUrl: pictureUrl,
              placeholderSeed: authorPubkey,
              size: kListAuthorAvatarSize,
            ),
            Flexible(
              child: _BylineText(
                byline: l10n.listByAuthor(_nameMarker),
                name: name,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [byline] with [_nameMarker] replaced by [name] styled as a link.
class _BylineText extends StatelessWidget {
  const _BylineText({required this.byline, required this.name});

  final String byline;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final markerAt = byline.indexOf(_nameMarker);
    final before = markerAt < 0 ? byline : byline.substring(0, markerAt);
    final after = markerAt < 0
        ? ''
        : byline.substring(markerAt + _nameMarker.length);
    return Text.rich(
      TextSpan(
        style: VineTheme.labelLargeFont(color: colors.secondaryText),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: name,
            style: VineTheme.labelLargeFont(color: colors.link).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: colors.link,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
