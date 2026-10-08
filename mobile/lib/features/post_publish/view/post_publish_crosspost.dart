// ABOUTME: Wires the post-publish crossposting prompt to its cubit, and decides
// ABOUTME: whether the confirmation may look up crossposting state at all.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/post_publish/cubit/post_publish_crosspost_cubit.dart';
import 'package:openvine/features/post_publish/view/post_publish_crosspost_section.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

/// Whether the post-publish confirmation may load crossposting state for a
/// creator signed in through [source] with [availability].
///
/// Loading signs NIP-98 requests. The share menu defers that until a tap
/// because an external signer (Amber, a NIP-46 bunker, a browser extension)
/// can prompt for every signature, and a prompt nobody asked for is worse
/// than no suggestion. So only sources that sign silently qualify here.
bool shouldOfferPostPublishCrosspost({
  required CrosspostingAvailability availability,
  required AuthenticationSource source,
}) {
  if (availability == CrosspostingAvailability.unavailable) return false;
  return switch (source) {
    AuthenticationSource.divineOAuth ||
    AuthenticationSource.importedKeys ||
    AuthenticationSource.automatic => true,
    AuthenticationSource.none ||
    AuthenticationSource.bunker ||
    AuthenticationSource.amber ||
    AuthenticationSource.nip07 => false,
  };
}

/// The crossposting prompt for the post-publish confirmation sheet.
///
/// Builds its own [PostPublishCrosspostCubit] and loads once, keyed on the
/// repository so an account switch cannot leave it on the previous signer.
class PostPublishCrosspost extends ConsumerWidget {
  const PostPublishCrosspost({
    required this.onCrosspost,
    required this.onSetUp,
    required this.onReconnect,
    super.key,
  });

  final ValueChanged<List<CrosspostingConnection>> onCrosspost;
  final VoidCallback onSetUp;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(crosspostingAvailabilityProvider);
    final auth = ref.watch(authServiceProvider);
    if (!shouldOfferPostPublishCrosspost(
      availability: availability,
      source: auth.authenticationSource,
    )) {
      return const SizedBox.shrink();
    }
    final repository = ref.watch(crosspostingRepositoryProvider);
    final analytics = ref.watch(analyticsEventSinkProvider);
    return BlocProvider<PostPublishCrosspostCubit>(
      key: ValueKey((repository, analytics)),
      create: (_) {
        final cubit = PostPublishCrosspostCubit(
          repository: repository,
          analytics: analytics,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: PostPublishCrosspostSection(
        onCrosspost: onCrosspost,
        onSetUp: onSetUp,
        onReconnect: onReconnect,
      ),
    );
  }
}
