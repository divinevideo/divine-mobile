# Community badge discovery

## Purpose and agreed direction

Badges help people discover a community, see its people and videos, and follow people they connect with. The user explicitly selected the newer Lists gallery as the visual reference. Community-issued badges must be discoverable alongside official awards. Anyone can browse a community; holding its badge is not required to browse, follow an individual, or use the existing community subscription.

This design updates Explore → Badges and its handoff to the existing badge detail page. It does not change who can issue a badge, how awards are accepted, or NIP-58 membership proof.

## Current evidence

- ExploreBadgesCubit restricts discovery to one official issuer. The view renders compact 56px-art rows.
- A bounded public read of kind 30009 from the app's primary relay returned 203 distinct badge coordinates across 140 issuers, including 200 non-official definitions. This is discovery evidence, not a complete network census. No real account identifiers or badge names from that read are retained here.
- The live HTTP catalogue requires an issuer and currently returns three official award definitions. It cannot provide open community discovery simply by omitting that parameter.
- Lists already discovers public Nostr content from relays and presents media-led cards in two columns. Its current code and the existing Figma list reference supply the spacing, surfaces and typography.
- Badge detail already shows accepted members, member videos, individual Follow controls and a separate public badge subscription.

## Approaches

1. **Public-relay community gallery — recommended.** Use the same discovery pattern as Lists, retain official and community issuers equally, and open the existing member/video/follow flows. This provides useful discovery with the existing backend and protocol.
2. **Expand the central catalogue first.** A global HTTP directory could offer server-side search/ranking, but the current issuer-scoped endpoint cannot supply it. This adds backend/query/rollout work without being necessary for the requested gallery.
3. **Restyle the official-only directory.** Rejected: improving its artwork would still hide community-created badges and miss the product goal.

The user has approved the community-discovery direction and Lists inspiration. The concrete design below is proposed for review before product implementation.

## Experience

### Explore → Badges

- Keep the existing Badges tab and route.
- Lead with “Find your people” and short explanatory copy: “Find communities through the badges people share.” Localize all new copy.
- Make “Create a badge” and “My badges” accessible using the existing native editor and dashboard. Signed-out creation uses the existing sign-in handling; discovery remains public.
- Render a lazy two-column gallery with the Lists visual rhythm: 16dp outer gutters and column gap, 16dp media corners, 177:120 media ratio, and the existing title/description typography. Use one column where large text or available width makes two unreadable.
- Give each badge a large artwork area, its name, a short description, its issuer’s display identity and a small accepted-member preview when available. The card must open the full issuer-scoped coordinate even when another issuer uses the same name or d-tag. Badge artwork remains the issuer's published artwork; missing/broken artwork gets a deliberate monogram treatment, not the AI sparkle.
- People previews are supporting content. They cannot delay or suppress a badge card. Do not display invented popularity, member totals or activity claims. A preview is not a complete count.
- Tapping any card opens the existing badge detail page with its artwork, community description, people, their videos and Follow controls. Keep individual follows separate from the existing community subscription.
- Refresh retains useful cards on failure and presents a localized retry/error state. Loading skeletons match final card geometry. A failed or unanswered discovery read must not masquerade as an authoritative empty catalogue.

### People and following

- Make the existing member section prominent in the detail journey. Present accepted badge holders in human-facing copy as people in the community while preserving the exact accepted-award proof underneath.
- Keep the existing individual Follow/Following controls and video navigation. The separate subscription action is labeled “Follow community” in the proposed layout; its helper text explains that it adds community videos to Following and its public-list notice remains visible.
- Keep the existing community subscription separate, including the notice that the subscription list is public. Subscribing never silently bulk-follows accounts and never confers badge membership.
- Keep existing edit/award/revoke/delete ownership controls. Do not introduce self-join, invitations or new membership protocol.

## Discovery and architecture

- Add a public discovery read to the owning badge_repository package. Remove Explore's exclusive dependency on the official issuer allowlist. Preserve the existing issuer-specific catalogue API for callers that genuinely need it.
- Use existing Nostr kind 30009 definitions and the app's configured relay client, including its anonymous primary-relay read capability. No new backend endpoint, deployment, protocol kind, or new package is required.
- Start with a bounded recent window of 300 definition events. Deduplicate by full issuer+d-tag coordinate, select the newest valid definition with deterministic ties, and order cards by definition recency. This is a discovery window, not a promise to enumerate the entire network.
- Reveal 24 cards initially and another 24 through “Show more” until the loaded window is exhausted. Build card contents lazily. Do not add a search field that only pretends to search beyond the loaded window; global directory search is outside this change.
- Reuse current event verification and deletion rules. Reject malformed/unsigned/spoofed definitions; honor issuer-signed deletions; never merge identical d-tags from different issuers. Full IDs stay intact in protocol data and logs.
- Respect blocked, muted and vanished issuers and people before exposing their cards or previews, using the existing policy boundaries. Refresh policy-dependent state after an account or block-list change. User-created badges never acquire an official endorsement merely by appearing.
- The repository owns relay/API composition, filtering, sorting, deduplication and preview sourcing. Cubits own UI state and superseded-load/disposal behavior. Widgets only render and dispatch actions.
- Reuse the existing indexed accepted-holder preview for visible cards, filtered through the same viewer policy as detail. At most three faces per card, at most four in-flight preview reads, and at most one read per coordinate per discovery generation. No per-card complete relay holder walk on the gallery. Preview errors leave artwork/title/description usable.
- A preview never proves complete membership. The existing detail page reconciles with relays before treating its member set as final.
- Reuse shared image eligibility rules and current avatar/image components; never request invalid, insecure or known-dead image origins. Keep reduced-motion support and bounded image decoding.

## Visual and accessibility constraints

Use VineTheme and adaptive context.vineColors tokens in both appearances. Keep Bricolage Grotesque and Inter, Phosphor/Divine icons, and shared buttons. No gradients, fabricated communities, invented statistics, real-user fixtures or AI-generated community artwork.

Each community card is one named accessible navigation target. Member follow controls remain separately named and sized for touch. Check large text, narrow screens, light/dark appearances, missing artwork, long names and descriptions, refresh failure, and signed-out access.

The accompanying SVG is a layout sketch with synthetic communities and placeholder people, not an app screenshot or a proposal to publish seeded content.

## Acceptance evidence

1. A signed definition from a non-official issuer appears; two issuers sharing a d-tag stay distinct; official definitions still appear.
2. Newer revisions, valid deletions, malformed signatures and blocked/muted/vanished accounts follow current repository rules. A missing relay answer is not shown as a proven empty directory.
3. Public discovery works signed out and does not depend on the issuer-only HTTP catalogue.
4. Cards remain useful when holder previews fail, do not invent counts, and preview requests obey visibility, concurrency and deduplication bounds.
5. A card opens the right issuer-scoped detail; individual Follow affects only the selected person; the existing community subscription remains distinct and publicly disclosed.
6. Refresh, account/policy changes, superseded requests and close/disposal cannot append stale or hidden results.
7. Gallery/detail widget tests cover both appearances, large text, loading/error/empty states and accessible actions. Use synthetic content for real-app visual checks when available.
8. Run affected package/app tests, required localization checks, full analysis and relevant guards; obtain fresh whole-diff independent review; publish a focused PR targeting main and inspect finished CI. Merge or deployment requires authorization for this new PR; the earlier 15-PR merge authorization does not extend to it.

## Scope boundaries

No backend or infrastructure change; no global search/ranking service; no new social protocol, automatic bulk-follow, badge entitlement change or official badge-art republishing. No release, deployment, LiveKit or livestream work. The separate one-item symptom is not claimed reproduced on a device; broader public discovery must have regression coverage against silently reducing the catalogue to one badge.

## Design readiness

A fresh read-only builder check found no important unanswered questions before implementation planning. The relay-discovery approach, finite browsing window, member-proof boundary and separate follow actions are explicit. Product implementation awaits review of this concrete design and layout sketch.
