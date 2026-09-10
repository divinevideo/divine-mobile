import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/profile_badge_explanation_sheet.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';

class UserName extends ConsumerWidget {
  const UserName._({
    super.key,
    this.pubkey,
    this.userProfile,
    this.embeddedName,
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    this.anonymousName,
    this.neverGenerateName = false,
    this.showProfileBadges = true,
  });

  /// Create a UserName widget from a pubkey.
  ///
  /// If [embeddedName] is provided (e.g., from REST API response with
  /// author_name), it will be used as a fallback when the profile isn't
  /// cached yet. This avoids unnecessary WebSocket profile fetches for
  /// videos that already have author data embedded.
  ///
  /// Set [neverGenerateName] on surfaces that show the signed-in user their
  /// own identity. A generated "Adjective Animal NN" handle is a plausible
  /// human name the user never chose, so showing it back to them reads as
  /// their account having been reset (#6423). Those surfaces render blank —
  /// normally under a `Skeletonizer` — until a real name resolves.
  factory UserName.fromPubKey(
    String pubkey, {
    String? embeddedName,
    Key? key,
    TextStyle? style,
    int? maxLines,
    bool? selectable,
    String? anonymousName,
    TextOverflow? overflow,
    bool neverGenerateName = false,
    bool showProfileBadges = true,
  }) => UserName._(
    pubkey: pubkey,
    embeddedName: embeddedName,
    key: key,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    selectable: selectable,
    anonymousName: anonymousName,
    neverGenerateName: neverGenerateName,
    showProfileBadges: showProfileBadges,
  );

  factory UserName.fromUserProfile(
    UserProfile userProfile, {
    Key? key,
    TextStyle? style,
    int? maxLines,
    bool? selectable,
    String? anonymousName,
    TextOverflow? overflow,
    bool neverGenerateName = false,
    bool showProfileBadges = true,
  }) => UserName._(
    userProfile: userProfile,
    key: key,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    selectable: selectable,
    anonymousName: anonymousName,
    neverGenerateName: neverGenerateName,
    showProfileBadges: showProfileBadges,
  );

  final String? pubkey;
  final UserProfile? userProfile;

  /// Optional embedded author name from REST API (e.g., video.authorName).
  /// Used as fallback when profile isn't cached, avoiding WebSocket fetches.
  final String? embeddedName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? selectable;
  final String? anonymousName;

  /// Suppresses the generated "Adjective Animal NN" fallback entirely.
  ///
  /// See [UserName.fromPubKey]'s doc for why. Applies to a resolved profile
  /// with an empty name as well as to the unresolved case.
  final bool neverGenerateName;

  /// Whether compact profile badges should render beside the display name.
  ///
  /// Profile headers pass false because they render full-size explanation
  /// controls beside the name instead of the tiny inline indicators.
  final bool showProfileBadges;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late String displayName;
    late String effectivePubkey;

    // When [neverGenerateName] is set, an empty placeholder replaces the
    // generated handle everywhere it would otherwise appear, so the caller
    // renders blank (typically under a Skeletonizer) instead of a name the
    // user never chose. It has to apply to a *resolved* profile too: a kind-0
    // with empty name and display_name still falls through to the generated
    // handle, and that is a state users reach — publishing from divine-web
    // with an empty name strips both fields.
    final placeholder = anonymousName ?? (neverGenerateName ? '' : null);

    if (userProfile case final userProfile?) {
      effectivePubkey = userProfile.pubkey;
      displayName = userProfile.betterDisplayName(placeholder);
    } else {
      final profileAsync = ref.watch(userProfileReactiveProvider(pubkey!));
      effectivePubkey = pubkey!;

      // Precedence mirrors UserProfile.betterDisplayName: a real name embedded
      // in a REST response beats a caller-supplied placeholder, which beats
      // the generated handle. Honouring the placeholder here is what makes
      // the header's displayNameHint reach the failure case at all (#6423).
      final fallbackName = embeddedName != null
          ? UserProfile.sanitizeDisplayName(embeddedName!)
          : placeholder ?? UserProfile.defaultDisplayNameFor(pubkey!);

      displayName = switch (profileAsync) {
        AsyncData(:final value) when value != null => value.betterDisplayName(
          placeholder,
        ),
        AsyncLoading() || AsyncData() => fallbackName,
        AsyncError() => fallbackName,
      };
    }

    // Note: Strikethrough for failed NIP-05 verification is now shown on the
    // NIP-05 identifier itself (in _UniqueIdentifier), not on the display name.
    // The display name is the user's chosen name and should not be crossed out.

    final textStyle =
        style ??
        TextStyle(
          color: context.vineColors.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        );
    final isOgViner =
        showProfileBadges &&
        ref.watch(
          ogVinerCacheServiceProvider.select(
            (service) => service.isOgViner(effectivePubkey),
          ),
        );
    final showCheckmark =
        showProfileBadges && shouldShowSpecialProfileCheckmark(effectivePubkey);
    // The beta chit yields to both the checkmark and the OG Viner chit, so a
    // name never carries two of them. The Viner rosters are disjoint by
    // construction; many team accounts also appear on the beta roster, so the
    // checkmark still has to be checked here.
    final isOgBetaTester =
        showProfileBadges &&
        !isOgViner &&
        !showCheckmark &&
        isOgBetaTesterPubkey(effectivePubkey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Flexible(
          child: selectable ?? false
              ? SelectableText(
                  displayName,
                  style: textStyle,
                  maxLines: maxLines ?? 1,
                )
              : DivineHeartText(
                  displayName,
                  style: textStyle,
                  maxLines: maxLines ?? 1,
                  overflow: overflow ?? TextOverflow.ellipsis,
                ),
        ),
        if (showCheckmark) const SpecialProfileCheckmark(),
        if (isOgViner) const OgVinerBadge(),
        if (isOgBetaTester)
          OgBetaBadge(
            onTap: () => showProfileBadgeExplanationSheet(
              context,
              ProfileBadgeExplanationType.ogBetaTester,
            ),
          ),
      ],
    );
  }
}
