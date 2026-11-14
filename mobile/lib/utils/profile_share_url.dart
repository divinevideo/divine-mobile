// ABOUTME: Resolves the link a profile's Share button sends, shared by the
// ABOUTME: own-profile and other-profile screens so both apply one rule.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_link/profile_link_cubit.dart';
import 'package:openvine/providers/short_link_provider.dart';
import 'package:openvine/utils/profile_link_resolver.dart';

/// The URL a profile is shared under.
///
/// A Divine username becomes its subdomain URL only once that exact claim
/// verifies. Anything else, including an external NIP-05, falls back to the
/// npub profile URL. Missing metadata uses the public ownership lookup.
Future<String> resolveProfileShareUrl(
  WidgetRef ref, {
  required String pubkey,
  required UserProfile? profile,
  ProfileLinkCubit? linkCubit,
}) async {
  final shortener = ref.read(shortLinkClientProvider);
  final link = linkCubit == null
      ? await profileLinkResolverFor(ref)
            .resolve(pubkey: pubkey, profile: profile)
      : await (linkCubit.state.resolution ??
            Future.value(linkCubit.state.link));
  return shortener?.shorten(link.url) ?? link.url;
}
