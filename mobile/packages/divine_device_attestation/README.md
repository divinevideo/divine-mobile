# Divine Device Attestation

Divine's iOS plugin for producing Apple App Attest payloads at video publish
time. The app binds each payload to both the media proof and the publishing
account, and it scopes cached App Attest keys per account.

## Origin and ownership

This package was forked from `app_device_integrity` 1.1.0, originally published
by Bubo Tech, under the license retained in this directory. Upstream has not
released since December 2024, and Divine's implementation now has a different
public API and lifecycle. Divine maintains this package as a private workspace
package rather than overriding the hosted dependency.

## Divine behavior

- The Dart API requires `challengeString` and `keyScope`; `keyScope` identifies
  the publishing account whose cached App Attest key answers the challenge.
- The iOS implementation reuses each account's rate-limited key, resumes one
  generated-but-unattested key before replacing it, and serializes concurrent
  provisioning behind a 30-second watchdog.
- The challenge binds the media proof hash to the publishing pubkey. Cached
  credentials answer later challenges with assertions, and invalid restored
  key identifiers re-provision once without clearing a newer replacement.
- Assertion generation has a 15-second native watchdog above the app's
  10-second attestation budget. Provisioning, retry, and recursive
  re-provisioning retain their own deadlines.

The package is intentionally iOS-only. Divine's Android proof flow uses its
separate hardware-attestation implementation and does not use Play Integrity
through this plugin.

## Verification

From this directory, run:

```sh
flutter analyze
flutter test
```

Native registration changes also require an iOS device or archive build. They
cannot be delivered as a Shorebird patch.
