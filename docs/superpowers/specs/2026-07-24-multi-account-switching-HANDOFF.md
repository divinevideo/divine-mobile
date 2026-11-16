# Multi-account switching — HANDOFF

**Date:** 2026-07-26
**PR:** https://github.com/divinevideo/divine-mobile/pull/6342 (ready for review)
**Epic:** #4623
**Branch:** `feat/multi-account-switching`
**Worktree:** `/Users/rabble/code/divine/divine-mobile/.worktrees/multi-account-switching`
**Reviewers requested:** Liz (`NotThatKindOfDrLiz`), Meylis (`realmeylisdev`)
**Design doc (read first):** `docs/superpowers/specs/2026-07-24-multi-account-switching-design.md`

This doc is a self-contained handoff so a fresh agent (any LLM) can resume
without re-deriving the state. Read it top to bottom, then the design doc.

---

## TL;DR status

**In-place account switching is built, wired, and PROVEN RUNNING on the iOS
simulator.** Tap another already-signed-in account → you become it on the same
screen. No sign-out, no welcome-screen bounce. Verified by an on-device
integration test (two real accounts, real `signInForAccount`, real container
swap, asserted authenticated as the target). Everything is committed and
pushed. It's behind `FF_ACCOUNT_SWITCHING` (runtime-toggleable), so it's dark
until deliberately enabled.

18 commits on the branch (all pushed). Feature works. Remaining items are
polish + rollout, not "make it work."

---

## What "the switch" is and why it's built this way

Users are logged into several accounts and switch constantly. The OLD switch
(still the code path for *adding* a new account) signs out → routes to the
welcome screen → `WelcomeBloc` auto-signs-in the pending account. That bounce
is unacceptable for high-frequency switching, and it caused data-loss reports
(#4623).

**The mechanism (the key architectural facts):**

1. `authServiceProvider` is `@Riverpod(keepAlive: true)` with **no static
   singleton** — every `ProviderContainer` gets its **own** `AuthService`
   instance and its own mutable session state. (Verify:
   `grep -rn "static.*AuthService.*instance" mobile/lib` → none.)
2. `main.dart` already mounts the app via `UncontrolledProviderScope` around a
   `ProviderContainer`.

So a switch = **build a new container, let its fresh `AuthService` sign in as
the target via the EXISTING `signInForAccount`, swap the container into the
scope, dispose the old one.** Because sign-in runs on the *new* instance, the
leaving account's `AuthService` is just thrown away with its container — no
cleanup, no stale providers, and **no side-effect-free `activate()` refactor is
needed** (that was an earlier assumption; it's off the critical path — design
§8.2 correction).

**The one real constraint is the DB, not auth.** `databaseProvider`
(`@Riverpod keepAlive`) opens a native SQLite connection per container and
closes it on dispose. Two live containers = two connections to the same
encrypted file = corruption. So the DB is **hoisted** into a `DeviceScope` and
shared across every container via provider overrides. `FlutterSecureStorage`
is deliberately NOT hoisted — it's a stateless facade over the platform
keychain; a per-container instance is harmless. Only things holding
non-shareable open OS state (the DB connection) get hoisted.

**Rollback (prove-then-commit):** `swapAccount` builds + signs in the new
container FIRST; only on success does it swap. On failure it disposes the
half-built container and the current account is untouched.

---

## New files (the mechanism)

| File | Role |
|---|---|
| `mobile/lib/services/auth/account_scope.dart` | `AccountScope` (sealed `SignedOut`\|`SignedIn`) + immutable `AccountSession` (pubkey, `NostrIdentity`, source, relays). The account-boundary model. |
| `mobile/lib/providers/device_scope.dart` | `DeviceScope` (shared DB + prefs + switch controller) + `deviceScopeProvider` + `buildAccountContainer(deviceScope)`. Only the DB truly needs sharing. |
| `mobile/lib/providers/container_swap_host.dart` | `ContainerSwapHost` (owns the live container, swaps in place, disposes old post-frame) + `AccountSwitchController` (the UI handle; lives above the container). |
| `mobile/lib/providers/swap_account.dart` | `swapAccount(...)` — build → sign in (real `signInForAccount`) → swap; rollback on failure. Also inits `EnvironmentService` on the new container before reading its auth service (see gotcha). |
| `mobile/integration_test/account_swap_integration_test.dart` | On-device proof. Two real local-key accounts, real swap, asserted. |

**Changed (wiring):**
- `mobile/lib/main.dart` — builds the DB once in `main()` (`createAppDatabase`), wraps in `DeviceScope`, mounts via `ContainerSwapHost`. Behaviour-identical for a single account.
- `mobile/lib/providers/database_provider.dart` — extracted `createAppDatabase()` (so `main()` builds the DB before any container).
- `mobile/lib/providers/auth_providers.dart` — added `activeAccountProvider` (bridge: derives `AccountScope` from current auth; container overrides it later).
- `mobile/lib/screens/settings/settings_screen.dart` — switcher onTap now calls `swapAccount` (was `cubit.switchToAccount`); failure snackbar.
- `mobile/lib/blocs/settings_account/settings_account_cubit.dart` — removed dead `switchToAccount` (switch is app-level now); `addNewAccount` still uses the sign-out→welcome flow (correct — a *new* account isn't authenticated yet).
- `mobile/lib/l10n/app_en.arb` (+ generated) — `settingsAccountSwitchFailed` (in `_knownUntranslatedDebt`, English-only for now).

---

## Phase 1 bug fixes bundled in this PR (independent of the switch, were live on main)

- **`notifications` cross-account inbox leak** — table had no owner column, so both accounts shared one inbox. Owner-scoped (`owner_pubkey` + migration + claim-on-signin). Files: `packages/db_client/.../tables.dart`, `notifications_dao.dart`, `notification_repository`.
- **`pending_product_events` cross-signed analytics** — flush signs with the current account's NIP-98 token; rows had no owner and sign-out didn't clear them, so logout→login-as-other published the prior account's analytics under the new signature. Owner-scoped. Files: `pending_product_events_dao.dart`, `lib/services/product_event_queue.dart`, `social_providers.dart`.
- **Feature-flag cubit guard** — the 2026-04 design specified a cubit-level guard that never shipped. Added.
- Deleted dead `lib/services/identity_manager_service.dart` (a second, non-functional switching model).

---

## Commit list (newest first)

```
75998fb5e test(account): on-device integration test proves the in-place swap works
39c8a54cd fix(account): initialize environment on the swapped-in container before sign-in
751828505 feat(account): switch accounts in place from settings — no welcome bounce
725f9451c feat(account): mount the container-swap infrastructure at app entry
53ae8de97 feat(account): add swapAccount — build, sign in, swap in place, roll back on failure
0a704eaa3 feat(account): add ContainerSwapHost — in-place container swap, no tree remount
641f96027 feat(account): add DeviceScope — shared device singletons across a container swap
299a01ace docs(account): in-place switch is unblocked — activate() off the critical path
603634b68 docs(account): record why Phase 2 credentials can't ship before the finalize refactor
575e92fa9 docs(account): mark PendingProductEvents resolved — phase 1 complete
6af2d915a fix(analytics): scope the product-event queue to its owning account
e629d7cb1 docs(account): record the activate() entanglement blocker for phase 4
949e03fa0 feat(account): bridge AccountScope off the current auth session
c2e42971e feat(account): add the AccountScope / AccountSession boundary model
2547bc4ef docs(account): record phase-1 progress and reorder prefs work to phase 3
d5f08774d fix(account): enforce the account-switching flag in the cubit, not just the UI
858619843 fix(notifications): scope the notification cache to its owning account
0c4736926 docs(account): architecture report and plan for multi-account switching
```

---

## How to verify / run

**Run the app (single-account, no regression check):**
```
cd mobile
mise exec -- flutter run -d <ios-sim-id>            # boots clean
mise exec -- flutter run -d <ios-sim-id> --dart-define=FF_ACCOUNT_SWITCHING=true   # switcher UI live in Settings
```
Both confirmed to boot clean to the feed.

**Run the mechanism unit/widget tests (host, fast):**
```
cd mobile
mise exec -- flutter test test/providers/device_scope_test.dart \
  test/providers/container_swap_host_test.dart \
  test/providers/swap_account_test.dart \
  test/services/auth/account_scope_test.dart \
  test/providers/active_account_provider_test.dart
```

**Run the on-device proof (the definitive switch test):**
```
cd mobile
# If it fails to build with "Missing package product 'FlutterFramework'"/'firebase-core',
# that's a stale Xcode SPM cache — clean it first (see gotcha below).
mise exec -- flutter test integration_test/account_swap_integration_test.dart -d <ios-sim-id>
```
Last result: `All tests passed!`

---

## Gotchas learned the hard way (READ THESE)

1. **Driving the app on the sim.** There is NO iOS/simulator MCP in this env and
   `idb` isn't installed. Use **`flutter test integration_test/... -d <sim>`** —
   it runs the real app on-device with a real gesture layer + real Keychain/DB.
   `patrol` (already a dep) drives native dialogs but the existing
   `multi_account_switch_test.dart` needs the local Docker backend. Don't get
   stuck on "I can't tap" — integration_test is the tool.

2. **`flutter test integration_test` trips a stale Xcode SPM cache** that the
   normal `flutter run` build doesn't. Symptom: `Failed to build iOS app /
   Missing package product 'FlutterFramework'` (+ firebase-*, etc.), test dies
   at `+0 -1: loading`. Fix (per `.claude/rules/ios_build_troubleshooting.md`,
   ~15 min): `rm -rf ~/Library/Developer/Xcode/DerivedData/*; cd mobile/ios &&
   rm -rf Pods Podfile.lock .symlinks; flutter clean && flutter pub get && (cd
   ios && pod install)`. Do NOT commit pubspec.lock/Package.resolved changes
   from this.

3. **The integration test needs a guarded zone for network noise.** Sign-in
   fires fire-and-forget relay discovery (HTTP to indexers) → `ClientException`
   the offline test can't avoid. The test wraps the network-triggering auth
   calls in `_guarded()` (a `runZonedGuarded` that swallows
   ClientException/SocketException/WebSocket/cert/host-lookup) while surfacing
   real assertion failures. Keep `tester.*` ops OUT of that zone (zone-mismatch).

4. **The sim shuts itself down during a long (~5 min) build**, so a later
   `simctl install` fails with `SimError 405 "current state: Shutdown"`.
   Mitigate: `open -a Simulator` + `xcrun simctl bootstatus <id> -b` before
   install, or build first then `simctl boot`/`install`/`launch` the pre-built
   `Runner.app`. Read a headless app's logs with `xcrun simctl spawn <id> log
   show --last 30s --predicate 'process == "Runner"'`.

5. **`CacheSync` is a process-global static** (`static late CacheDao _dao`),
   initialized once at launch by the startup coordinator. It is SHARED across
   containers (and the DB it holds is the hoisted one), so the swap does NOT
   need to init it. A `CacheSync._dao not initialized` LateInit only appears in
   tests that skip app startup — it's a test artifact, not a real-app gap.

6. **`EnvironmentService` is per-container and defaults to production.** It's
   NOT global. A swap container that skips startup would default to production
   (fine for the team) but ignore a staging override. `swapAccount` calls
   `environmentService.initialize()` on the new container before it first reads
   `authServiceProvider` — env parity with a cold launch. Initializing later
   rebuilds the auth service in LOCAL (its `OAuthConfig` changes) and disposes
   the instance the switch already fenced (#11046).

7. **Stale local `origin/main` ref caused a fake "merge conflict with main"** in
   the pre-push hook (it uses `git merge-tree --write-tree origin/main HEAD`,
   which breaks on a stale/unrelated ref). If a push is rejected for conflicts
   but GitHub shows the PR mergeable: run `git fetch origin main` and retry —
   do NOT rebase (a bad rebase tried to replay thousands of commits; abort with
   `git rebase --abort` if that happens). NEVER `--no-verify`.

8. `AuthService` has **no single sign-in finalization chokepoint**: fresh
   sign-in runs through `_setupUserSession`, but the reconnect/restore paths
   (`_reconnectAmber`/`_reconnectBunker`/`_reconnectNip07`, ~`auth_service.dart:2199`)
   finalize inline and bypass it. Matters for any "do X once when an account
   becomes active" change.

---

## Remaining work (none blocks a flag-gated team test)

Priority order:

1. **Per-account prefs isolation** (the one real tester-facing rough edge).
   Bookmarks / mutes / seen-videos DON'T yet survive a switch — 8 live
   `SharedPreferences` keys across 5 services (`seen_videos`, `bookmark`,
   `curated_list`, `content_reporting`, `content_deletion`) use static global
   keys and get *deleted* by `UserDataCleanupService` on switch. Now clean to
   fix: containers are per-account, so it's per-account keys (`<key>_<pubkey>`)
   + a copy-old-global-value migration + claim-on-first-signin (same pattern as
   notifications/drafts), then drop those keys from the cleanup service's
   always-clear list, and split `UserDataCleanupService` into `switchAway`
   (preserve) vs `deleteAccountFromDevice` (destroy). See design doc Phase 3
   bullet + §3.2(d)/(f). ~5 services, mechanical, test A→B→A per key.

2. **CI**: re-run any flaked "Generated Files" job (it's a git-fetch
   shallow-clone infra race, not code — all generated files are committed; the
   normal Tests job passes). Confirm CI green on HEAD.

3. **TestFlight upload**: Rabble runs `zsp` — an agent can't do the upload.

4. (Later, robustness, NOT a blocker) The atomic `activate()` /
   `buildAndProveSession` refactor + write-once per-account credential storage
   (Phase 2/4). Design doc §8.4 + the Phase-2 correction explain why credentials
   fold into that refactor and can't ship independently (the null-`userPubkey`
   OAuth cohort must force re-auth, not be auto-archived — it breaks the Bug-2
   guard in `auth_service_multi_account_test.dart`).

---

## Also see (episodic notes, if the next agent is Claude with the journal)

`~/.claude/journal/2026-07-25-*` — three entries: the container-swap approach
(activate() off critical path), the credential finalize-chokepoint finding, and
the driving-the-app / SPM-cache gotchas. Non-Claude agents: the same content is
in the design doc + this handoff's gotchas.
