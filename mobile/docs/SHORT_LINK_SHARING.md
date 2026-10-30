# External short-link sharing

Short-link sending is enabled by default in native builds: FeatureFlag.shortLinksSharing defaults true. Set compile-time FF_SHORT_LINKS_SHARING=false to retain full URLs. Web builds default off because the gateway does not currently allow the Flutter web deployment's origin; opt-in web builds must have gateway CORS support for their origin. Shortening works without login. Disabled clients retain full URLs without making creation requests. The gateway controls creation independently.

Only external video Copy/Share via and profile Share try shortening. Nostr events and DM messages retain the original canonical URL. Verified username subdomains keep their existing URL because they are outside the shortener destination grammar. First-party video IDs, full hex pubkeys and valid full npubs are preserved without truncation.

ShortLinkClient sends JSON to https://gateway.divine.video/api/links without an Authorization header. Transport and response reading share a two-second budget. Invalid mapping, quota, network, timeout and disabled responses fall back to the full URL. It refuses redirects, bounds responses to 4096 bytes and caches only exact validated successes, at most 100 per client. Provider disposal closes pending requests and clears cached mappings. No account state or signing service is needed.

Repeated Copy/Share via events are dropped while the same action is pending. Action results from a dismissed modal cannot pop the source page or trigger a late platform share. No new UI state or translations are introduced.

Receiving is already merged separately. These client defaults take effect in the next app build; Android association changes also require a native store release. Public links redirect to canonical web URLs for clients without short-link handling. Disabling creation/sending preserves existing public redirects.
