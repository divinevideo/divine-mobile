---
name: pr-screenshots
description: |
  Use when a divine-mobile pull request changes something a user can see and
  its description needs screenshots of the real app; when a maintainer or
  reviewer asks for screenshots, visual evidence, or "show me it working";
  or when you are tempted to substitute widget-test renders or to ask a
  human to set up accounts or attach images. Covers iOS simulator + LOCAL
  Docker stack + Maestro/idb + secret-gist hosting.
author: Claude Code
version: 1.0.0
---

# Real-app screenshots for a PR

**Core principle:** you can produce real-app screenshots end to end yourself.
Run this branch on an iOS simulator against the repo's local Docker stack,
with throwaway accounts that exist only there. Drive the app with Maestro and
`idb`, capture with `simctl`, and host the images in a secret gist. The app
talks only to the local relay. A LOCAL build still reaches a few production HTTPS services (the identity verifier, supporter
status, share short links, crossposting), so avoid driving those flows unless
the PR needs them. Apart from the trust check in step 0, ask the maintainer
nothing for this.

`<skill-dir>` below is the directory containing this file. Each run keeps its
scratch files (logs, keys, flows, screenshots) in a folder of its own, so
parallel sessions and earlier runs never mix screenshots or keys. Create it once
with `mktemp -d "${TMPDIR:-/tmp}/pr-screenshots-<n>.XXXXXX"`, then start every
shell call with `export SCRATCH=<the path it printed>`; the scripts refuse to run
without it. Agent shells often have no `$TMPDIR`, and a bare `$TMPDIR/...` then
expands to a read-only `/...`.

Budget: about 5 minutes for the first build, about 1 minute to sign in, and about
4 minutes to navigate and capture. A `maestro hierarchy` call takes 30–60s, so use the
navigation map below before dumping.

## Quick reference

| Need | Do |
|---|---|
| App + backend running | `bash <skill-dir>/scripts/sim_up.sh <worktree-root> [device type]` → prints `UDID=`, `BUNDLE_ID=` and `STACK_STARTED=`. It creates (or reuses) a simulator named `pr-screenshots-<worktree>`, an iPhone 16 Pro unless you pass another type from `xcrun simctl list devicetypes` |
| Signed-in user | `maestro --device <UDID> test -e APP_ID=<BUNDLE_ID> <skill-dir>/scripts/new_device_account.yaml` |
| Someone to view or message | `bash <skill-dir>/scripts/make_account.sh "Sam Tester"` → npub |
| Open a profile | Maestro `openLink: divine:///profile/<npub>` (three slashes), then `tapOn: {text: Open, optional: true}` |
| See what's tappable | `maestro --device <UDID> hierarchy` and grep `accessibilityText` or `resource-id`. A row with a subtitle is labelled `"Title\nSubtitle"`, so `tapOn: "Title"` fails; tap the full label or an id |
| Tap inside the system photo picker | `idb ui tap --udid <UDID> <x> <y>` in **points** (pixels ÷ the screen scale: 3 on an iPhone Pro) |
| Add a video to Photos | `ffmpeg -f lavfi -i testsrc2=size=720x1280:rate=30:duration=6 -f lavfi -i sine=duration=6 -c:v libx264 -pix_fmt yuv420p -b:v 12M -c:a aac -shortest "$SCRATCH/clip.mp4"` then `xcrun simctl addmedia <UDID> "$SCRATCH/clip.mp4"` |
| Dark / light | The app defaults to **Dark**, not System, so simulator appearance alone changes nothing. Switch in the app (see the navigation map), and also run `xcrun simctl ui <UDID> appearance light` so system sheets match |
| Freeze an upload mid-way | `docker compose -f local_stack/docker-compose.yml pause blossom-proxy` before the send; `… unpause blossom-proxy` straight after the shot. The stack is shared, so this freezes uploads for every session on it |
| Capture | First wait for an element that loads **last**: "No videos yet" renders before the profile header, so wait for the header too. Then `xcrun simctl io <UDID> screenshot "$SCRATCH/NN-state.png"` and **Read the PNG** to check it shows what you claim |
| Publish | `bash <skill-dir>/scripts/publish_gist.sh "PR <n> screenshots at <sha>" "$SCRATCH/01-profile-dark.png" "$SCRATCH/02-profile-light.png"`, naming each file you checked rather than a glob that also catches retakes → `<img>` tags with verified raw URLs |
| Put in PR | Reviewers edit descriptions, so build the new body from the live one, read right before you save: `gh pr view <n> --json body -q .body > "$SCRATCH/body.md" && test -s "$SCRATCH/body.md"`, append a `## Screenshots` table of those tags, then `gh pr edit <n> --body-file "$SCRATCH/body.md"` and re-read it. On someone else's PR, post the table as a comment (`gh pr comment <n> --body-file …`) unless the author asked for it in the description |

## Navigation map (debug build: bundle id `co.openvine.app.staging`)

| Goal | Maestro |
|---|---|
| Own profile | `tapOn: {id: profile_tab}` — wait for `id: profile_pending_action` (the "Secure Your Account" row of a new account) as well as `"No videos yet"`. Its label carries a count that changes while the profile loads, so wait on the id |
| Edit profile | `tapOn: {id: edit_profile_button}` (a pencil icon; label "Edit Profile") |
| Messages inbox | `tapOn: {id: inbox_tab}` opens **Notifications** first, then `tapOn: "Messages\nMessages"`; empty state is `"No messages yet"` |
| Appearance → Light | from the own profile: `id: settings_button` → `id: settings_app_preferences_tile` → `"Appearance\nChoose how Divine looks on this device"` → `"Light"` (or `"Dark"`, `"System default"`); back out with `id: back_button` ×3 |
| Someone's profile | `openLink: divine:///profile/<npub>` + optional `Open` |
| DM thread | on their profile, `tapOn: "Message"`; composer `"Say something…"`. Text: type, then `tapOn: {id: dm_message_send_button}`, which appears only once there is text. Video: `tapOn: {id: dm_attach_video_button}` → `"Video from your gallery"`; picking a video sends it straight away |

The magenta line above the tab bar marks the LOCAL environment; mention it in the
caption rather than cropping it. The stack's seed adds a few synthetic videos;
create whatever else the screen needs yourself.

## Steps

0. **Check the PR may be built here.** Building runs the PR's own code on this machine: `local_stack/up.sh` and its compose file, the Podfile and the Xcode build phases. Go on only when the PR comes from a branch in this repository (`gh pr view <n> --json isCrossRepository` is `false`) or its author is an org member (`gh api orgs/divinevideo/members/<login>` answers 204), and the request came from the person running this session or an org member. Otherwise stop and say why: a pull request from anyone else is reviewed, not run (`AGENT_TRUST_BOUNDARY.md` in divine-context).
1. **Build the PR's head in a worktree nobody else is using.** Screenshots must come from the code under review, and building in, or cleaning up, another session's checkout breaks its build. For your own PR, use your task worktree. Otherwise make a detached one at the head commit: take `gh pr view <n> --json headRefOid -q .headRefOid`, then `git fetch origin pull/<n>/head && git worktree add --detach .worktrees/pr-<n>-screens <sha>`. Keep that SHA; the PR section names it.
2. **`sim_up.sh`.** It waits while another run is starting the stack, then reuses a local stack another session already started (printing `STACK_STARTED=no`); otherwise it sets `BLOSSOM_PUBLIC_URL=http://localhost:43003`, writes the Keycast `master.key` a fresh worktree lacks, starts `local_stack/up.sh` and makes sure its refresh-interval tuning ran. Then it boots this run's own simulator, pins the status bar to 9:41, builds with `--dart-define=DEFAULT_ENV=LOCAL`, and installs the app. The first build takes about 5 minutes. Run it in the background with output going to a file.
3. **Sign in** with `new_device_account.yaml`. It clears the keychain and the app's data before launch, so every run starts on a fresh welcome screen and no earlier account stays on the device; there is no need to `simctl erase`. `clearState` alone is not enough: the Nostr key lives in the keychain (`mobile/e2e/maestro/README.md`).
4. **Create the other people the screen needs** with `make_account.sh`, then navigate. Write each step as a small Maestro flow. Run it with `perl -e 'alarm 240; exec @ARGV' maestro --device <UDID> test flow.yaml` so a hung step cannot hang you. Write the flows in `$SCRATCH`, not in the repo.
5. **Stage every state the PR claims, not just the happy path.** That includes in progress, failed, empty, after navigating away and back, and both appearances. A failure you produce for real, such as stopping a container, beats describing one.
6. **Capture and look.** Read every PNG. Check that it shows the claimed state and nothing that may not be public: no real names, keys or emails; no corporate partner, customer, brand or campaign name unless a maintainer approved it (`AGENTS.md`, "Security"); and no media you did not create in this run, such as other items in the simulator's Photos library behind the picker. If one appears, re-stage the shot, or ask a maintainer before using it. The synthetic accounts are fine.
7. **Publish** with `publish_gist.sh`. Run `--dry-run` first to check the files. It prints each URL only after checking it answers 200. The gist is unlisted, not private: once its URLs are in a public PR, anyone can open them, and taking them out later does not undo that.
8. **Write the PR section.** Add a table of states, the commit they were built from, one line on how they were captured (simulator, LOCAL stack, throwaway accounts, anything staged such as a paused container), and anything you noticed. On your own PR, also fix any "Not verified" text that the screenshots now contradict. Someone else's description is theirs: check authorship first (`AGENTS.md`, "Working On An Existing PR") and follow the "Put in PR" row above.
9. **Clean up:**
   - if you paused the Blossom proxy, unpause it (`docker compose -f local_stack/docker-compose.yml unpause blossom-proxy`): a paused container in the shared stack stalls every other session's uploads;
   - stop the stack (`cd mobile && mise run local_down`) only if `sim_up.sh` printed `STACK_STARTED=yes` and nobody else is using it: `xcrun simctl list devices booted` shows no other `pr-screenshots-` simulator, and no other session is running local-stack tests. Every worktree shares the one `local_stack` compose project, so `down` stops it for everyone;
   - `xcrun simctl delete <UDID>`, which removes this run's simulator, its data and the status-bar override;
   - for a detached worktree you made, `git worktree remove --force .worktrees/pr-<n>-screens`, which takes its `mobile/build` (about 4 GB) with it; in your own task worktree, delete `mobile/build`;
   - delete this worktree's Xcode output, `~/Library/Developer/Xcode/DerivedData/Runner-*`, about 2 GB. Check its
     `info.plist` `WorkspacePath` points at this worktree before deleting;
   - `rm -rf "$SCRATCH"`, which takes the run's keys, flows, logs and screenshots with it.

## Gotchas (each one cost a real run)

| Symptom | Cause / fix |
|---|---|
| A video you just published is missing from the feeds or a profile grid | The stack's refresh-interval tuning did not run, so REST read models refresh every 5–60 minutes. `sim_up.sh` runs it even when `up.sh` fails; if you started the stack another way, run `docker compose -f local_stack/docker-compose.yml run --rm funnelcake-local-tuning`. |
| DM send fails after the upload completes: "names only relays this device will not dial" | The recipient advertised a `ws://` kind-10050 inbox relay. `make_account.sh` publishes no 10050, so DMs fall back to the local relay. |
| Deep link does nothing | Use `divine:///…` with an empty host. iOS shows an "Open in …?" sheet the first time, so tap `Open` with `optional: true`. |
| A `divine:///profile/…` link opens Home | The branch predates #11017, before which iOS dropped every `divine:///` route except saved videos and challenges. Check with `git merge-base --is-ancestor a04e156363b5be9269a2e806199daaa2a60a042e HEAD`; if it fails, reach the profile through search instead. |
| Maestro asks which device to use, or drives another simulator | More than one device is booted. Pass `--device <UDID>` to every `maestro` call. |
| Maestro `tapOn` fails inside the photo picker | The picker runs out of process. Use `idb ui tap` at point coordinates. |
| Pressing Enter in the composer doesn't send | The field is multiline. Tap `id: dm_message_send_button`. |
| Notification permission sheet covers the app | `new_device_account.yaml` dismisses it. If it appears later, tap `Don’t Allow`. |
| Every local upload finishes too fast to screenshot | Pause the Blossom proxy (see the quick reference), then capture. A long pause makes the send fail, which is useful for the failed-state shot. |
| Seeded videos never load | The running stack was seeded for the Android emulator (`BLOSSOM_PUBLIC_URL` defaults to `10.0.2.2`). Only a stack `sim_up.sh` starts itself is seeded for the iOS simulator; publish your own videos instead. |
| A profile header shows the previous profile's name | Known app bug (#11043): opening one profile over another reuses the name. Navigate Home first if it matters for the shot. Delete this row once #11043 is closed. |
| `nak event` hangs | It reads an event from stdin whenever stdin is a pipe, or the relay never sent `OK`. The scripts give it `< /dev/null` and wrap it in `perl -e 'alarm …'`. Do the same for ad-hoc calls. |
| `bad math expression` in a zsh one-liner | In zsh `GID` is the shell's group id, an integer, so assigning a gist id to it fails. Use another name, e.g. `GIST_ID`. |
| Build fails: a plugin "requires minimum platform version 16.0" | Flutter left the generated Swift package below iOS 16, which happens on a cold machine or a fresh worktree. The failed build repairs it, and `sim_up.sh` builds once more; if that fails too, see `.claude/rules/ios_build_troubleshooting.md` (cause 3). |
| `flutter pub get` fails with an rsync `mkdir … SourcePackages` error | It happens in a fresh worktree. `sim_up.sh` pre-creates `build/{ios,macos}/SourcePackages`. |
| Disk fills | Free space dropped by about 8 GB during one build: `mobile/build`, DerivedData and caches. The stack's images add about 10 GB the first time. Check `df -h /System/Volumes/Data` first: start with about 12 GB free when the stack's images are already pulled, about 20 GB when they are not. |

## Never

- Point the app at production, or publish test events to non-local relays.
- Substitute widget-test or golden renders and call them screenshots. If real capture truly fails, say so with the error, and offer renders labelled as renders.
- Push screenshots to the company repo: no orphan branches, no committed PNGs, no draft releases. The gist is the host.
- Commit the Maestro flows or keys you write for one PR.
