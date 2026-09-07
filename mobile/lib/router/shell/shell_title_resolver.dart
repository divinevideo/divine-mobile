// ABOUTME: Pure resolvers for the shell app bar's title and back button
// ABOUTME: Kept free of Riverpod so both are testable without pumping a shell

import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';
import 'package:openvine/utils/npub_hex.dart';

/// Title the shell app bar shows for [context].
///
/// [exploreTabName] and [profileDisplayName] are resolved by the caller,
/// because both come from providers and only one route type needs each.
/// Returns an empty string for routes that render their own header.
String resolveShellTitle({
  required AppLocalizations l10n,
  required RouteContext? context,
  String? exploreTabName,
  String? profileDisplayName,
}) {
  switch (context?.type) {
    case RouteType.home:
      return l10n.navHome;
    case RouteType.explore:
      // In feed mode the title names the tab the video came from.
      final tabName = exploreTabName;
      if (context?.videoIndex != null && tabName != null) {
        return labelForExploreTabName(l10n, tabName, shellTitle: true);
      }
      return l10n.navExplore;
    case RouteType.categoryGallery:
      return l10n.navExplore;
    case RouteType.notifications:
      return l10n.navNotifications;
    case RouteType.inbox:
      return l10n.navInbox;
    case RouteType.profile:
      if ((context?.npub ?? '') == 'me') return l10n.navMyProfile;
      // A display name that is itself an npub is the profile-not-loaded
      // placeholder, not a name worth putting in the app bar.
      if (profileDisplayName != null &&
          !profileDisplayName.startsWith('npub1')) {
        return profileDisplayName;
      }
      return l10n.navProfile;
    default:
      return '';
  }
}

/// The pubkey whose profile the app bar title should display, if any.
///
/// Null when [context] is not another user's profile, so the caller knows it
/// need not watch a profile provider at all.
String? shellTitleProfilePubkeyHex(RouteContext? context) {
  if (context?.type != RouteType.profile) return null;
  final npub = context?.npub ?? '';
  if (npub == 'me') return null;
  return npubToHexOrNull(npub);
}

/// Whether the shell app bar shows a back button for [context].
bool shellShowsBackButton({
  required RouteContext? context,
  required String? currentUserHex,
}) {
  if (context == null) return false;

  final isExploreVideo =
      context.type == RouteType.explore && context.videoIndex != null;
  // Notifications base state is index 0, not null.
  final isNotificationVideo =
      context.type == RouteType.notifications &&
      context.videoIndex != null &&
      context.videoIndex != 0;
  final isProfileWithShellAppBar =
      context.type == RouteType.profile &&
      !isOwnProfileGridRoute(context, currentUserHex);

  return isExploreVideo || isNotificationVideo || isProfileWithShellAppBar;
}

/// Whether the shell suppresses its own app bar for [context].
///
/// Home, the inbox, the explore grid and the viewer's own profile grid each
/// render a header of their own, so a second one would stack on top.
bool shellSuppressesAppBar({
  required RouteContext? context,
  required int currentIndex,
  required String? currentUserHex,
}) {
  if (currentIndex == 0) return true;

  if (context != null &&
      (context.type == RouteType.inbox ||
          context.type == RouteType.conversation)) {
    return true;
  }

  // Off an explore route the branch index is the only signal available.
  final isExploreGrid = context?.type == RouteType.explore
      ? context!.videoIndex == null
      : currentIndex == 1;
  if (isExploreGrid) return true;

  // Video mode uses the app bar even on the viewer's own profile.
  return isOwnProfileGridRoute(context, currentUserHex);
}
