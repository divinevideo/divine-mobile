// ABOUTME: Shared synthetic pubkeys for test fixtures.
// ABOUTME: Never use a real personal key as test data.

/// A clearly-synthetic 64-char hex pubkey for use as a generic fixture
/// identity in tests (test video author, mock current-user pubkey, and
/// similar).
///
/// Replaces the real personal key that #5963 removed from production code
/// but which lingered as scattered literals across test files
/// (#6083 / support-trust-safety#184). `deadbeef` repeated is unmistakably
/// fake yet a valid lowercase 64-char hex that round-trips through npub
/// encode/decode.
const syntheticTestPubkey =
    'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

/// A second clearly-synthetic pubkey, distinct from [syntheticTestPubkey], for
/// tests that need two different fixture identities (e.g. "me" vs "not me").
const syntheticOtherTestPubkey =
    'cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe';

/// The npub encoding of [syntheticTestPubkey], written out as a literal.
///
/// Tests that assert on a route or identifier built from a pubkey compare
/// against this constant instead of re-running `NostrKeyUtils.encodePubKey`.
/// Recomputing the encoder on both sides of an `expect` is `f(x) == f(x)`: it
/// passes for any encoder, including one that returns the raw hex. A literal
/// makes the assertion independent, so an encoder regression fails the test
/// rather than moving the expectation with it.
const syntheticTestNpub =
    'npub1m6kmam774klwlh4dhmhaatd7al02m0h0m6kmam774klwlh4dhmhslezuz0';
