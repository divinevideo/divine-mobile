# Tag limit feedback in the tags picker

Issue: #11226. Size: small change.

## Intent

A video can carry at most 10 hashtags (#10053, deliberate, unchanged here).
When a video is already at 10, typing a new tag and pressing return clears the
field and adds nothing. The only cue is a muted line, "You can add up to 10
hashtags.", that has been on screen the whole time, so the creator cannot tell
why their tag vanished or what to do. This bites hardest when editing an older
post that already has 10 tags.

Goal: when the picker turns a tag away because of the limit, say so at that
moment, say how to make room, and keep what the creator typed.

Non-goals: changing the limit or how it is enforced; redesigning the sheet;
the publish path.

Anti-goals: a second feedback surface (snackbar, dialog, header counter) in a
sheet the design lead kept minimal; feedback that relies on colour alone;
green for a rejection.

## Approaches

- **A. Inline rejection notice in the existing hint line (chosen).** Extends
  the design lead's `TagsPickerNotice` / `_TagInputHint` from #10053, which
  already handles the sibling "too long" rejection in the same field. Warning
  colour follows the social sticker sheet's treatment of this same limit
  (#10540). Remedy wording follows the profile pin limit (#9251).
- **B. Error snackbar, like the profile pin limit.** Visible, but a different
  surface from the sibling "too long" case in the same field, and it competes
  with the open sheet and keyboard.
- **C. Prevent instead of reject** (disable the field at 10, or a "10/10"
  header count like the collaborator picker). Disabling forces removing a tag
  before typing the new one, which is backwards for the edit case; a count
  alone explains nothing.

Chosen: A, by Matt on 2026-11-18, with the design lead able to take it further
in review.

## Design

**Bloc** (`TagsPickerBloc`, `TagsPickerState`):
- Add `TagsPickerNotice.tagLimitReached`: a valid tag that is not already on
  the video was dropped because the video is at the limit.
- `_withAddedTags` sets it whenever such a token is dropped, for a single
  typed tag and for the overflow of a pasted list. A token that duplicates an
  existing or sticker tag is not a rejection and sets nothing. If one paste
  hits both "too long" and the limit, the limit notice wins, since it is the
  one that blocks the rest. (Claude's call.)
- Removing a tag resets `notice`, and the empty-query debounce keeps it
  (hm21's fix in #10053). Typing a non-empty query resets a too-long notice
  but keeps the limit notice while the video is still at the limit: the
  field keeps the turned-away text, so its own debounced query arrives after
  the rejection and would otherwise erase the warning. (Found while
  building; Claude's call.)

**Field** (`_addTag` in `video_metadata_tags_selector.dart`):
- If the video is already at the limit when the creator submits, keep the
  typed text in the field instead of clearing it, so it can be added once a
  tag is removed. Otherwise clear as today. The widget decides from
  `TagsPickerState.turnsAwayAtLimit(raw)` before dispatching, because the
  bloc answers asynchronously; that getter is the one rejection rule both
  layers share, so a tag the video already has is never treated as turned
  away. At the limit, a tag the video already has clears the field and
  leaves any notice alone. A pasted list that partly fits still clears; the notice
  explains the drop. At the limit, pressing return on an empty field does
  nothing. Typing a tag then a space (rather than return) at the limit still
  clears the text; the warning explains it. (Claude's calls.)

**Hint line** (`_TagInputHint`):
- `notice == tagLimitReached` → new string, `context.vineColors.accentWarning`.
- At the limit with no rejected attempt → existing string, muted, unchanged.
- The text itself changes between the two states, so the change is not
  colour-only and the existing `liveRegion` announces the first rejection.
- A repeat rejection leaves the text unchanged, so the field announces it
  explicitly with `announceDetached`, as the support form does for every
  rejected attempt. No double announcement on the first one.

**Copy**: new ARB key `videoMetadataTagsPickerTagLimitRemoveToAdd`:
"You can add up to {max} hashtags. Remove one to make room." (`one` form:
"…{max} hashtag. Remove it to make room."). `{max}` comes from
`HashtagExtractor.maxHashtagsPerVideo`. Checked against the brand tone guide
and the localization style guide, translated into every locale as #10053 did,
and flagged in the PR for fluent review.

**Social sticker sheet**: keeps the existing string. That sheet shows the
limit before any attempt and cannot remove tags itself, so "Remove one to make
room" would point at an action it does not offer. This departs from one line
of #11226; the PR says so. (Claude's call.)

## Tests

- Bloc: limit notice for a typed tag at 10; for paste overflow; none for a
  duplicate at 10; cleared by removing a tag; survives the empty-query
  debounce; limit wins over "too long" in one paste.
- Widget: at 10, submitting keeps the typed text and shows the new string;
  removing a tag clears it and the kept text can then be added; below the
  limit the field still clears.
- Each new test is checked to fail with its guard removed.

## Left to the builder

Exact widget structure, test file placement per repo rules, and translations.
