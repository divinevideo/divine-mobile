# Social sound discovery and reuse

Date: 2026-09-21
Status: Product framework agreed in conversation; implementation proposal for review.

## Product outcome

Make the path from hearing a sound to collecting it and making a video short,
recognizable, and reliable. Preserve the existing rich saved-sound card design.

The two destinations have different jobs:

- Discover gains Sounds as its rightmost tab. In code this is the Explore screen.
- My Library → Sounds remains the user's collection and gains a permanent Add sound
  action, available in both empty and populated states.

The same browser and sound identity must work in discovery, the camera, the editor,
and publishing. Public sound title and creator credit are the primary labeling
problem. Private organization is useful but does not substitute for correct credit.

## Agreed behavior

### Discover → Sounds

Search at the top; Trending, Following, Vine classics, and Recent filters.
Provide shortcuts to Saved sounds and Add sound without turning Discover into a
second library.

Cards retain the current thumbnail/typography treatment. Show a recognizable sound
title, original creator credit, preview, Save, and Use sound. Provide example videos
on the sound page, with a small example affordance on the card. Pause the existing
feed before audio preview; only one preview or video may play at a time.

Following means sounds used in public videos by people the viewer follows, including
reused sounds. It does not mean sounds authored by those people, private saves, or
mutual follows. Signed-out users get an explanatory sign-in state. An empty followed
set gets a discovery shortcut, not silently substituted global results.

Trending means recent adoption, not new upload time or lifetime popularity. Display
a time window only when its measurements exist. The initial target is This week:
distinct creators using each sound in the last seven days, with recent use and growth
as supporting signals. See the plan's server contract gate before promising this
label. Missing metrics remain unknown; never display an invented zero or percentage.

Search covers public title, credited creator, public tags, and indexed public
description. Searching Saved also covers private nicknames, collections, and retained
source context. Do not send private library metadata to public discovery services.
Do not promise lyric/transcript search until an indexed source supports it.

### My Library → Sounds

Permanent Add sound and Find sounds actions above the saved cards.

Add sound opens file import directly. A user can import, preview, optionally give the
entry a private name, assign a collection, and save without starting a video.
Keep the full audio file. Trimming selects a segment when making a video, never when
merely adding it to the library.

Save copies into existing library-owned persistent storage, then persists the saved
record, and only then reports success. Cancel/error must not leave an unexplained
saved record or abandoned temporary copy. Account switches must not write into the
new account. A saved file must survive draft deletion and application restart.

Preserve encrypted creator-sync behavior already present. Do not promise that an
imported file's bytes sync merely because its metadata does. Distinguish a private
library item from a publicly reusable sound and label unavailable local media clearly.

Saved-card actions: Preview, Use sound, More. More contains edit private details,
organize collections, and remove. Remove retains its existing cross-device semantics;
do not turn it into a supposedly local undo without verifying sync/tombstone behavior.

Saving a discoverable reusable sound is one action. Optional organization follows
the durable save and never blocks it. A sound can belong to several named collections.
Collections are private, accept ordinary multiword names, and coexist with existing
private hashtags; do not destructively reinterpret old tags.

### Public identity and credit

Primary public display: sound title, then By credited creator. Source-video title,
caption, and author are visibly source context, not substitutes for audio authorship.
Put Shared by, source, and license information in sound details where applicable.

Keep stable source identity through saves, timeline instance IDs, drafts, and
publication. Reusing a sound keeps its original reference and does not republish it
under the reuser. Multiple videos using the same source lead to the same sound page.

For new original audio, offer Let others use this sound with affirmative opt-in.
When enabled, show an optional Name your sound field and an automatically populated
creator credit preview. A missing name displays Original sound with the creator
separately. Do not require naming to publish otherwise valid own audio.
Honor existing explicit user preferences; do not reset them as part of this work.

Imported audio requires its own public attribution/ownership flow when sharing.
A private filename or nickname is never automatically a public attribution claim.
Bundled and catalog audio retain supplied artist/source/license metadata and must
not be assumed to have been made by the person posting the video.

If a sound cannot be resolved, show unavailable/unknown credit without guessing
from a general inspired-by relation or crediting the current video author.

### Reuse eligibility

- Verified archived Vine audio is eligible under the approved archive policy,
  with authoritative creator opt-outs/takedowns and server rollout respected.
- New Divine audio requires explicit creator opt-in.
- Saving/importing privately grants no public remix permission.
- Credit stays visible when reuse is unavailable.
- A policy-loading/network failure is distinct from a creator declining reuse.
- Recheck permission at use and publish time. A saved historical grant is not a
  permanent authorization.
- Preserve the existing owner exception.

Archive status must come from the authoritative policy response. A title, old date,
client-supplied tag, or the mere presence of a Vine-shaped identifier is insufficient.
Do not create a separate mobile policy that contradicts the existing backend contract.

### Camera, editor, and publishing

Use sound from discovery or a saved card opens creation with that sound selected,
while leaving existing drafts intact. Do not automatically force lip-sync mode;
recording and choosing an existing clip remain available. From an active draft, the
picker returns a choice to that draft rather than opening a new recorder.

The shared browser offers Saved alongside discovery. Selecting a sound does not
implicitly save it; Save and Use sound remain separate actions.

On the publishing screen, provide a Sound row showing the current selection or
Add sound. Return to the same draft and metadata after selecting. Audio changes
invalidate and rerender the published output through the existing editor pipeline;
they cannot merely update attribution while uploading the old render.
Allow preview against the video, segment adjustment, volume control, and removal.

If no added sound exists, offer a dismissible Try a sound prompt. Use a stronger
prompt for known-muted/no-audio videos. Speech detection is an enhancement only if a
reliable existing signal is available; missing captions are not evidence of silence.
Never add music automatically, block publishing for skipping, or erase ambient audio.
Remember dismissal in the draft across navigation and reopen.

### Sounds from elsewhere

File import covers audio users have exported from other apps. Support existing Divine
sound links through existing routing. Add catalog links only through a provider
resolver with a verified contract, retained credit, and a supported media result.
Do not ship an unrestricted URL downloader or claim automatic access to another
app's saved collection. Native share-extension/account-library integrations are a
separate scoped feature after target apps and their capabilities are established.

## Architecture boundaries

Use UI → BLoC/Cubit → Repository → Client. New feature state uses BLoC/Cubit;
existing Riverpod remains a composition/compatibility bridge.

- Existing sounds_repository owns sound discovery aggregation and domain models.
- Existing funnelcake_api_client owns direct Funnelcake HTTP contracts.
- Existing SoundLibraryApiClient owns provider catalog HTTP normalization.
- Existing VideosRepository owns following/classic video retrieval and content
  filtering; inject Flutter-free ports into sounds_repository to avoid dependency cycles.
- Existing SavedSoundsBloc/Service own private library persistence and creator sync.
- An app coordinator owns navigation and draft attachment, not the repository.
- Share public credit formatting and source identity across every surface.
- Use one reusable browser View with browse and select-for-draft host modes.

Do not introduce a new service or sound event kind. Do not put Flutter widget types
in a repository. Preserve source/license data through every adapter.

## Evidence and dependencies

Mobile baseline: 3c1056651a56ee9a836cd76cbd65c2c1610bd801, fetched 2026-09-21.

Observed in current mobile code:
- SoundDetailScreen._onUseSound saves instead of entering creation.
- The picker maps SavedSound to AudioEvent and loses private search/display context.
- The library Add audio launcher is debug-only and routes through the trimming picker.
- ExploreTabsState derives tab order by stable names; Sounds must append after all
  optional tabs, not rely on a fixed numeric index.
- Existing audio sharing forms and fallbacks can confuse the sound creator with
  publisher/source-video credit; reproduce specific branches before patching.
- Imported audio already uses library-owned storage.
- Saved-sound metadata already participates in creator sync.

Existing service contracts, inspected locally:
- Funnelcake GET /api/sounds with trending/recent/popular/uses sorting.
- Funnelcake GET /api/search?type=sound&q=... and per-sound stats.
- Sound proxy GET /api/sounds/trending and /api/sounds/:id/videos.
- Sound proxy provider search and resolution APIs.
- Funnelcake POST /api/videos/audio-reuse/bulk for fresh authoritative permissions.

Read-only live probes of https://api.divine.video on 2026-09-21 returned HTTP 200
and arrays for trending/recent with limit=1. Returned field names included id,
pubkey, title, audio_url, author_name, source, usage_count; trending added
trending_score. This verifies reachability and shape, not ranking accuracy,
provenance completeness, permission, coverage, or production rollout.

The local sound proxy sorts a candidate page by current total reuse count; this
is not weekly adoption and is not proof of globally ordered pagination. Its video
lookup already understands both video kinds 34235 and 34236.

Archive compatibility already has draft PR
https://github.com/divinevideo/divine-mobile/pull/8467
(open and draft when checked 2026-09-21). Treat as a coordination dependency,
not authorization to modify or take over that branch. Read the current contract
and integrate after it lands rather than inventing a parallel implementation.
Brain search document 451C238E0922CB0607814751A4 identified this prior art; current
GitHub metadata, not that historical result, established its draft/open state.

Service source references:
- divine-funnelcake/crates/api/src/sound_handlers.rs
- divine-funnelcake/docs/audio-reuse-policy.md
- divine-funnelcake/docs/LLM_API_GUIDE.md (Sounds)
- divine-sound-proxy/src/index.mjs
- divine-sound-proxy/README.md

The shared divine-context checkout was on a working branch and was not updated.
Sibling service checkouts were read-only; local source is not proof of deployment.

## Completion criteria

1. Discover's rightmost Sounds tab can find a sound absent from Saved.
2. Following includes a friend's reuse of another creator's sound.
3. Trending ordering/count labels match the defined time window.
4. One Save action persists the sound without a mandatory naming step.
5. Import works from an empty library without camera/editor navigation or trimming.
6. Use sound enters creation or updates the current draft, according to context.
7. Public title and original creator remain consistent through reuse and publishing.
8. Opted-out new sounds cannot be reused; eligible verified archive sounds can.
9. A publish-time audio change is audible in the final rendered video.
10. Private collections/nicknames stay private and are searchable in the picker.
11. Light/dark, screen reader, large text, offline/retry, and account-switch behavior
    are verified in the touched surfaces.

