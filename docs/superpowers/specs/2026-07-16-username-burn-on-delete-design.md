# Opt-in `@divine.video` username burn on account deletion — design

> **Superseded (2026-09-13).** The direct `POST /api/username/release` burn
> endpoint and `ProfileRepository.releaseUsername()` described below were
> removed from divine-mobile in #9144. The live path is the two-phase
> `POST /api/username/release/prepare` handshake in
> `mobile/lib/repositories/account_deletion_recovery_repository.dart`. Kept for
> design context; do not build against the API described here.

**Issue:** divinevideo/divine-mobile#6126 (assigned to @mbradley).
**Spans two repos / two PRs:** `divine-name-server` (new `POST /api/username/release` endpoint) + `divine-mobile` (client + opt-in toggle + orchestration). Both target `main`; neither stacks.
**Status:** Design complete, approved to write plan. Origin: the Jeff/imrdavis support incident (deleting an account never released the `@divine.video` handle).
**Related:** interacts with the reversible-deletion epic (funnelcake#652 → mobile#6127) and the claimed-account deletion bug keycast#296. Neither blocks this; see [Interactions](#interactions-not-blockers).

## Goal

When a user deletes their Divine account, give them an **opt-in, default-off** choice to also permanently **burn** their `@divine.video` username (revoke it and block re-registration). Default off, so anyone who wants to keep their Nostr identity for use elsewhere is unaffected. Execute the burn only if they choose it.

This adds the one deletion axis that is untouched today.

## Verified current behavior (traced on the current checkout)

Account deletion acts on two axes and ignores a third:

| Axis | Deletion today |
|---|---|
| Content + profile | `account_deletion_service.dart` fetches **all** the user's events (all kinds, incl. the kind-0 profile) and publishes batch NIP-09 (kind 5) deletes per kind, then a NIP-62 (kind 62) vanish with `['relay','ALL_RELAYS']`. Best-effort, subject to relays honoring it. |
| Key custody (keycast) | `deleteKeycastAccount()` (`auth_service.dart:2708`) is called for registered/OAuth users; for registered users a failure **hard-stops** the flow (no sign-out) — `delete_account_dialog.dart:309-328`. |
| **Username (`you@divine.video`)** | **Untouched — stays `active` and keeps resolving.** |

There is no deletion→nameserver path anywhere; no NIP-62 handling on the nameserver; revoke/burn is admin-only (`admin.post('/username/revoke')`).

The kind-0 profile is **already** covered by the content path, so the username is the only net-new axis — this feature adds exactly one capability, not two.

**Why burn stops resolution (verified):** `revokeUsername(name, burn)` (queries.ts:339) sets `status='burned', recyclable=0`. `nip05.ts` serves only `status==='active'` (lines 32, 85, 90), so a burned name returns `{names:{}}`; the cron reconciliation enqueues a Fastly **delete** for revoked/burned names (index.ts:142). A claim of a `burned` name is rejected (username.ts:464); only `revoked` names are recyclable (username.ts:114). So **burn = resolution dies at origin + edge, and the handle cannot be re-registered** — squatting/impersonation protection.

**One active name per pubkey (verified):** partial unique index on `(pubkey, status='active')`; `getUsernameByPubkey` filters `status='active'` (queries.ts:109-110); claiming a new name auto-revokes the prior active one (username.ts:478).

## Decisions

- **Opt-in, default off.** The common case ("done with Divine, keep my identity elsewhere") wants the name kept.
- **Burn, not revoke.** Only `burn:true` blocks re-registration. Revoke would let a squatter re-claim.
- **Hard-block on burn failure (burn-first ordering).** If the user opted in and the release fails, **abort the whole deletion with nothing destroyed**; the user retries or unchecks the toggle to proceed. This is *forced* by "don't delete unless we can also burn": burn is a single irreversible write with no dry-run, so it must run before any irreversible deletion, and the signer window ( NIP-98 needs a live signer, which only exists before `deleteKeycastAccount()`) forbids any other order.
- **No Cubit refactor of `executeAccountDeletion`.** Extend the existing procedural function minimally; keep the genuinely-new logic (ownership lookup, release) in the repository/provider layers. Rationale: #6127 rebuilds this whole flow full-screen, so a Cubit refactor now is throwaway and collides. Documented tradeoff.

## Design — Part 1: divine-name-server

### `POST /api/username/release`

Mirrors `/api/username/claim` structurally.

- **Auth:** `verifyNip98Event` (same middleware as `/claim`). The pubkey is derived from the NIP-98 header.
- **Body:** `{ "name": "<handle>" }`. Explicit, not derived from the pubkey. The server verifies the authed pubkey owns that **active** name (via `getUsernameByPubkey`); a mismatch is rejected. This prevents a client bug from burning "whatever name I happen to own" and forces the caller to name the exact handle.
- **Action:** `revokeUsername(canonical, burn: true)` **plus** enqueue the Fastly delete task (mirror the `admin.post('/username/revoke')` path's `enqueueFastlySyncTask` call). The 6-hourly cron reconciliation is the backstop; origin stops serving immediately regardless.
- **Responses:**
  - `200 { ok:true, released:true, name, status:'burned' }` on success.
  - `200 { ok:true, released:false, reason:'no_active_name' }` idempotent no-op when the caller owns no active name, or it is already burned.
  - `401` NIP-98 verification failure (`Nip98Error`).
  - `403` authed pubkey does not own the named active handle.
  - `400` missing/invalid body.
- **Collision-free:** different repo/service from the reversible-deletion cluster; independently testable (vitest) and deployable (CF Worker).

**Alternative considered:** derive the name from the pubkey (no body). Rejected — explicit `{name}` is safer and matches `/claim`'s shape.

### Tests (vitest)
- Happy path: owner burns own active name → `burned` + Fastly enqueue.
- Not-owner: authed pubkey ≠ owner of named handle → `403`.
- No active name / already burned → idempotent `200 released:false`.
- NIP-98 failure → `401`.

## Design — Part 2: divine-mobile

### Repository layer (`profile_repository`)
- `releaseUsername({required String name})` mirroring `claimUsername()` (`profile_repository.dart:750`): NIP-98 header via `_nostrClient.createNip98AuthHeader`, same error taxonomy → a typed `UsernameReleaseResult` (success / notOwner / networkError / authError). No strings in state.
- `getUsernameByPubkey({required String pubkeyHex})` wrapping `GET /api/username/by-pubkey/:pubkey` (net-new — no client wrapper exists today). Returns the active handle or null.

### Ownership gate
A Riverpod `FutureProvider` (consistent with the legacy-Riverpod settings screen) exposes "does the current user own an active `@divine.video` name, and which one." The toggle renders only when a name is owned. Keeps the network lookup out of the widget.

### Toggle
An opt-in checkbox **inside the existing `showDeleteAllContentWarningDialog`** (`delete_account_dialog.dart:77`) — a control added to the existing dialog, not a new dialog. Default off. Names the exact handle. Copy is a **draft pending product/brand sign-off** (not a build blocker); per support/product feedback it must read as permanent/"lost forever," and per brand we present it as "username," not "NIP-05."

### Orchestration (`executeAccountDeletion`, `delete_account_dialog.dart:261`)
**Burn-first.** If the user opted in:
1. `releaseUsername(name)` runs **before** any destructive step, while the signer is fresh.
   - On failure → **abort, nothing destroyed**, error snackbar (same `DivineSnackbarContainer` pattern as today's failure path): the account was *not* deleted; retry, or uncheck the toggle. `getUsernameByPubkey` on a later retry returns null once burned, so the toggle self-clears and retry proceeds cleanly.
   - On success → continue.
2. Existing flow unchanged: `deleteAccount()` (NIP-62/09) → `deleteKeycastAccount()` → `signOut(deleteKeys:true, deleteLocalUserData:true)`.

The `burnUsername` flag and the owned `name` flow from the dialog's `onConfirm` into `executeAccountDeletion` (new params). No Flutter types leak below the widget layer.

### l10n
New ARB keys (toggle label, burn-failure snackbar) added to `app_en.arb` and mirrored to every `app_*.arb`, or added to `_knownUntranslatedDebt` if translations are deferred; `arb_consistency_test` run.

### Tests
- `profile_repository`: `releaseUsername` (200 / 403 / network) + `getUsernameByPubkey` (found / not-found).
- Widget: toggle shows only when a name is owned; hidden otherwise.
- Orchestration: burn-failure aborts with nothing deleted; burn-success proceeds through the existing steps.

## End-to-end data flow (opted-in path)

```
tap Delete → ownership provider resolves → dialog shows checkbox for @alice.divine.video
 → type DELETE + check burn + confirm
 → executeAccountDeletion:
     releaseUsername(name) --NIP-98--> POST /release --> burn + Fastly de-sync
        ├─ fail  → abort, nothing deleted, error snackbar (retry / uncheck)
        └─ ok    → deleteAccount() → deleteKeycastAccount() → signOut() → /welcome
```

## Error handling (per-layer)
- **Client `releaseUsername`** returns a typed result; the orchestration maps failure → localized snackbar. No error strings/exception objects in any state object.
- **Server** returns typed JSON `{ok,error}` mirroring `/claim`.
- Release failure is a **hard gate** on the opted-in path (nothing destroyed), not a best-effort side effect.

## Interactions (not blockers)

- **keycast#296 (claimed-account deletion FK bug).** On a *claimed* account, today's deletion already fails at `deleteKeycastAccount()` (the `account_claim_tokens` `NO ACTION` FK rolls back `DELETE FROM users`). With this feature, burn-first means the handle burns, then the flow still dies at the pre-existing keycast wall. This is **not caused or worsened by this feature** — claimed-account deletion is already broken, it's keycast's to fix (separate repo, unscheduled), and the burned handle is what the user asked for and is retryable once keycast#296 lands. The common non-claimed path works end-to-end today. **Decision: ship independently, document here, do not gate.**
- **#6127 (reversible 28-day deletion).** When that full-screen flow lands, the burn must be deferred to the terminal deletion moment (pre-signed + gift-wrapped alongside the future-dated kind-62, or server-side) — it must not fire at prepare-time, or a user who cancels within the recovery window loses their handle permanently. That wiring belongs to #6127. Cross-linked both directions already.

## Non-goals / out of scope
- Broader deletion-robustness gaps (optimistic "success" on best-effort relay deletion, swallowed partial failures) — tracked separately.
- The non-claimed self-serve delete-failure second cause surfaced while investigating #4881 — separate bug, not this feature.
- Any nameserver NIP-62 handling — out of scope; the client calls `/release` explicitly.

## Open questions
- Toggle + snackbar copy: product/brand sign-off before merge.
- Confirm the exact `enqueueFastlySyncTask` call shape when implementing the endpoint (mirror admin revoke).
