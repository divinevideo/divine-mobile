// ABOUTME: The 40pt outlined avatar a people list uses for its members, in
// ABOUTME: the hero preview pile and in the roster rows.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Edge of a roster avatar, per the design's member rows and preview pile.
const kPeopleListMemberAvatarSize = 40.0;

const _cornerRadius = 16.0;

/// A member's avatar with the design's 1pt outline, so the piled avatars in
/// the hero preview read as separate tiles against each other.
class PeopleListMemberAvatar extends StatelessWidget {
  const PeopleListMemberAvatar({
    required this.pubkey,
    this.pictureUrl,
    super.key,
  });

  final String pubkey;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: UserAvatar(
        imageUrl: pictureUrl,
        placeholderSeed: pubkey,
        size: kPeopleListMemberAvatarSize,
        cornerRadius: _cornerRadius,
      ),
    );
  }
}
