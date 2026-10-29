import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:openvine/features/challenges/challenge_link.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:uuid/uuid.dart';

class ChallengePage extends ConsumerWidget {
  const ChallengePage({required this.link, super.key});
  final ChallengeLink link;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(challengeAppSessionProvider);
    return session.when(
      loading: () => const Scaffold(
        body: Center(child: DivineCircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: DiVineAppBar(
          title: context.l10n.challengeTitle,
          showBackButton: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.challengeUnavailable),
              DivineButton(
                type: DivineButtonType.quiet,
                onPressed: () => ref.invalidate(challengeAppSessionProvider),
                label: context.l10n.commonRetry,
              ),
            ],
          ),
        ),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: DiVineAppBar(
              title: context.l10n.challengeTitle,
              showBackButton: true,
            ),
            body: Center(child: Text(context.l10n.challengeSignIn)),
          );
        }
        final videos = ref.watch(videosRepositoryProvider);
        return BlocProvider(
          key: ValueKey((session, link.naddr)),
          create: (_) {
            session.useLinkHints(link.coordinate, link.relays);
            final cubit = ChallengeParticipationCubit(
              coordinate: link.coordinate,
              submissions: session.submissions,
              refresh: () => session.refreshForDisplay(link.coordinate),
              loadCandidates: () async {
                await session.store.checkLive();
                final feed = await videos.getAuthorFeed(
                  authorPubkey: session.store.owner,
                  skipCache: true,
                );
                await session.store.checkLive();
                return feed.videos
                    .where((v) => v.pubkey == session.store.owner)
                    .toList();
              },
              exactVideo: session.adapter.exactEvent,
              clientTags: () async => await Nip89ClientTag.wantsClientTag(1111)
                  ? [Nip89ClientTag.tag]
                  : [],
              prepareRecording: (definition) async {
                final id = const Uuid().v4();
                await session.prepareRecording(
                  recordingId: id,
                  definition: definition,
                );
                return id;
              },
              handoffs: () => session.publishedHandoffs(link.coordinate),
              reviewPublished: session.reviewPublished,
            );
            unawaited(cubit.load());
            return cubit;
          },
          child: Consumer(
            builder: (context, ref, _) {
              final organizer = context.select(
                (ChallengeParticipationCubit cubit) =>
                    cubit.state.read?.view.definition?.event.pubkey,
              );
              final organizerProfile = organizer == null
                  ? null
                  : ref.watch(userProfileReactiveProvider(organizer)).value;
              return ChallengeView(
                loadCandidatePreview: (id) async {
                  final video = await session.adapter.exactEvent(id);
                  if (video == null ||
                      video.id != id ||
                      video.pubkey != session.store.owner) {
                    return null;
                  }
                  await session.refreshVideo?.call(video);
                  await session.store.checkLive();
                  return session.reads.isVisible(video) ? video : null;
                },
                organizerName: organizerProfile?.bestDisplayName,
                organizerAvatarUrl: organizerProfile?.picture,
                onOrganizerTap: organizer == null
                    ? null
                    : () {
                        unawaited(
                          OtherProfileRouteData(
                            npub: NostrKeyUtils.encodePubKey(organizer),
                          ).push<void>(context),
                        );
                      },
                ownerName: ref
                    .watch(userProfileReactiveProvider(session.store.owner))
                    .value
                    ?.bestDisplayName,
                onRecord: (context, id) async {
                  await context.push<void>(
                    Uri(
                      path: VideoRecorderScreen.path,
                      queryParameters: {'challenge_recording': id},
                    ).toString(),
                  );
                  if (context.mounted) {
                    await context.read<ChallengeParticipationCubit>().load();
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
