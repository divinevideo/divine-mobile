# Delete-account identity + username confirmation — Implementation Plan

> **Partly superseded (2026-09-13).** `ProfileRepository.releaseUsername()`,
> referenced in a test snippet below, was removed from divine-mobile in #9144;
> the live path is the two-phase `POST /api/username/release/prepare`
> handshake. The identity-confirmation design in this plan is unaffected.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Re-derived 2026-07-17 against merged `origin/main`** (PR #6138, username-burn, landed). This plan **extends** the merged `_DeleteAllContentDialog` (which already opens immediately and async-reveals the burn `CheckboxListTile`), it does not rewrite it. Decision A (from review): resolve the **local profile** before opening so the identity + username gate are set up front; the name-server burn lookup stays async per #6138. Decision B: the confirmed-account guard sits at the **top of `executeAccountDeletion`** (before the burn-first step).

**Goal:** On the account-deletion confirmation, show which account is being deleted (avatar + name + username/npub) and require re-typing that account's username (DELETE fallback), bind the deletion to the confirmed account, and correct the overstated deletion copy — all layered onto #6138's burn-enabled dialog.

**Architecture:** A plain `DeleteAccountConfirmation` value object holds the identity + required token, derived in `_DeleteAccountTile` from the account's claimed handle (resolved from the local profile before the dialog opens). `_DeleteAllContentDialog` renders it (identity header + account-specific token) while keeping its async burn toggle. `executeAccountDeletion` verifies the current account still matches the confirmed one and aborts before the burn.

**Tech Stack:** Flutter, Riverpod, `mocktail`, `flutter_test`. Spec: `docs/superpowers/specs/2026-07-16-delete-account-identity-confirmation-design.md`. Issue: #6137.

## Global Constraints

- Run all Flutter commands from `mobile/`.
- Dart 80-column formatting; no raw `Colors.*` / inline `TextStyle` — use `VineTheme.*`.
- All user-facing strings via `context.l10n`; every test `MaterialApp` needs `localizationsDelegates: AppLocalizations.localizationsDelegates` + `supportedLocales: AppLocalizations.supportedLocales`.
- Token = full `displayNip05` (`@name.divine.video` / `name@domain`); match is trim + lowercase + strip one leading `@` (username) or trim + uppercase == `DELETE` (fallback). No bare/short form. Shown == typed == accepted.
- Identity display always shows at least the npub.
- Do not disturb #6138's burn behavior (async `ownedUsernameFuture` reveal, burn-first execution). This plan is additive.
- Conventional-commit messages; commit after each task.

---

### Task 1: l10n copy (additions + subtitle correction)

Adds the identity/gate strings and the account-changed guard message; corrects the tile subtitle. The old prompt key stays (the dialog still uses it) until Task 3.

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` (`_knownUntranslatedDebt`)
- Generated: `mobile/lib/l10n/generated/*`

**Interfaces:**
- Produces getters: `deleteAccountWarningBody`, `deleteAccountConfirmUsernamePrompt`, `deleteAccountConfirmDeletePrompt`, `deleteAccountConfirmationHintUsername`, `deleteAccountAccountChanged`; updated `nostrSettingsDeleteAccountSubtitle`.

- [ ] **Step 1: Add new keys to `app_en.arb`** (near the other `deleteAccount*` keys)

```json
"deleteAccountAccountChanged": "You switched accounts, so nothing was deleted. Reopen delete for the account you want to remove.",
"deleteAccountConfirmDeletePrompt": "To confirm, type:",
"deleteAccountConfirmUsernamePrompt": "To confirm, type your username:",
"deleteAccountConfirmationHintUsername": "Type your username",
"deleteAccountWarningBody": "This permanently deletes your account and all your content from Divine, and sends a deletion request to other Nostr relays. Some relays and clients may still keep copies.",
```

- [ ] **Step 2: Correct the tile subtitle value**

```json
"nostrSettingsDeleteAccountSubtitle": "Permanently delete your account and content from Divine, and request removal from other Nostr relays. Some copies may remain.",
```

- [ ] **Step 3: Allow the new English-only keys as known debt** — in `test/l10n/arb_consistency_test.dart`, set:

```dart
const _knownUntranslatedDebt = <String>{
  'deleteAccountAccountChanged',
  'deleteAccountConfirmDeletePrompt',
  'deleteAccountConfirmUsernamePrompt',
  'deleteAccountConfirmationHintUsername',
  'deleteAccountWarningBody',
};
```

- [ ] **Step 4: Regenerate**

Run: `flutter gen-l10n`
Expected: exit 0; the five new getters exist in `lib/l10n/generated/app_localizations.dart`.

- [ ] **Step 5: Run the ARB consistency test**

Run: `flutter test test/l10n/arb_consistency_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/l10n/app_en.arb mobile/lib/l10n/generated mobile/test/l10n/arb_consistency_test.dart
git commit -m "feat(delete-account): add identity-confirm copy and correct delete-relay overstatement (#6137)"
```

---

### Task 2: `DeleteAccountConfirmation` value object

Pure logic: derives the required token + identifier from the account's claimed handle, and matches typed input.

**Files:**
- Create: `mobile/lib/widgets/delete_account_confirmation.dart`
- Test: `mobile/test/widgets/delete_account_confirmation_test.dart`

**Interfaces:**
- Produces: `class DeleteAccountConfirmation`, factory `DeleteAccountConfirmation({required String pubkeyHex, required String displayName, required String? avatarUrl, required String? handle})`; fields `pubkeyHex`, `displayName`, `avatarUrl`, `identifierLine`, `requiredToken`, `isUsernameConfirmation`; method `bool matches(String input)`.
- Consumes: `NostrKeyUtils.truncateNpub` from `package:openvine/utils/nostr_key_utils.dart`.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/delete_account_confirmation_test.dart`:

```dart
// ABOUTME: Unit tests for DeleteAccountConfirmation token derivation + matching
// ABOUTME: Covers Divine handle, external handle, and no-handle (DELETE) cases

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';

void main() {
  const pubkeyHex =
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

  group(DeleteAccountConfirmation, () {
    group('Divine handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Rabble',
        avatarUrl: null,
        handle: '@rabble.divine.video',
      );

      test('is a username confirmation with the full handle as token', () {
        expect(c.isUsernameConfirmation, isTrue);
        expect(c.requiredToken, equals('@rabble.divine.video'));
        expect(c.identifierLine, equals('@rabble.divine.video'));
      });

      test('matches the exact handle, @-less, and cased forms', () {
        expect(c.matches('@rabble.divine.video'), isTrue);
        expect(c.matches('rabble.divine.video'), isTrue);
        expect(c.matches('  @RABBLE.DIVINE.VIDEO  '), isTrue);
      });

      test('does not match the bare local part or DELETE', () {
        expect(c.matches('rabble'), isFalse);
        expect(c.matches('@rabble'), isFalse);
        expect(c.matches('DELETE'), isFalse);
      });
    });

    group('external handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Alice',
        avatarUrl: null,
        handle: 'alice@example.com',
      );

      test('uses the external handle as token, case-insensitively', () {
        expect(c.isUsernameConfirmation, isTrue);
        expect(c.requiredToken, equals('alice@example.com'));
        expect(c.matches('ALICE@example.com'), isTrue);
        expect(c.matches('alice@example.com '), isTrue);
      });
    });

    group('no handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Wild Otter 7',
        avatarUrl: null,
        handle: null,
      );

      test('falls back to DELETE and shows a truncated npub', () {
        expect(c.isUsernameConfirmation, isFalse);
        expect(c.requiredToken, equals('DELETE'));
        expect(c.identifierLine, startsWith('npub1'));
      });

      test('matches DELETE case-insensitively and trimmed, not a handle', () {
        expect(c.matches('delete'), isTrue);
        expect(c.matches('  DELETE '), isTrue);
        expect(c.matches('rabble.divine.video'), isFalse);
      });
    });

    test('empty handle is treated as no handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'X',
        avatarUrl: null,
        handle: '',
      );
      expect(c.isUsernameConfirmation, isFalse);
      expect(c.requiredToken, equals('DELETE'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/delete_account_confirmation_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `mobile/lib/widgets/delete_account_confirmation.dart`:

```dart
// ABOUTME: Value object for the delete-account confirmation dialog
// ABOUTME: Derives the required confirm token (username or DELETE) and matches input

import 'package:openvine/utils/nostr_key_utils.dart';

const String _deleteToken = 'DELETE';

/// Identity + confirm-token for the account-deletion dialog.
///
/// [handle] is the account's claimed `displayNip05` (full form, e.g.
/// `@name.divine.video` or `name@domain`) or `null`/empty when the account has
/// none. When present it becomes the required token; otherwise the token is
/// `DELETE` and the shown identifier is a truncated npub.
class DeleteAccountConfirmation {
  const DeleteAccountConfirmation._({
    required this.pubkeyHex,
    required this.displayName,
    required this.avatarUrl,
    required this.identifierLine,
    required this.requiredToken,
    required this.isUsernameConfirmation,
  });

  factory DeleteAccountConfirmation({
    required String pubkeyHex,
    required String displayName,
    required String? avatarUrl,
    required String? handle,
  }) {
    final hasHandle = handle != null && handle.isNotEmpty;
    return DeleteAccountConfirmation._(
      pubkeyHex: pubkeyHex,
      displayName: displayName,
      avatarUrl: avatarUrl,
      identifierLine: hasHandle
          ? handle
          : NostrKeyUtils.truncateNpub(pubkeyHex),
      requiredToken: hasHandle ? handle : _deleteToken,
      isUsernameConfirmation: hasHandle,
    );
  }

  final String pubkeyHex;
  final String displayName;
  final String? avatarUrl;
  final String identifierLine;
  final String requiredToken;
  final bool isUsernameConfirmation;

  /// Whether [input] satisfies the confirmation.
  ///
  /// Username: case-insensitive, trimmed, leading `@` optional.
  /// Fallback: case-insensitive, trimmed, equals `DELETE`.
  bool matches(String input) {
    if (isUsernameConfirmation) {
      return _normalizeHandle(input) == _normalizeHandle(requiredToken);
    }
    return input.trim().toUpperCase() == _deleteToken;
  }

  static String _normalizeHandle(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/delete_account_confirmation_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/widgets/delete_account_confirmation.dart test/widgets/delete_account_confirmation_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/widgets/delete_account_confirmation.dart mobile/test/widgets/delete_account_confirmation_test.dart
git commit -m "feat(delete-account): DeleteAccountConfirmation token value object (#6137)"
```

---

### Task 3: Extend the dialog with identity + username gate

Adds a required `confirmation` param, renders `_DeleteIdentityHeader` + the account-specific token/prompt/hint, keeps the async burn toggle, and retires the old prompt key.

**Files:**
- Modify: `mobile/lib/widgets/delete_account_dialog.dart` (`showDeleteAllContentWarningDialog`, `_DeleteAllContentDialog`; add `_DeleteIdentityHeader`)
- Modify: `mobile/lib/l10n/app_*.arb` (retire `deleteAccountFinalConfirmationBody`)
- Modify: `mobile/test/widgets/delete_account_dialog_test.dart`

**Interfaces:**
- Consumes: `DeleteAccountConfirmation` (Task 2); l10n getters (Task 1); `UserAvatar` from `package:openvine/widgets/user_avatar.dart`.
- Produces: `showDeleteAllContentWarningDialog({required BuildContext context, required DeleteAccountConfirmation confirmation, required void Function({required bool burnUsername, ({String name, String canonical})? ownedUsername}) onConfirm, required Future<({String name, String canonical})?> ownedUsernameFuture})`.

- [ ] **Step 1: Update the dialog tests (write failing)**

In `test/widgets/delete_account_dialog_test.dart`, add imports and confirmation fixtures near the top:

```dart
import 'package:openvine/widgets/delete_account_confirmation.dart';

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

DeleteAccountConfirmation _deleteFallback() => DeleteAccountConfirmation(
  pubkeyHex: _pubkeyHex,
  displayName: 'Wild Otter 7',
  avatarUrl: null,
  handle: null,
);

DeleteAccountConfirmation _divineUsername() => DeleteAccountConfirmation(
  pubkeyHex: _pubkeyHex,
  displayName: 'Rabble',
  avatarUrl: null,
  handle: '@rabble.divine.video',
);
```

Thread a `confirmation` param through the existing `_showDialog` helper (default `_deleteFallback()`) and every `showDeleteAllContentWarningDialog(...)` call site in the test, e.g.:

```dart
Future<void> _showDialog(
  WidgetTester tester, {
  DeleteAccountConfirmation? confirmation,
  void Function({required bool burnUsername, ...})? onConfirm,
  ({String name, String canonical})? ownedUsername,
}) async {
  // ... inside the builder:
  onPressed: () => showDeleteAllContentWarningDialog(
    context: context,
    confirmation: confirmation ?? _deleteFallback(),
    ownedUsernameFuture: Future.value(ownedUsername),
    onConfirm: onConfirm ?? ({required burnUsername, ownedUsername}) {},
  ),
}
```

The existing "confirmation input" group now runs under `_deleteFallback()` (DELETE still enables). Add a username group:

```dart
group('username confirmation', () {
  testWidgets('shows the identity (name + handle)', (tester) async {
    await _showDialog(tester, confirmation: _divineUsername());
    expect(find.text('Rabble'), findsOneWidget);
    expect(find.text('@rabble.divine.video'), findsWidgets);
  });

  testWidgets('typing DELETE does not enable the button', (tester) async {
    await _showDialog(tester, confirmation: _divineUsername());
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete All Content'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('typing the handle enables the button', (tester) async {
    await _showDialog(tester, confirmation: _divineUsername());
    await tester.enterText(find.byType(TextField), '@rabble.divine.video');
    await tester.pump();
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete All Content'),
    );
    expect(button.onPressed, isNotNull);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/delete_account_dialog_test.dart`
Expected: FAIL — `showDeleteAllContentWarningDialog` has no `confirmation` param.

- [ ] **Step 3: Add the `confirmation` param + identity header, swap token/prompt/hint**

In `delete_account_dialog.dart`, add imports:

```dart
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/user_avatar.dart';
```

Add `required DeleteAccountConfirmation confirmation` to `showDeleteAllContentWarningDialog` and pass it to `_DeleteAllContentDialog`. Add the field + constructor param to `_DeleteAllContentDialog`.

In `_DeleteAllContentDialogState`: delete `static const _requiredText = 'DELETE';`, and change `canConfirm`:

```dart
final owned = _ownedUsername;
final c = widget.confirmation;
final canConfirm = c.matches(_confirmationController.text);
```

At the top of the `content` `Column.children`, insert:

```dart
_DeleteIdentityHeader(confirmation: c),
const SizedBox(height: 16),
```

Change the warning body text to `context.l10n.deleteAccountWarningBody`. Change the prompt (the `Text` currently showing the body) — actually replace the single body `Text` with the warning body above; then add the prompt line:

```dart
Text(
  c.isUsernameConfirmation
      ? context.l10n.deleteAccountConfirmUsernamePrompt
      : context.l10n.deleteAccountConfirmDeletePrompt,
  style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
),
const SizedBox(height: 8),
```

Replace the `const Text(_requiredText, ...)` monospace token with:

```dart
Text(
  c.requiredToken,
  style: const TextStyle(
    color: VineTheme.error,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
  ),
),
```

On the `TextField`: set `textCapitalization: c.isUsernameConfirmation ? TextCapitalization.none : TextCapitalization.characters` and `hintText: c.isUsernameConfirmation ? context.l10n.deleteAccountConfirmationHintUsername : context.l10n.deleteAccountConfirmationHint`.

Leave the `if (owned != null) ...[ CheckboxListTile(...) ]` burn block unchanged.

Add the header widget at the end of the file:

```dart
class _DeleteIdentityHeader extends StatelessWidget {
  const _DeleteIdentityHeader({required this.confirmation});

  final DeleteAccountConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          imageUrl: confirmation.avatarUrl,
          name: confirmation.displayName,
          placeholderSeed: confirmation.pubkeyHex,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                confirmation.displayName,
                style: VineTheme.titleMediumFont(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                confirmation.identifierLine,
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Retire the old prompt key**

Run:
```bash
sed -i '' '/"deleteAccountFinalConfirmationBody":/d' mobile/lib/l10n/app_*.arb
cd mobile && flutter gen-l10n && cd ..
```

- [ ] **Step 5: Verify no stale references, run tests**

Run: `rg -n "deleteAccountFinalConfirmationBody|_requiredText" mobile/lib`
Expected: no matches.

Run: `flutter test test/widgets/delete_account_dialog_test.dart test/l10n/arb_consistency_test.dart`
Expected: PASS (including #6138's burn-toggle tests, untouched).

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/widgets/delete_account_dialog.dart test/widgets/delete_account_dialog_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/widgets/delete_account_dialog.dart mobile/lib/l10n mobile/test/widgets/delete_account_dialog_test.dart
git commit -m "feat(delete-account): show identity + require username in confirm dialog (#6137)"
```

---

### Task 4: Bind deletion to the confirmed account (guard before burn)

`executeAccountDeletion` gains `confirmedPubkey`; if the live account no longer matches, it aborts **before** the burn-first step.

**Files:**
- Modify: `mobile/lib/widgets/delete_account_dialog.dart` (`executeAccountDeletion`)
- Modify: `mobile/test/widgets/delete_account_dialog_test.dart`

**Interfaces:**
- Produces: `executeAccountDeletion({..., required String confirmedPubkey})` — aborts with the `deleteAccountAccountChanged` snackbar when `authService.currentPublicKeyHex != confirmedPubkey`, before burn or delete.

- [ ] **Step 1: Write the failing test** — add to the `executeAccountDeletion` group:

```dart
testWidgets('aborts before burn when the account changed', (tester) async {
  final deletionService = _MockAccountDeletionService();
  final authService = _MockAuthService();
  final profileRepository = _MockProfileRepository();
  when(() => authService.currentPublicKeyHex).thenReturn('now_a_different_pk');

  late BuildContext ctx;
  await tester.pumpWidget(
    _wrapWithRouter(
      Builder(builder: (context) {
        ctx = context;
        return const Scaffold(body: SizedBox.shrink());
      }),
    ),
  );

  await executeAccountDeletion(
    context: ctx,
    deletionService: deletionService,
    authService: authService,
    profileRepository: profileRepository,
    burnUsername: true,
    ownedUsername: (name: 'rabble', canonical: 'rabble'),
    confirmedPubkey: _pubkeyHex,
  );
  await tester.pumpAndSettle();

  verifyNever(() => profileRepository.releaseUsername(name: any(named: 'name')));
  verifyNever(() => deletionService.deleteAccount(
    onProgress: any(named: 'onProgress'),
  ));
});
```

(Use the same `_MockProfileRepository` the merged file already declares for the burn tests; add `confirmedPubkey: _pubkeyHex` to the other `executeAccountDeletion(...)` calls in this group so they compile.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/delete_account_dialog_test.dart --plain-name "aborts before burn"`
Expected: FAIL — no `confirmedPubkey` param.

- [ ] **Step 3: Add the parameter + guard**

Add `required String confirmedPubkey` to `executeAccountDeletion`. Capture the message with the other pre-await captures:

```dart
final accountChangedText = context.l10n.deleteAccountAccountChanged;
```

As the **first statement inside the `try`** (before the `if (burnUsername)` block):

```dart
if (authService.currentPublicKeyHex != confirmedPubkey) {
  Log.warning(
    'Deletion aborted: signed-in account changed since confirmation',
    name: screenName,
    category: LogCategory.auth,
  );
  dismissDialog();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(accountChangedText, error: true),
    );
  }
  return;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/delete_account_dialog_test.dart`
Expected: PASS (guard test + existing burn tests).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/widgets/delete_account_dialog.dart test/widgets/delete_account_dialog_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/widgets/delete_account_dialog.dart mobile/test/widgets/delete_account_dialog_test.dart
git commit -m "feat(delete-account): abort deletion if the account changed after confirm (#6137)"
```

---

### Task 5: Resolve identity before confirm + wire the tile

`_DeleteAccountTile` resolves the local profile (bounded wait, existing `_ProgressOverlay`), builds the `DeleteAccountConfirmation`, and threads `confirmedPubkey` — while keeping #6138's async `ownedUsernameFuture` for the burn toggle.

**Files:**
- Modify: `mobile/lib/screens/settings/nostr_settings_screen.dart` (`_DeleteAccountTile._handleDeleteAllContent`, imports, a timeout const)
- Test: `mobile/test/screens/settings/nostr_settings_screen_delete_tile_test.dart`

**Interfaces:**
- Consumes: `fetchUserProfileProvider(pubkey).future` → `Future<UserProfile?>`; `DeleteAccountConfirmation` (Task 2); `showDeleteAllContentWarningDialog` + `executeAccountDeletion` (Tasks 3/4); `models.UserProfile` getters `bestDisplayName` / `picture` / `displayNip05` / static `defaultDisplayNameFor`. Keeps the existing `ownedDivineUsernameProvider` / `profileRepositoryProvider` reads.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/screens/settings/nostr_settings_screen_delete_tile_test.dart` (mirror the tile logic; assert the resolved handle appears in the opened dialog):

```dart
// ABOUTME: The delete-account tile resolves identity before opening the dialog
// ABOUTME: and shows the account's username, not a bare npub.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

class _MockAuthService extends Mock implements AuthService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  testWidgets('resolves the profile and shows the username in the dialog', (
    tester,
  ) async {
    final auth = _MockAuthService();
    when(() => auth.currentPublicKeyHex).thenReturn(_pubkeyHex);

    final profile = UserProfile(
      pubkey: _pubkeyHex,
      name: 'Rabble',
      nip05: '_@rabble.divine.video',
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _openFromTile(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          fetchUserProfileProvider(_pubkeyHex)
              .overrideWith((ref) async => profile),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rabble'), findsOneWidget);
    expect(find.text('@rabble.divine.video'), findsWidgets);
  });
}

// Mirrors _DeleteAccountTile._handleDeleteAllContent's identity resolution.
Future<void> _openFromTile(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final pubkey = container.read(authServiceProvider).currentPublicKeyHex!;
  final profile = await container.read(fetchUserProfileProvider(pubkey).future);
  if (!context.mounted) return;
  await showDeleteAllContentWarningDialog(
    context: context,
    confirmation: DeleteAccountConfirmation(
      pubkeyHex: pubkey,
      displayName: profile?.bestDisplayName ??
          UserProfile.defaultDisplayNameFor(pubkey),
      avatarUrl: profile?.picture,
      handle: profile?.displayNip05,
    ),
    ownedUsernameFuture: Future.value(null),
    onConfirm: ({required burnUsername, ownedUsername}) {},
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings/nostr_settings_screen_delete_tile_test.dart`
Expected: FAIL until imports/logic compile.

- [ ] **Step 3: Update imports** in `nostr_settings_screen.dart` — hide the thin `UserProfile`, add models + the profile provider + the value object:

```dart
import 'package:openvine/services/auth_service.dart' hide UserProfile;
```
add:
```dart
import 'package:models/models.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
```

> If the analyzer flags `AuthState`/`AuthService` as hidden, mirror the exact `hide`/`show` form used at `settings_screen.dart:39`.

- [ ] **Step 4: Add a timeout const + rewrite `_handleDeleteAllContent`**

After the imports:
```dart
const Duration _profileResolveTimeout = Duration(seconds: 3);
```

Replace `_DeleteAccountTile._handleDeleteAllContent` with (keeps #6138's async burn lookup, adds the pre-open local-profile resolve + `confirmedPubkey`):

```dart
  Future<void> _handleDeleteAllContent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);
    final profileRepository = ref.read(profileRepositoryProvider);
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) return;

    // Burnable-handle lookup stays async (revealed inside the dialog).
    final ownedUsernameFuture = ref.read(ownedDivineUsernameProvider.future);

    // Resolve the local profile up front so the identity + username gate are
    // ready when the dialog opens (Decision A). Fast: Drift cache. Bounded so
    // an offline miss degrades to npub + DELETE instead of hanging.
    final overlay = _ProgressOverlay.show(context);
    UserProfile? profile;
    try {
      profile = await ref
          .read(fetchUserProfileProvider(pubkey).future)
          .timeout(_profileResolveTimeout, onTimeout: () => null);
    } catch (_) {
      profile = null;
    } finally {
      overlay.dismiss();
    }
    if (!context.mounted) return;

    final confirmation = DeleteAccountConfirmation(
      pubkeyHex: pubkey,
      displayName:
          profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
      avatarUrl: profile?.picture,
      handle: profile?.displayNip05,
    );

    await showDeleteAllContentWarningDialog(
      context: context,
      confirmation: confirmation,
      ownedUsernameFuture: ownedUsernameFuture,
      onConfirm:
          ({
            required bool burnUsername,
            ({String name, String canonical})? ownedUsername,
          }) => executeAccountDeletion(
            context: context,
            deletionService: deletionService,
            authService: authService,
            profileRepository: profileRepository,
            burnUsername: burnUsername,
            ownedUsername: ownedUsername,
            confirmedPubkey: pubkey,
            screenName: 'NostrSettingsScreen',
          ),
    );
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/screens/settings/nostr_settings_screen_delete_tile_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/screens/settings/nostr_settings_screen.dart test/screens/settings/nostr_settings_screen_delete_tile_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/settings/nostr_settings_screen.dart mobile/test/screens/settings/nostr_settings_screen_delete_tile_test.dart
git commit -m "feat(delete-account): resolve identity before confirm and bind the tile (#6137)"
```

---

### Task 6: Full verification sweep

- [ ] **Step 1: Analyze** — `flutter analyze lib test integration_test` → `No issues found!`
- [ ] **Step 2: Run every touched suite** —
```bash
flutter test \
  test/widgets/delete_account_confirmation_test.dart \
  test/widgets/delete_account_dialog_test.dart \
  test/screens/settings/nostr_settings_screen_delete_tile_test.dart \
  test/l10n/arb_consistency_test.dart
```
Expected: all PASS (including #6138's burn tests in the dialog file).
- [ ] **Step 3: Format** — `dart format lib/widgets/delete_account_confirmation.dart lib/widgets/delete_account_dialog.dart lib/screens/settings/nostr_settings_screen.dart` → commit any changes.
- [ ] **Step 4: Rebase + push** —
```bash
git fetch origin && git rebase origin/main
git push --force-with-lease
```
then mark PR #6158 ready for review.

---

## Self-Review

**Spec coverage:** identity display → Task 3 `_DeleteIdentityHeader`; account-specific token + DELETE fallback + strict full-form → Task 2; resolve-before-confirm (Decision A) → Task 5; bind + abort-before-burn (Decision B) → Task 4; NIP-05-only token → Task 2; copy correction + tile subtitle → Task 1, old key retired → Task 3; claimed handle (no verification) → Task 5 reads `displayNip05`; three account shapes + guard + resolve → Tasks 2/3/4/5. #6138 burn behavior untouched (async reveal, burn-first) → verified in Tasks 3/6.

**Placeholder scan:** none — every code step is concrete.

**Type consistency:** `DeleteAccountConfirmation({pubkeyHex, displayName, avatarUrl, handle})` + fields used identically across Tasks 2/3/5. `executeAccountDeletion({..., confirmedPubkey})` defined in Task 4, called in Task 5. Dialog `onConfirm({required bool burnUsername, ({String name, String canonical})? ownedUsername})` matches the merged #6138 signature.

**Open verification for the implementer (flagged, not placeholders):**
- Task 5 test constructs `models.UserProfile(pubkey:, name:, nip05:)` — confirm the constructor's required/named params and adjust the fixture if it differs; the asserted behavior (name + handle render) is the point.
- Confirm `_ProgressOverlay` still exists in the merged `nostr_settings_screen.dart` (present for `_RemoveKeysTile`); reuse it.
- Confirm `_MockProfileRepository` is already declared in the merged `delete_account_dialog_test.dart` (Task 4 reuses it).
