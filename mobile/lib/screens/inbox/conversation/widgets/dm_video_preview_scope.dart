// ABOUTME: Provides one video DM's kept preview frame to the bubble it builds,
// ABOUTME: or why it holds the preview back: requests, blocked and muted.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart'
    show FollowRelationship;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_preview/dm_video_preview_cubit.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/encrypted_video_card.dart'
    show DmVideoHold;

/// Builds a video DM's bubble with the frame this device keeps for it, or
/// with why its preview is held back.
///
/// The video downloads as soon as the bubble shows, and the card shows a
/// frame of it, when the message is the user's own, the user has posted in
/// the 1:1 chat, or the user follows the sender. Anyone else's card holds its
/// preview back: a request downloads nothing until the user plays it, and a
/// blocked or muted sender's card shows nothing of the video, not even a
/// frame read before. Either way a tap still plays it. A held card never
/// reads the kept file, so viewing it keeps nothing longer.
class DmVideoPreviewScope extends ConsumerWidget {
  /// Creates a [DmVideoPreviewScope] for [message].
  const DmVideoPreviewScope({
    required this.message,
    required this.accepted,
    required this.blocked,
    required this.muted,
    required this.builder,
    super.key,
  });

  /// The kind 15 video message.
  final DmMessage message;

  /// Whether the message is the user's own, or the user has posted in this
  /// 1:1 conversation.
  final bool accepted;

  /// Whether the user blocked the sender. Overrides [accepted] and following:
  /// a thread reached from the Blocked chip is still readable.
  final bool blocked;

  /// Whether the user muted the sender, without blocking them. Overrides
  /// [accepted] and following, as [blocked] does.
  final bool muted;

  /// Builds the bubble with the frame's path, null until there is one, and
  /// why its preview is held back, null when it is not.
  final Widget Function(
    BuildContext context,
    String? framePath,
    DmVideoHold? hold,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blocked) return builder(context, null, DmVideoHold.blocked);
    if (muted) return builder(context, null, DmVideoHold.muted);
    final store = ref.watch(dmVideoStoreProvider);
    // `value`, not `asData`: while the relationship reloads it keeps the
    // previous answer, so the preview is not torn down and started again.
    final relationship = ref
        .watch(followRelationshipProvider(message.senderPubkey))
        .value;
    final trusted =
        accepted ||
        relationship == FollowRelationship.youFollow ||
        relationship == FollowRelationship.mutual;
    if (!trusted) {
      // Until the relationship is known, neither download nor say why.
      return builder(
        context,
        null,
        relationship == null ? null : DmVideoHold.request,
      );
    }
    return BlocProvider(
      // A new account starts a fresh read.
      key: ValueKey((store, message.id)),
      create: (_) {
        final cubit = DmVideoPreviewCubit(
          message: message,
          store: store,
          download: true,
          decode: true,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocSelector<DmVideoPreviewCubit, DmVideoPreviewState, String?>(
        selector: (state) => state.framePath,
        builder: (context, framePath) => builder(context, framePath, null),
      ),
    );
  }
}
