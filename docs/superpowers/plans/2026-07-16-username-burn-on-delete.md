# Opt-in @divine.video username burn on delete — Implementation Plan

> **Superseded (2026-09-13).** The direct `POST /api/username/release` burn
> endpoint and `ProfileRepository.releaseUsername()` described below were
> removed from divine-mobile in #9144. The live path is the two-phase
> `POST /api/username/release/prepare` handshake in
> `mobile/lib/repositories/account_deletion_recovery_repository.dart`. Kept for
> design context; do not build against the API described here.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user opt in, during account deletion, to permanently burn their `@divine.video` username so it stops resolving and cannot be re-registered.

**Architecture:** New public NIP-98 endpoint `POST /api/username/release` on divine-name-server burns the caller's own active name (`revokeUsername(..., burn:true)` + Fastly de-sync). Mobile adds `releaseUsername()` + an ownership lookup to `profile_repository`, an opt-in checkbox in the existing delete dialog gated on owning an active name, and a **burn-first, hard-block** step in `executeAccountDeletion`.

**Tech Stack:** divine-name-server (TypeScript, Hono, Cloudflare Workers, D1, vitest). divine-mobile (Dart, Flutter, bloc/Riverpod, http, mocktail).

**Spec:** `docs/superpowers/specs/2026-07-16-username-burn-on-delete-design.md`

## Global Constraints

- **Two repos, two PRs, both target `main`, neither stacks.** Part A in a `divine-name-server` worktree off its `origin/main`; Part B in this `divine-mobile` worktree (`feat/username-burn-on-delete`).
- **Burn = `burn:true`** on `revokeUsername` (status `burned`, `recyclable=0`). Never plain revoke.
- **Burn-first ordering** in `executeAccountDeletion`: release runs before any destructive step; on failure abort with nothing destroyed.
- **Never truncate Nostr IDs / pubkeys** anywhere (code, logs, tests).
- **No error strings/exception objects in bloc/cubit state.** Typed results only.
- **l10n:** any new `app_en.arb` key is mirrored to every `app_*.arb` (or added to `_knownUntranslatedDebt`); run `flutter test test/l10n/arb_consistency_test.dart`.
- **Divine dark-mode only:** use `VineTheme` + `divine_ui` components, no raw `Colors.*`.
- **Verify before push:** `dart format`, `flutter analyze lib test`, scoped tests (Part B); `npm test` / `vitest` (Part A).
- Part B's `/by-pubkey` lookup is a pre-existing prod endpoint, so the toggle renders for handle owners immediately — it is **not** inert. Until Part A (`/release`) is deployed to prod, an opted-in confirm hard-blocks the whole account deletion (the user can uncheck to proceed), so **deploy #65 to prod before a mobile build with the toggle ships**. Unit tests use a mocked client.

---

# Part A — divine-name-server: `POST /api/username/release`

> Executed in a fresh `divine-name-server` worktree:
> `git -C /Users/mjb/code/divine-name-server fetch origin && git -C /Users/mjb/code/divine-name-server worktree add .worktrees/username-release -b feat/username-release-endpoint origin/main`

### Task A1: `POST /api/username/release` endpoint + tests

**Files:**
- Modify: `src/routes/username.ts` (add route after the `/claim` route at line 541; add `revokeUsername` to the `../db/queries` import block at lines 8-20)
- Test: `src/routes/username.test.ts` (add a `describe('POST /release')` block)

**Interfaces:**
- Consumes (already imported in `username.ts`): `verifyNip98Event`, `validateUsername`, `UsernameValidationError`, `getUsernameByPubkey`, `enqueueFastlySyncTask`, `deleteUsernameFromFastly`.
- Adds import: `revokeUsername` from `../db/queries` (signature `revokeUsername(db, name, burn: boolean): Promise<void>`).
- Produces: route `POST /api/username/release`, request `{ name: string }`, responses documented below. Part B's `releaseUsername()` consumes this contract.

**Response contract (what Part B relies on):**
- `200 { ok:true, released:true, name, status:'burned' }` — burned.
- `200 { ok:true, released:false, reason:'no_active_name' }` — caller owns no active name (idempotent no-op).
- `401 { ok:false, error }` — NIP-98 failure.
- `403 { ok:false, error }` — caller owns a *different* active name than the one requested.
- `400 { ok:false, error }` — invalid/missing name.

- [ ] **Step 1: Write the failing tests**

Add to `src/routes/username.test.ts`. Mirror the existing claim tests' harness: reuse `createMockDB(initialUsernames)`, the `vi.mock('../middleware/nip98')` and `vi.mock('../utils/fastly-sync')` blocks already at the top of the file, and the `verifyNip98Event` mock accessor pattern used by the existing `describe('POST /claim')` block (read that block first to copy the exact `beforeEach`/import-of-mock wiring).

```ts
describe('POST /release', () => {
  let verifyNip98Event: any
  beforeEach(async () => {
    const nip98Module = await import('../middleware/nip98')
    verifyNip98Event = nip98Module.verifyNip98Event
    vi.mocked(verifyNip98Event).mockResolvedValue(
      '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b'
    )
  })

  function app(db: any) {
    const a = new Hono()
    a.use('*', async (c, next) => { c.env = { DB: db, executionCtx: c.executionCtx }; await next() })
    a.route('/api/username', username)
    return a
  }

  it('burns the caller\'s own active name', async () => {
    const db = createMockDB([{
      name: 'alice', username_display: 'alice', username_canonical: 'alice',
      pubkey: '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b',
      status: 'active',
    }])
    const res = await app(db).request('/api/username/release', {
      method: 'POST', headers: { Authorization: 'Nostr x' },
      body: JSON.stringify({ name: 'alice' }),
    })
    expect(res.status).toBe(200)
    const json = await res.json()
    expect(json).toMatchObject({ ok: true, released: true, name: 'alice', status: 'burned' })
  })

  it('returns 403 when the caller owns a different active name', async () => {
    const db = createMockDB([{
      name: 'bob', username_display: 'bob', username_canonical: 'bob',
      pubkey: '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b',
      status: 'active',
    }])
    const res = await app(db).request('/api/username/release', {
      method: 'POST', headers: { Authorization: 'Nostr x' },
      body: JSON.stringify({ name: 'alice' }),
    })
    expect(res.status).toBe(403)
  })

  it('returns 200 no-op when the caller owns no active name', async () => {
    const db = createMockDB([])
    const res = await app(db).request('/api/username/release', {
      method: 'POST', headers: { Authorization: 'Nostr x' },
      body: JSON.stringify({ name: 'alice' }),
    })
    expect(res.status).toBe(200)
    expect(await res.json()).toMatchObject({ ok: true, released: false, reason: 'no_active_name' })
  })

  it('returns 401 on NIP-98 failure', async () => {
    vi.mocked(verifyNip98Event).mockRejectedValue(
      Object.assign(new Error('bad auth'), { name: 'Nip98Error' })
    )
    const db = createMockDB([])
    const res = await app(db).request('/api/username/release', {
      method: 'POST', headers: {}, body: JSON.stringify({ name: 'alice' }),
    })
    expect(res.status).toBe(401)
  })
})
```

Verify `createMockDB` handles: (a) `getUsernameByPubkey` — `SELECT * FROM usernames WHERE pubkey = ? AND status = ?` returning the fixture whose `pubkey` matches and `status='active'`; (b) `revokeUsername` — the `UPDATE usernames SET status = ?...` no-op is fine for the mock (assertion is on the response, not DB mutation). If the existing `createMockDB` lacks the by-pubkey SELECT branch, add it next to the existing username SELECT branches, matching their style.

- [ ] **Step 2: Run tests, verify they fail**

Run: `cd /Users/mjb/code/divine-name-server/.worktrees/username-release && npm test -- src/routes/username.test.ts`
Expected: the four `POST /release` tests FAIL (404 — route not defined yet).

- [ ] **Step 3: Add `revokeUsername` to imports**

In `src/routes/username.ts`, add `revokeUsername,` to the destructured `../db/queries` import (lines 8-20).

- [ ] **Step 4: Implement the route**

Insert before `export default username` (line 543):

```ts
username.post('/release', async (c) => {
  try {
    const bodyText = await c.req.text()
    const url = new URL(c.req.url)
    const pubkey = await verifyNip98Event(
      c.req.raw.headers,
      'POST',
      url.toString(),
      bodyText
    )

    const body = JSON.parse(bodyText) as { name: string }
    const { name } = body

    let usernameData: { display: string; canonical: string }
    try {
      usernameData = validateUsername(name)
    } catch (error) {
      if (error instanceof UsernameValidationError) {
        return c.json({ ok: false, error: error.message }, 400)
      }
      throw error
    }
    const { canonical: nameCanonical } = usernameData

    // The caller must currently hold this exact active name. One active name
    // per pubkey (partial unique index on pubkey,status='active').
    const owned = await getUsernameByPubkey(c.env.DB, pubkey)
    if (!owned) {
      // Nothing active to release (e.g. already burned). Idempotent no-op.
      return c.json({ ok: true, released: false, reason: 'no_active_name' })
    }
    const ownedCanonical = owned.username_canonical || owned.name?.toLowerCase()
    if (ownedCanonical !== nameCanonical) {
      return c.json({ ok: false, error: 'You do not own that username' }, 403)
    }

    // Burn: permanent, blocks re-registration (recyclable=0).
    await revokeUsername(c.env.DB, nameCanonical, true)

    // Delete from Fastly so the burned name stops resolving at the edge.
    c.executionCtx.waitUntil(
      deleteUsernameFromFastly(c.env, nameCanonical).then(async (result) => {
        if (!result.success) {
          await enqueueFastlySyncTask(c.env.DB, {
            username: nameCanonical,
            action: 'delete',
          })
        }
      })
    )

    return c.json({
      ok: true,
      released: true,
      name: owned.username_display || owned.name,
      status: 'burned',
    })
  } catch (error) {
    if (error instanceof Error && error.name === 'Nip98Error') {
      return c.json({ ok: false, error: error.message }, 401)
    }
    console.error('Release error:', error)
    return c.json({ ok: false, error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 5: Run tests, verify they pass**

Run: `cd /Users/mjb/code/divine-name-server/.worktrees/username-release && npm test -- src/routes/username.test.ts`
Expected: all `POST /release` tests PASS. Then run the full suite: `npm test`. Expected: all green.

- [ ] **Step 6: Update the file's ABOUTME header**

In `src/routes/username.ts` line 2, add `POST /release` to the Authenticated endpoints list.

- [ ] **Step 7: Commit**

```bash
git add src/routes/username.ts src/routes/username.test.ts
git commit -m "feat(username): add POST /api/username/release to burn caller's own name (#6126)"
```

**→ First real commit in the nameserver repo. STOP: draft the PR description for Matt's approval, then push + open the draft PR.**

---

# Part B — divine-mobile: client + toggle + orchestration

> Executed in the existing worktree `.worktrees/username-burn-on-delete` (branch `feat/username-burn-on-delete`). Run `flutter pub get` in `mobile/` first (fresh worktree).

### Task B1: `UsernameReleaseResult` + `releaseUsername()` in profile_repository

**Files:**
- Create: `mobile/packages/profile_repository/lib/src/username_release_result.dart`
- Modify: `mobile/packages/profile_repository/lib/profile_repository.dart` (add barrel export after line 12)
- Modify: `mobile/packages/profile_repository/lib/src/profile_repository.dart` (add `_usernameReleaseUrl` const near line 21; add `releaseUsername` method after `claimUsername` ~line 833)
- Test: `mobile/packages/profile_repository/test/src/profile_repository_release_test.dart`

**Interfaces:**
- Produces: `sealed class UsernameReleaseResult` with `UsernameReleaseSuccess`, `UsernameReleaseNotOwner`, `UsernameReleaseNetworkError`, `UsernameReleaseError(String message)`; and `Future<UsernameReleaseResult> releaseUsername({required String name})`.
- Consumes: `_nostrClient.createNip98AuthHeader({url, method, payload})` and `_httpClient.post(...)` — same as `claimUsername` (`profile_repository.dart:750-832`).

- [ ] **Step 1: Write the result type**

Create `mobile/packages/profile_repository/lib/src/username_release_result.dart`:

```dart
/// Sealed class representing the result of a username release (burn) attempt.
sealed class UsernameReleaseResult {
  /// Creates a username release result.
  const UsernameReleaseResult();
}

/// Username was permanently burned.
class UsernameReleaseSuccess extends UsernameReleaseResult {
  /// Creates a success result.
  const UsernameReleaseSuccess();
}

/// The authenticated pubkey does not own the requested active name.
class UsernameReleaseNotOwner extends UsernameReleaseResult {
  /// Creates a not-owner result.
  const UsernameReleaseNotOwner();
}

/// The server could not be reached (network failure, timeout, CORS).
class UsernameReleaseNetworkError extends UsernameReleaseResult {
  /// Creates a network-error result.
  const UsernameReleaseNetworkError();
}

/// The server rejected the release or it could not be authenticated.
class UsernameReleaseError extends UsernameReleaseResult {
  /// Creates an error result with the given [message].
  const UsernameReleaseError(this.message);

  /// Description of what went wrong.
  final String message;

  @override
  String toString() => 'UsernameReleaseError($message)';
}
```

Add to `mobile/packages/profile_repository/lib/profile_repository.dart` after line 12:
```dart
export 'src/username_release_result.dart';
```

- [ ] **Step 2: Write the failing test**

Create `mobile/packages/profile_repository/test/src/profile_repository_release_test.dart`. Mirror the existing claim test's setup (find it: `grep -rl "claimUsername" test/`) for how `ProfileRepository` is constructed with a mock `NostrClient` + mock `http.Client`. Then:

```dart
group('releaseUsername', () {
  test('returns UsernameReleaseSuccess on 200 released:true', () async {
    when(() => nostrClient.createNip98AuthHeader(
      url: any(named: 'url'), method: 'POST', payload: any(named: 'payload'),
    )).thenAnswer((_) async => 'Nostr xyz');
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => Response('{"ok":true,"released":true,"name":"alice","status":"burned"}', 200));

    final result = await repository.releaseUsername(name: 'alice');
    expect(result, isA<UsernameReleaseSuccess>());
  });

  test('returns UsernameReleaseNotOwner on 403', () async {
    when(() => nostrClient.createNip98AuthHeader(
      url: any(named: 'url'), method: 'POST', payload: any(named: 'payload'),
    )).thenAnswer((_) async => 'Nostr xyz');
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => Response('{"ok":false,"error":"You do not own that username"}', 403));

    expect(await repository.releaseUsername(name: 'alice'), isA<UsernameReleaseNotOwner>());
  });

  test('returns UsernameReleaseNetworkError on http failure', () async {
    when(() => nostrClient.createNip98AuthHeader(
      url: any(named: 'url'), method: 'POST', payload: any(named: 'payload'),
    )).thenAnswer((_) async => 'Nostr xyz');
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
      .thenThrow(Exception('socket'));

    expect(await repository.releaseUsername(name: 'alice'), isA<UsernameReleaseNetworkError>());
  });
});
```

- [ ] **Step 3: Run test, verify it fails**

Run: `cd mobile/packages/profile_repository && flutter test test/src/profile_repository_release_test.dart`
Expected: FAIL — `releaseUsername` not defined.

- [ ] **Step 4: Implement `releaseUsername`**

In `profile_repository.dart`, add near line 22:
```dart
const _usernameReleaseUrl = 'https://names.divine.video/api/username/release';
```

Add after `claimUsername` (mirror its NIP-98 + http + switch shape):
```dart
/// Permanently burns the caller's own `@divine.video` username via a
/// NIP-98 authenticated request to `names.divine.video/api/username/release`.
///
/// The server verifies the authenticated pubkey owns [name] as an active
/// username before burning it. Returns a [UsernameReleaseResult].
Future<UsernameReleaseResult> releaseUsername({required String name}) async {
  final payload = jsonEncode({'name': name});
  final authHeader = await _nostrClient.createNip98AuthHeader(
    url: _usernameReleaseUrl,
    method: 'POST',
    payload: payload,
  );

  if (authHeader == null) {
    Log.error(
      'NIP-98 auth header generation returned null (release: $name)',
      name: 'ProfileRepository.releaseUsername',
      category: LogCategory.auth,
    );
    return const UsernameReleaseError('Nip98 authorization failed');
  }

  try {
    final response = await _httpClient
        .post(
          Uri.parse(_usernameReleaseUrl),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          body: payload,
        )
        .timeout(_nameServerHttpTimeout);

    String? serverError;
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        serverError = data['error'] as String?;
      } on Exception {
        // ignore parse failures
      }
    }

    return switch (response.statusCode) {
      200 => const UsernameReleaseSuccess(),
      401 => UsernameReleaseError(serverError ?? 'Authentication failed'),
      403 => const UsernameReleaseNotOwner(),
      _ => UsernameReleaseError(
        serverError ?? 'Unexpected response: ${response.statusCode}',
      ),
    };
  } on Exception catch (e, st) {
    Log.error(
      'release network error (username: $name)',
      name: 'ProfileRepository.releaseUsername',
      category: LogCategory.api,
      error: e,
      stackTrace: st,
    );
    return const UsernameReleaseNetworkError();
  }
}
```

Note: a `200 released:false` (no_active_name) maps to `UsernameReleaseSuccess` — from the client's perspective "the name is not active" is a satisfied post-condition (nothing to burn), so the deletion may proceed. Document this with a one-line comment on the `200 =>` arm.

- [ ] **Step 5: Run test, verify it passes**

Run: `cd mobile/packages/profile_repository && flutter test test/src/profile_repository_release_test.dart`
Expected: PASS. Then `flutter test` (package) + confirm coverage gate.

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/profile_repository/lib/src/username_release_result.dart \
        mobile/packages/profile_repository/lib/profile_repository.dart \
        mobile/packages/profile_repository/lib/src/profile_repository.dart \
        mobile/packages/profile_repository/test/src/profile_repository_release_test.dart
git commit -m "feat(profile): add releaseUsername() to burn @divine.video handle (#6126)"
```

**→ First real commit in divine-mobile. STOP: draft the PR description for Matt's approval, then push + open the draft PR.**

### Task B2: `getUsernameByPubkey()` in profile_repository

**Files:**
- Modify: `mobile/packages/profile_repository/lib/src/profile_repository.dart` (add `_usernameByPubkeyUrl` const near line 22; add method after `releaseUsername`)
- Test: `mobile/packages/profile_repository/test/src/profile_repository_by_pubkey_test.dart`

**Interfaces:**
- Produces: `Future<String?> getUsernameByPubkey({required String pubkeyHex})` — returns the active display name, or `null` if the pubkey owns no active `@divine.video` name.

- [ ] **Step 1: Write the failing test**

```dart
group('getUsernameByPubkey', () {
  test('returns the display name when found', () async {
    when(() => httpClient.get(any())).thenAnswer((_) async =>
      Response('{"ok":true,"found":true,"name":"alice","canonical":"alice"}', 200));
    expect(
      await repository.getUsernameByPubkey(
        pubkeyHex: '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b',
      ),
      'alice',
    );
  });

  test('returns null when not found', () async {
    when(() => httpClient.get(any())).thenAnswer((_) async =>
      Response('{"ok":true,"found":false}', 200));
    expect(
      await repository.getUsernameByPubkey(
        pubkeyHex: '345352a677feb41d624589f2169278dbd5a25ba940663f2020101d30a09ef96f',
      ),
      isNull,
    );
  });

  test('returns null on http failure', () async {
    when(() => httpClient.get(any())).thenThrow(Exception('socket'));
    expect(
      await repository.getUsernameByPubkey(
        pubkeyHex: '345352a677feb41d624589f2169278dbd5a25ba940663f2020101d30a09ef96f',
      ),
      isNull,
    );
  });
});
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd mobile/packages/profile_repository && flutter test test/src/profile_repository_by_pubkey_test.dart`
Expected: FAIL — method undefined.

- [ ] **Step 3: Implement**

Add const near line 22:
```dart
const _usernameByPubkeyUrl = 'https://names.divine.video/api/username/by-pubkey';
```
Add method:
```dart
/// Returns the active `@divine.video` display name owned by [pubkeyHex], or
/// `null` if the pubkey owns none (or on any lookup failure — callers treat
/// "unknown" as "no owned name" and simply do not offer the burn option).
Future<String?> getUsernameByPubkey({required String pubkeyHex}) async {
  try {
    final response = await _httpClient
        .get(Uri.parse('$_usernameByPubkeyUrl/$pubkeyHex'))
        .timeout(_nameServerHttpTimeout);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['found'] != true) return null;
    return data['name'] as String?;
  } on Exception catch (e, st) {
    Log.warning(
      'by-pubkey lookup failed',
      name: 'ProfileRepository.getUsernameByPubkey',
      category: LogCategory.api,
      error: e,
      stackTrace: st,
    );
    return null;
  }
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `cd mobile/packages/profile_repository && flutter test test/src/profile_repository_by_pubkey_test.dart` → PASS. Then `flutter test` (package) + coverage gate.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/profile_repository/lib/src/profile_repository.dart \
        mobile/packages/profile_repository/test/src/profile_repository_by_pubkey_test.dart
git commit -m "feat(profile): add getUsernameByPubkey() ownership lookup (#6126)"
```

### Task B3: owned-username FutureProvider

**Files:**
- Create: `mobile/lib/providers/owned_divine_username_provider.dart`
- Test: `mobile/test/providers/owned_divine_username_provider_test.dart`

**Interfaces:**
- Consumes: `profileRepositoryProvider` (nullable, gated on `isNostrReadyProvider`), `authServiceProvider.currentPublicKeyHex`.
- Produces: `final ownedDivineUsernameProvider = FutureProvider.autoDispose<String?>(...)` returning the active owned name or null.

- [ ] **Step 1: Write the failing test**

Use `ProviderContainer` with overrides for `profileRepositoryProvider` (a mock returning `getUsernameByPubkey` → 'alice') and `authServiceProvider` (currentPublicKeyHex → a full hex). Assert `await container.read(ownedDivineUsernameProvider.future)` == 'alice'; and null when pubkey is null.

```dart
test('resolves owned name from repository', () async {
  final container = ProviderContainer(overrides: [
    profileRepositoryProvider.overrideWithValue(mockRepo),
    authServiceProvider.overrideWithValue(mockAuth),
  ]);
  addTearDown(container.dispose);
  when(() => mockAuth.currentPublicKeyHex).thenReturn(
    '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b');
  when(() => mockRepo.getUsernameByPubkey(pubkeyHex: any(named: 'pubkeyHex')))
    .thenAnswer((_) async => 'alice');
  expect(await container.read(ownedDivineUsernameProvider.future), 'alice');
});
```

- [ ] **Step 2: Run test, verify it fails.** `cd mobile && flutter test test/providers/owned_divine_username_provider_test.dart` → FAIL (provider undefined).

- [ ] **Step 3: Implement.** (Match the exact provider names for auth/profile repo by reading `mobile/lib/providers/` — `authServiceProvider`, `profileRepositoryProvider`.)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import the existing auth + profile repository providers

/// The active @divine.video username owned by the signed-in user, or null if
/// none / not resolvable. Drives whether the delete flow offers the burn
/// toggle.
final ownedDivineUsernameProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  if (pubkey == null || pubkey.isEmpty) return null;
  final repo = ref.watch(profileRepositoryProvider);
  if (repo == null) return null;
  return repo.getUsernameByPubkey(pubkeyHex: pubkey);
});
```

- [ ] **Step 4: Run test, verify it passes.** → PASS.

- [ ] **Step 5: Commit.**
```bash
git add mobile/lib/providers/owned_divine_username_provider.dart \
        mobile/test/providers/owned_divine_username_provider_test.dart
git commit -m "feat(account): add owned-divine-username provider for burn gate (#6126)"
```

### Task B4: l10n keys + burn checkbox in the delete dialog

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb` (+ mirror to every `app_*.arb`)
- Modify: `mobile/lib/widgets/delete_account_dialog.dart` (`showDeleteAllContentWarningDialog`, line 77 — add optional `ownedUsername` param + a checkbox; change `onConfirm` to `void Function({required bool burnUsername})`)
- Modify: `mobile/lib/screens/settings/nostr_settings_screen.dart` (`_handleDeleteAllContent`, line 271 — read `ownedDivineUsernameProvider`, pass `ownedUsername`)
- Test: `mobile/test/widgets/delete_account_dialog_test.dart`

**Interfaces:**
- Produces: `showDeleteAllContentWarningDialog({required BuildContext context, String? ownedUsername, required void Function({required bool burnUsername}) onConfirm})`.

- [ ] **Step 1: Add l10n keys.** In `app_en.arb`:
```json
"deleteAccountBurnUsernameToggle": "Also permanently give up {username}",
"@deleteAccountBurnUsernameToggle": {
  "description": "Opt-in checkbox in the delete-account dialog to burn the user's @divine.video handle. {username} is like @alice.divine.video.",
  "placeholders": { "username": { "type": "String" } }
},
"deleteAccountBurnUsernameFailed": "Couldn't release your username. Your account was not deleted. Try again, or uncheck the option.",
"@deleteAccountBurnUsernameFailed": {
  "description": "Error shown when the opt-in username burn fails during account deletion."
}
```
Mirror both keys into every other `app_*.arb` (or `_knownUntranslatedDebt`). Run `cd mobile && flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test.** Pump `showDeleteAllContentWarningDialog` inside a `MaterialApp` with `AppLocalizations.localizationsDelegates`/`supportedLocales`. Assert: with `ownedUsername: 'alice'` the checkbox label (resolved from `AppLocalizations`, not hardcoded) is present; with `ownedUsername: null` it is absent; checking it + confirming invokes `onConfirm(burnUsername: true)`.

- [ ] **Step 3: Run test, verify it fails.** `cd mobile && flutter test test/widgets/delete_account_dialog_test.dart` → FAIL.

- [ ] **Step 4: Implement.** Change the `onConfirm` signature to `void Function({required bool burnUsername})`; add a local `bool burnUsername = false` inside the dialog's `StatefulBuilder`; when `ownedUsername != null`, render a `CheckboxListTile` (dark-mode `VineTheme` colors) above the confirm button with label `context.l10n.deleteAccountBurnUsernameToggle('@$ownedUsername.divine.video')`; pass `burnUsername` into `onConfirm`. Update `_DeleteAccountTile._handleDeleteAllContent` to `ref.watch(ownedDivineUsernameProvider).valueOrNull` and pass it as `ownedUsername`, and update its `onConfirm` to accept `{required bool burnUsername}` and forward it to `executeAccountDeletion` (Task B5 adds the param).

- [ ] **Step 5: Run test, verify it passes.** → PASS. Run `flutter test test/l10n/arb_consistency_test.dart`.

- [ ] **Step 6: Commit.**
```bash
git add mobile/lib/l10n/ mobile/lib/widgets/delete_account_dialog.dart \
        mobile/lib/screens/settings/nostr_settings_screen.dart \
        mobile/test/widgets/delete_account_dialog_test.dart
git commit -m "feat(account): add opt-in burn-username checkbox to delete dialog (#6126)"
```

### Task B5: burn-first hard-block wiring in `executeAccountDeletion`

**Files:**
- Modify: `mobile/lib/widgets/delete_account_dialog.dart` (`executeAccountDeletion`, line 261 — add `required bool burnUsername`, `String? ownedUsername`, `required ProfileRepository profileRepository` params; add the burn-first step)
- Modify: `mobile/lib/screens/settings/nostr_settings_screen.dart` (pass `profileRepository` + `burnUsername` + `ownedUsername`)
- Test: `mobile/test/widgets/delete_account_dialog_test.dart` (orchestration group)

**Interfaces:**
- Consumes: `profileRepository.releaseUsername(name:)` (B1), `UsernameReleaseSuccess` (B1).

- [ ] **Step 1: Write the failing orchestration tests.**
  - burn opted-in + `releaseUsername` returns non-success → `deletionService.deleteAccount` is **never** called; an error snackbar with `deleteAccountBurnUsernameFailed` shows.
  - burn opted-in + `releaseUsername` returns `UsernameReleaseSuccess` → proceeds and `deleteAccount` **is** called.
  - burn not opted-in → `releaseUsername` **never** called; existing flow unchanged.

Use mocktail mocks for `AccountDeletionService`, `AuthService`, `ProfileRepository`; `verify`/`verifyNever` on the calls.

- [ ] **Step 2: Run tests, verify they fail.** → FAIL (params/behavior absent).

- [ ] **Step 3: Implement.** Add params to `executeAccountDeletion`. Insert, as the first action inside the `try` (before `deletionService.deleteAccount`):
```dart
if (burnUsername && ownedUsername != null) {
  final releaseResult =
      await profileRepository.releaseUsername(name: ownedUsername);
  if (releaseResult is! UsernameReleaseSuccess) {
    dismissDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.deleteAccountBurnUsernameFailed,
          error: true,
        ),
      );
    }
    return; // hard-block: nothing destroyed
  }
}
```
Wire `_DeleteAccountTile` to pass `profileRepository: ref.read(profileRepositoryProvider)!`, `burnUsername`, `ownedUsername`. (If `profileRepositoryProvider` is null-gated, guard the toggle path so it is non-null whenever `ownedUsername != null`.)

- [ ] **Step 4: Run tests, verify they pass.** → PASS.

- [ ] **Step 5: Full verification.**
```bash
cd mobile && dart format lib/widgets/delete_account_dialog.dart lib/screens/settings/nostr_settings_screen.dart
flutter analyze lib test
flutter test test/widgets/delete_account_dialog_test.dart test/l10n/arb_consistency_test.dart
```

- [ ] **Step 6: Commit.**
```bash
git add mobile/lib/widgets/delete_account_dialog.dart \
        mobile/lib/screens/settings/nostr_settings_screen.dart \
        mobile/test/widgets/delete_account_dialog_test.dart
git commit -m "feat(account): burn username first with hard-block during deletion (#6126)"
```

---

## Self-review (against spec)

- **Spec coverage:** endpoint (A1) ✓; releaseUsername + typed result (B1) ✓; getUsernameByPubkey ownership lookup (B2) ✓; ownership gate provider (B3) ✓; opt-in toggle + copy + l10n (B4) ✓; burn-first hard-block orchestration (B5) ✓; keycast#296/#6127 interactions are documented in the spec, no code ✓.
- **Type consistency:** `UsernameReleaseSuccess/NotOwner/NetworkError/Error` used identically across B1/B5; `releaseUsername({required String name})` and `getUsernameByPubkey({required String pubkeyHex})` consistent across tasks; endpoint response keys (`released`, `reason:'no_active_name'`, `status:'burned'`) consistent A1↔B1.
- **Ordering/dependency:** A1 independent; B1→B5 depend as noted; the mobile toggle renders live (the `/by-pubkey` lookup is already in prod), so A1 (`/release`) must be deployed to prod before shipping a mobile build with the toggle, else an opted-in confirm hard-blocks deletion (unit-tested with mocks).
- **Draft-PR gates:** flagged after A1's first commit and after B1's first commit — draft the PR description for Matt before pushing/opening.
