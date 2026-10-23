// ABOUTME: Storefront policy for creator monetization surfaces.
// ABOUTME: Keeps iOS App Store UI limited to optional creator tips.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';

@visibleForTesting
bool? debugUsesAppleAppStoreTipPolicyOverride;

bool get usesAppleAppStoreTipPolicy =>
    debugUsesAppleAppStoreTipPolicyOverride ??
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

List<MonetizationLinkProvider> monetizationProvidersForCurrentStorefront() {
  if (!usesAppleAppStoreTipPolicy) {
    return MonetizationLinkProvider.values;
  }

  return MonetizationLinkProvider.values
      .where((provider) => provider.category == MonetizationLinkCategory.tip)
      .toList(growable: false);
}

List<MonetizationLink> monetizationLinksForCurrentStorefront(
  Iterable<MonetizationLink> links,
) {
  if (!usesAppleAppStoreTipPolicy) {
    return links.toList(growable: false);
  }

  return links
      .where((link) => link.provider.category == MonetizationLinkCategory.tip)
      .toList(growable: false);
}
