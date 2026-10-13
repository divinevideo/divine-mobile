// MPL-2.0
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/chat/chat_page.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

/// Chat routes bound to the active Divine session (no new login flow):
/// relay + signer come from the already signed-in identity.
List<RouteBase> chatRoutes(Ref ref) => [
  GoRoute(
    path: ChatScreen.path,
    name: 'chat',
    redirect: (_, _) => chatRedirectIfUnavailable(ref),
    builder: (ctx, st) => ChatPage(
      communityId: st.uri.queryParameters['community'],
      channelId: st.uri.queryParameters['channel'],
    ),
  ),
];

/// Sends `/chat` home unless [FeatureFlag.concordChat] is on and the account
/// may message.
///
/// The POC signs with the account's real key into a stream anyone can read,
/// so a build that has not opted in must not open it. Accounts under the
/// protected-minor messaging restriction stay out even with the flag on, the
/// same way the DM screens keep them out of group messages.
String? chatRedirectIfUnavailable(Ref ref) {
  final enabled = ref.read(isFeatureEnabledProvider(FeatureFlag.concordChat));
  if (enabled && !ref.read(isDmRestrictedProvider)) return null;
  return VideoFeedPage.pathForIndex(0);
}
