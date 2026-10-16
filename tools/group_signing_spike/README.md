# Throwaway Nostr threshold-signing spike

This is an isolated feasibility test, not an app package or a production signer.
It generates fresh dealerless FROST keys, signs real NIP-01 event hashes through
Dart → flutter_rust_bridge → ZF Rust, and verifies ordinary BIP-340 signatures.
No full group secret is constructed, persisted, logged or exported.

Seven tests cover 2-of-2, every 2-of-3 pair, 3-of-3, insufficient signing quorum,
incomplete DKG, changed message/content rejection, immutable approval bytes,
distinct fresh nonce commitments, one-use approval rejection, and the tested
FROST API rejecting threshold one. That boundary does not imply the product
requires two human approvals: normal content uses one authorized admin.
The tests use Bitcoin Core secp256k1 through coinlib, bip340 0.3.0, and the actual
Divine Event class imported directly from its source. They simulate participants
in one process; confidential delivery and broadcast agreement are supplied by the
harness. They do not prove secure network ceremonies or physical-device operation.

## Reproduce on macOS ARM64

Requires Dart >=3.12, Rust, Git, CMake and an Apple C toolchain. The app itself
requires Dart >=3.13; use a compatible Flutter SDK for app checks. Run here:

```sh
dart pub get --enforce-lockfile
git clone https://github.com/peercoin/frosty.git .dart_tool/frosty-source
git -C .dart_tool/frosty-source checkout --detach 0457225a54dd36dcfff86268206f16cc42f59a07
cargo build --locked --manifest-path .dart_tool/frosty-source/frosty_flutter/rust/Cargo.toml
mkdir -p build
cp .dart_tool/frosty-source/frosty_flutter/rust/target/debug/libfrosty_rust.dylib build/
git clone https://github.com/bitcoin-core/secp256k1.git .dart_tool/secp256k1-source
git -C .dart_tool/secp256k1-source checkout --detach e3a885d42a7800c1ccebad94ad1e2b82c4df5c65
cmake -S .dart_tool/secp256k1-source -B .dart_tool/secp256k1-build -DBUILD_SHARED_LIBS=ON -DSECP256K1_ENABLE_MODULE_RECOVERY=ON -DSECP256K1_BUILD_TESTS=OFF -DSECP256K1_BUILD_EXHAUSTIVE_TESTS=OFF -DSECP256K1_BUILD_BENCHMARK=OFF
cmake --build .dart_tool/secp256k1-build -j 4
cp .dart_tool/secp256k1-build/src/libsecp256k1.2.dylib build/libsecp256k1.dylib
dart analyze
dart test --reporter expanded
```

`build/` and `.dart_tool/` are ignored. The native release lock resolves
frost-secp256k1-tr **2.2.0** and flutter_rust_bridge **2.11.1**, not current 3.0.0.
The stock coinlib build script needed missing `autoreconf`; CMake above builds
the same pinned Bitcoin Core source without changing the machine's packages.

Frosty 5 requires Dart 3.13 and coinlib 6 / pointycastle 4. The app's locked
bip340 0.3.0 uses pointycastle 3.9.1. This spike deliberately uses the compatible
Frosty 4 and verifier versions without dependency overrides or mobile changes.

To export a freshly generated **public signed event only**, set
`GROUP_SIGNING_SPIKE_EVENT_PATH` to a file outside version control while running
the tests. No shares or nonce material are exported. The event is an empty public
kind-30005 list with synthetic identity and prototype metadata.

Approval guards here are process-local. The upstream native wrapper does not
consume nonces on sign and exposes share bytes to Dart; a product bridge needs
opaque share handles and a durable consumption/abort policy. Never reuse this
harness with an existing identity or treat its in-memory delivery as NIP-17.

See the [proposed design](../../docs/superpowers/specs/2026-10-16-group-signed-events-design.md)
for ownership, transport, recovery and remaining acceptance gates.

## Local relay verification

A stock strfry relay rejected the damaged signature, accepted the threshold event
and returned it to a normal ID subscription; Divine's SDK verified the read-back.
This is a relay round-trip, **not** evidence of visible rendering in another app.
The local test container was stopped and removed after verification.

To repeat, export a public event as described above, create an empty database
folder and use a dedicated strfry config with no write-policy plugin:

```sh
mkdir -p .dart_tool/relay-db
cat > .dart_tool/relay.conf <<'CONFIG'
db = "/app/strfry-db/"
relay {
  bind = "0.0.0.0"
  port = 7777
}
CONFIG
docker run -d --name divine-group-signing-spike -p 127.0.0.1::7777 -v "$PWD/.dart_tool/relay-db:/app/strfry-db" -v "$PWD/.dart_tool/relay.conf:/etc/strfry.conf:ro" dockurr/strfry@sha256:599ab3500dbfbe6cb78c668e1892cd9802c192d066df4660e8e3175034a8344d
docker port divine-group-signing-spike 7777
```

Use the printed loopback port below, then clean up only this test container:

```sh
dart run bin/relay_round_trip.dart ws://127.0.0.1:<printed-port> .dart_tool/public-event.json
docker stop divine-group-signing-spike
docker rm divine-group-signing-spike
```

Validation on 2026-10-16: seven spike tests, `dart analyze`, the relay probe,
`flutter analyze --no-pub lib test integration_test tools` and all 12 tests in
`mobile/packages/nostr_sdk/test/unit/event_test.dart` passed. Flutter commands
used Flutter 3.47.2 / Dart 3.13.2. The system-default Dart was 3.12.2.
