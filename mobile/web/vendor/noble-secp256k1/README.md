# Vendored: @noble/secp256k1 3.2.0

`index.js` and `LICENSE` are copied byte-for-byte from the npm tarball
`@noble/secp256k1@3.2.0` (MIT, Paul Miller). Do not edit them.

- Tarball integrity (npm `dist.integrity`):
  `sha512-Z3ZAWOTxJ0EuTuZTi7Y69iK7GgrLHh8sgm45lVDhg/b3Nk1TpAiKhick2KkZisHuupeepSkyIydN/J459SdX1w==`
- `index.js` sha256:
  `ba5aadb469e9208f2da1c9878ab6bb93d2c894f84e6c7ebf9dbf9462741b9fb7`
- Published by GitHub Actions through npm trusted publishing, approved by
  the maintainer.

It is served from our own origin rather than a CDN, so a third party cannot
change the code that decides whether a Nostr event's signature is valid.

`../../nostr_crypto.js` imports it and exposes `globalThis.divineNostrCrypto`,
which the web build's relay pool uses to check event signatures. BIP-340
verification runs on the browser's native `BigInt`, with SHA-256 from
WebCrypto, instead of Dart's software `BigInt` (about 89 ms per check once
compiled to JavaScript).

To upgrade: download the new tarball, check its `dist.integrity` against
`https://registry.npmjs.org/@noble/secp256k1/<version>`, copy `index.js` and
`LICENSE` here, and update the hashes and version above.
