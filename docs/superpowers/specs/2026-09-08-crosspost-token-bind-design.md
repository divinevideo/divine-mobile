# Bind the ATProto crosspost client token; keep secrets out of errors (#8825) — design

**Problem.** `CrosspostApiClient` (the Keycast ATProto/Bluesky client) read its bearer
token straight from the OAuth session (`_oauthClient.getSession().accessToken`) — an
unbound token, not re-validated against the active account across the await, so an
account switch mid-flight could authenticate a request as the wrong account. Its
exception `toString()` also emitted the raw message, which can carry a connection URL
or token into logs. Same latent gaps #8705 fixed for the sibling `CrosspostingApiClient`.

## Approach (mirrors the merged #8705 sibling)

1. **Bind the token.** Replace the `KeycastOAuth oauthClient` dependency (used only for
   the token) with an injected `CrosspostAccessTokenReader = Future<String?> Function()`.
   `_authHeaders` awaits the reader instead of `getSession().accessToken`. The provider
   passes `authService.getBoundDivineAccessToken`, which captures the owner pubkey
   before the await and re-checks it after, refusing on mismatch — closing the
   account-switch TOCTOU.
2. **Scrub the exception.** `CrosspostApiException.toString()` now omits the raw
   `message` (keeps `statusCode` + `kind`), mirroring `CrosspostingApiException`.
3. **Tests (TDD):** a spy reader pinned as the token source (goes red if reverted to an
   unbound `getSession()` read — the AC's mutation check); a test that `toString()`
   does not leak the message.

## Files

`mobile/lib/services/crosspost_api_client.dart` (typedef + constructor + `_authHeaders`
+ exception `toString`), `mobile/lib/providers/upload_media_providers.dart` (wire the
bound reader), `mobile/test/services/crosspost_api_client_test.dart`.
