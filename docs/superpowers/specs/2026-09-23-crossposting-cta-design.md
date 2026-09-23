# Crossposting CTAs: surfacing the hidden distribution feature

Date: 2026-09-23
Status: design, pre-implementation
Decision owner: Rabble

## Context

Divine runs opt-in video crossposting: a creator connects an external platform
account, picks a posting mode, and the service publishes their Divine videos
there on their behalf. The service is live at `crossposter.divine.video`
(Cloudflare Worker, source repo `divine-connections`, deploying over the worker
still named `divine-crossposter`). Instagram and X report as enabled today;
TikTok and YouTube are staged behind `ENABLE_*` flags.

The mobile app already implements the whole flow natively:

- `mobile/lib/screens/settings/crossposting_settings_screen.dart` — connect and
  disconnect over in-app OAuth, per-platform mode Off / Manual / Automatic.
- `mobile/lib/services/crossposting_api_client.dart` — the API client.
- `mobile/lib/repositories/crossposting_repository.dart` — platform, connection,
  and preference aggregation.
- `mobile/lib/blocs/crossposting_settings/` — the settings cubit.
- `mobile/lib/widgets/crosspost_sheet.dart` + `mobile/lib/blocs/video_crosspost/`
  — per-video manual crosspost from the share sheet.
- 22-locale l10n for all of it.

The feature is shipped but effectively invisible. The service's own roadmap
(`divine-connections` `docs/crossposting-roadmap.md`) states the problem
directly:

> Crossposting is currently hidden and non-native in `divine-mobile`. It is
> fully built but not surfaced, and is not offered at the moment of publishing,
> which is where intent is highest. That is a `divine-mobile` task.

The same roadmap sets the strategic frame: crossposting to TikTok, Instagram,
and YouTube is a **creator-retention** feature — creators reaching an audience
they already have — and not an acquisition channel, because those platforms
suppress third-party watermarks and make outbound links inert. It explicitly
forbids adding watermarking. The app must not promise growth that the
distribution channel cannot deliver.

This design surfaces the feature with brand-aligned call-to-action copy, routes
the post-publish moment into the in-app share menu, and encourages automatic
mode in settings.

## Goals

- Make crossposting discoverable in settings with benefit-forward copy.
- Offer crossposting at the moment of publishing, where intent is highest.
- Encourage automatic mode, honestly framed as forward-looking only.
- Remove the web-setup hops that break the native flow.
- Never present a dead end: a user who cannot use in-app OAuth still gets a path.
- Do not corrupt the running post-publish View/Share experiment.

## Non-goals

- No watermarking. Ever. It gets content suppressed on the exact platforms it
  would be applied to.
- No new platforms. Adapters live server-side; new enabled platforms appear in
  the app automatically.
- No server-side fix for X OAuth. Tracked separately (see Risks).
- No growth/acquisition promises in copy.
- No redesign of the crossposting settings list beyond the added CTA.

## Product framing and copy

Copy follows `brand-guidelines/TONE_OF_VOICE.md` and
`brand-guidelines/AGENT_QUICK_REFERENCE.md`: candid, collective, a little punk,
active voice, benefits over features, no corporate speak. The value proposition
is twofold and must appear together: take your work out to the world, and carry
Divine with it.

Settings benefit card (zero connections):

- Headline: **Take your loops everywhere**
- Body: **Post once on Divine, share straight to Instagram. Your people are
  already out there — go meet them. Every loop you send carries a little link
  home, so the next creator finds us too.**
- Primary action: **Connect Instagram** (the first visible platform).

Settings automatic-mode encouragement (connected, manual or off):

- **Set it once.** **Every new loop you post goes out to Instagram for you — no
  extra taps.**
- Honest qualifier, always shown with it: **Only applies to loops you publish
  after you turn it on.**
- Action: **Turn on automatic.**

Share menu row (own videos, zero connections):

- Label: **Crosspost**
- Supporting line: **Send your loops to Instagram too.**

Post-publish: no new copy. The existing confirmation sheet's Share button opens
the in-app share menu, where the Crosspost row above already lives.

## Architecture

### One source of connection truth outside settings

Today two surfaces outside settings decide connection state independently: the
share menu via `VideoCrosspostCubit`, and the post-publish path with none. Add a
single cached provider for them:

- `crosspostingStatusProvider` — an `AsyncNotifier<List<CrosspostingPlatformSettings>>`
  over the existing `CrosspostingRepository`. The share menu CTA and the
  post-publish path read it.

The settings screen keeps its existing `CrosspostingSettingsCubit`, which
already holds the list it needs for the benefit and automatic-mode cards.
`CrosspostingSettingsCubit` and `VideoCrosspostCubit` remain the mutation
owners; the provider is read-only state. Actions still flow through the cubits
so operation serialization and error handling stay where they are.

### Platform availability in the app

The service reports X as enabled, but X connect has never worked end-to-end.
The app must not offer a broken flow. Introduce one shared predicate,
`crosspostingPlatformVisible(CrosspostingPlatform)`, that returns `false` for X,
and apply it in both `CrosspostingRepository.loadSettings` and
`VideoCrosspostCubit.loadConnections`. With X hidden, Instagram is the only
visible platform, which is why the copy above is Instagram-singular.

The X exclusion is transitional. It carries a comment referencing a tracking
issue for the server-side OAuth fix; when that issue closes, the predicate
returns `true` for X and the platform reappears everywhere at once. Open the
tracking issue as part of this work.

### Eligibility becomes tri-state

`crosspostingEligibleProvider` is a boolean gated on in-app OAuth support
(iOS 17.4+) and authentication. A boolean cannot express "can connect, but only
on the web." Replace it with a tri-state:

- `native` — authenticated and in-app OAuth is supported.
- `webOnly` — authenticated, but in-app OAuth is unsupported (iOS < 17.4, or the
  system version could not be determined). CTAs are shown and route to
  `crossposter.divine.video`.
- `unavailable` — not authenticated. CTAs are hidden; no dead end is shown.

The existing `appOAuthSupportProvider` and auth state remain the inputs.
Consumers are updated to the tri-state: the settings tile gate in
`general_settings_screen.dart:42` (shown for `native` and `webOnly`), the
settings screen's own guard in `crossposting_settings_screen.dart:37`, and the
share-menu dispatch.

## Surfaces

### Settings CTA

In `crossposting_settings_screen.dart`:

- When the loaded list has no connected platform, render a benefit card above
  the list (headline, body, primary connect action) using the copy above.
- When a platform is connected and its mode is not automatic, render the
  automatic-mode encouragement card with its honest qualifier and an action that
  sets that platform to automatic through the existing cubit.
- The platform list itself is unchanged.
- On `webOnly`, the connect and automatic actions open
  `crossposter.divine.video` instead of starting in-app OAuth.

### Share menu (per-video)

In `share_sheet_more_actions.dart`, the Crosspost row is currently rendered only
when `connectedCrosspostPlatforms` is non-empty (line 109). Change it to render
whenever `onCrosspost` is non-null, with the zero-connection label and
supporting line from the copy section. Behaviour by state:

- Connected — the existing `showCrosspostSheet` flow, unchanged.
- Zero connections, `native` — navigate to the native crossposting settings
  screen.
- `webOnly` — open the `crossposter.divine.video` setup page.

`_handleCrosspost` in `share_action_button.dart` drops its
`connections.isEmpty` early return and dispatches on the tri-state instead.

### Post-publish Share routes into the in-app share menu

Today the post-publish confirmation sheet's Share button opens the OS share
sheet (`upload_failure_listener.dart:286`), because the in-app menu needs a
hydrated `VideoEvent` and seconds after publish the event is often not
resolvable from Funnelcake or a relay. `PublishedEventLocalEcho` already closes
that gap by writing the signed event locally at publish time; the local read
path just has not been used for this.

New behaviour for `_onConfirmationShare`:

1. Resolve the published `VideoEvent` locally by `stableId` (the `d` tag) plus
   the current pubkey. Expose a public addressable lookup on
   `VideoEventService` (the private `_findCachedVideoByAddressable` already does
   the match).
2. Retry the local lookup for a short bounded window, since the echo write is
   best-effort and may still be in flight.
3. On success, present the in-app share menu with
   `ShareActionButton.showShareSheet`.
4. On failure within the bound, fall back to the current OS share sheet, so the
   button never dead-ends.

The confirmation sheet keeps its View and Share buttons; no third button is
added.

### Reconnect goes native

`crosspost_sheet.dart:421` opens the web setup page from the reconnect prompt.
Change it to navigate the native crossposting settings screen on `native`, and
keep the web page only for `webOnly`.

## Experiment integrity

`PostPublishExperiment` currently assigns control vs `viewShare` (a 50/50
sha256 bucket on pubkey) and only the treatment arm sees the confirmation sheet.
Routing Share into the in-app share menu changes what Share does for the
treatment arm, which is a material change to that arm's experience.

To avoid silently invalidating a running experiment:

- Do not fold crosspost into the experiment variant. Crosspost exposure and taps
  are logged as their own events, independent of the experiment.
- Confirm with whoever owns the post-publish experiment whether the Share
  behaviour change requires a variant bump or a new arm before shipping. If the
  experiment is still live and measured on share taps, treat this as a new arm
  rather than mutating `viewShare`.

This is the one open dependency that must be resolved before implementation.

## Analytics

New events, following the `AnalyticsEventSink` pattern already used by
`PostPublishExperiment`:

- `crosspost_cta_shown` with `surface` in `settings`, `share_sheet`.
- `crosspost_cta_tapped` with the same `surface` values.
- `crosspost_connect_started` and `crosspost_connect_result` with a
  `platform` parameter.

Never log a pubkey in shortened form; log whole values through the existing
helpers if identity is needed at all. Connection URLs, OAuth state, and tokens
never reach analytics or logs.

## Error handling

Reuse the existing `CrosspostingSettingsError` mapping and
`DivineSnackbarContainer` presentation. No new error surface is introduced. The
`webOnly` fallback is a routing decision, not an error state.

## Localization

Every new string is a new `app_en.arb` key read through `context.l10n` in the
same change, satisfying the orphaned-arb-key ratchet. Mirror each key into all
21 other `app_*.arb` locales, or add it to `_knownUntranslatedDebt` in
`test/l10n/arb_consistency_test.dart` when translation is deferred. Run
`flutter test test/l10n/arb_consistency_test.dart`.

## Testing

Unit:

- `crosspostingPlatformVisible` hides X.
- Tri-state eligibility: unauthenticated → `unavailable`; iOS below the floor →
  `webOnly`; supported → `native`.
- Repository and cubit both filter X out of their results.

Widget:

- Settings shows the benefit card at zero connections and hides it when
  connected.
- Settings shows the automatic-mode card when connected and not automatic, and
  the card's action calls `setMode(automatic)`.
- Share menu renders the Crosspost row with zero connections and routes to
  settings; with connections it opens the crosspost sheet.
- Post-publish Share resolves the local event and opens the in-app share menu;
  when resolution fails it falls back to the OS share sheet.
- Reconnect prompt navigates native rather than launching the web URL.

Then `flutter analyze`, the targeted suites above, and the guard scripts that
the touched trees trigger (l10n consistency, orphaned ARB keys, raw colors,
raw text styles, design-system ceilings).

## Risks and dependencies

- **X OAuth is broken server-side.** Hidden in the app until fixed; needs a
  tracking issue and a server/dev-portal fix outside this repo.
- **Post-publish experiment ownership.** The Share-behaviour change needs a
  decision from the experiment owner (see Experiment integrity).
- **Local echo race.** The bounded retry plus OS-share fallback contains it; the
  fallback is the same behaviour as today, so the worst case is no regression.
- **Only one platform visible.** With X hidden, the CTA is Instagram-only. If
  Instagram is disabled server-side, the benefit card must not render with no
  platform to connect; fall back to hiding the CTA rather than showing a dead
  button.

## Rollout

Ship behind the existing feature surfaces; no new flag is required because the
feature already ships. If a kill switch is wanted, gate the benefit card and the
share-menu row on a `FeatureFlag` entry, consistent with the Bluesky publishing
toggle in `general_settings_screen.dart`.
