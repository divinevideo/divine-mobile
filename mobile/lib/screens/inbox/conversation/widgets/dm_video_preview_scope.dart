// ABOUTME: Provides one video DM's kept preview frame to the bubble it builds;
// ABOUTME: a stranger's video downloads only once the user plays it.

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

/// Builds a video DM's bubble with the frame this device keeps for it.
///
/// The video downloads as soon as the bubble shows when the conversation is
/// [accepted] or the user follows the sender, unless the sender is [blocked].
/// Otherwise nothing downloads until the user plays it: a stranger or a
/// blocked sender cannot make the device fetch and decode a file, or learn
/// from their host when the thread was opened.
class DmVideoPreviewScope extends ConsumerWidget {
  /// Creates a [DmVideoPreviewScope] for [message].
  const DmVideoPreviewScope({
    required this.message,
    required this.accepted,
    required this.blocked,
    required this.builder,
    super.key,
  });

  /// The kind 15 video message.
  final DmMessage message;

  /// Whether the message is the user's own or the user has posted in this
  /// conversation.
  final bool accepted;

  /// Whether the user blocked or muted the sender. Overrides [accepted] and
  /// following: a thread reached from the Blocked chip is still readable.
  final bool blocked;

  /// Builds the bubble with the frame's path, null until there is one.
  final Widget Function(BuildContext context, String? framePath) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(dmVideoStoreProvider);
    final relationship = ref
        .watch(followRelationshipProvider(message.senderPubkey))
        .asData
        ?.value;
    final download =
        !blocked &&
        (accepted ||
            relationship == FollowRelationship.youFollow ||
            relationship == FollowRelationship.mutual);
    return BlocProvider(
      // A new account or a newly followed sender starts a fresh read.
      key: ValueKey((store, message.id, download)),
      create: (_) {
        final cubit = DmVideoPreviewCubit(
          message: message,
          store: store,
          download: download,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocSelector<DmVideoPreviewCubit, DmVideoPreviewState, String?>(
        selector: (state) => state.framePath,
        builder: builder,
      ),
    );
  }
}
