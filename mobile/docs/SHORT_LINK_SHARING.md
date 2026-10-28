# External short-link sharing

Short-link sending is enabled by default: FeatureFlag.shortLinksSharing defaults true. Set compile-time FF_SHORT_LINKS_SHARING=false to retain full URLs. Signed-out users and disabled clients keep their existing full URLs without signing or creation requests. The authenticated gateway enables creation independently.

Only external video Copy/Share via and profile Share try shortening. Nostr events and DM messages retain the original canonical URL. Verified username subdomains keep their existing URL because they are outside the shortener destination grammar. First-party video IDs, full hex pubkeys and valid full npubs are preserved without truncation.

ShortLinkClient signs the exact POST body for https://gateway.divine.video/api/links using the existing NIP-98 service. Signing plus transport and response reading share a two-second budget. Invalid mapping, quota, authentication, network, timeout and disabled responses fall back to the full URL. It refuses redirects, bounds responses to 4096 bytes and caches only exact validated successes, at most 100 per client. Auth/account changes dispose the client and its requests/cache through the existing provider lifecycle.

Repeated Copy/Share via events are dropped while the same action is pending. Action results from a dismissed modal cannot pop the source page or trigger a late platform share. No new UI state or translations are introduced.

Receiving is already merged separately. These client defaults take effect in the next app build; Android association changes also require a native store release. Public links redirect to canonical web URLs for clients without short-link handling. Disabling creation/sending preserves existing public redirects.
