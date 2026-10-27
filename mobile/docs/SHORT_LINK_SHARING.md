# External short-link sharing

Short-link sending is an internal opt-in: FeatureFlag.shortLinksSharing defaults false, with compile-time FF_SHORT_LINKS_SHARING available for controlled builds. Signed-out users and disabled clients keep their existing full URLs without signing or creation requests. The authenticated gateway also defaults creation off independently.

Only external video Copy/Share via and profile Share try shortening. Nostr events and DM messages retain the original canonical URL. Verified username subdomains keep their existing URL because they are outside the shortener destination grammar. First-party video IDs, full hex pubkeys and valid full npubs are preserved without truncation.

ShortLinkClient signs the exact POST body for https://gateway.divine.video/api/links using the existing NIP-98 service. Signing plus transport and response reading share a two-second budget. Invalid mapping, quota, authentication, network, timeout and disabled responses fall back to the full URL. It refuses redirects, bounds responses to 4096 bytes and caches only exact validated successes, at most 100 per client. Auth/account changes dispose the client and its requests/cache through the existing provider lifecycle.

Repeated Copy/Share via events are dropped while the same action is pending. Action results from a dismissed modal cannot pop the source page or trigger a late platform share. No new UI state or translations are introduced.

Receiving is already merged separately. Android association changes require a native store release. iOS /l association expansion, older-installed-app behavior and physical iOS/Android checks remain release gates. Do not enable broad sending before daily backup automation, restore checks, monitoring and a limited internal canary pass. Disabling creation/sending must preserve existing public redirects.
