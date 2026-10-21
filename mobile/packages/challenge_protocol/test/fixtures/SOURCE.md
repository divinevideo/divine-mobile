# Challenge convention v1 fixture provenance

Source repository: https://github.com/divinevideo/divine-challenges

Immutable source commit: 5800cf866d7a5b1a1fb38201f58044e4dc024a3d

Source paths: fixtures/v1/manifest.json, fixtures/v1/events.json,
fixtures/v1/scenarios.json. The files in v1 are verbatim byte copies obtained
with git show at that commit. No fixtures were regenerated for this port.

| File | SHA-256 |
| --- | --- |
| events.json | aef551d33e5f95004d5c3104be11959ae5e6c24ca2a30b07ef9566161b979699 |
| scenarios.json | 7e455dadfdac2430b9c454842358d8868f8bfd0ace499b2c6fcb1fb0d9986efa |

Schema version: 1. Convention: divine-challenge. All identities, prompts, relay
and media URLs are synthetic. The corpus contains exactly 29 parser cases and
22 replay scenarios; replay runs in both original and reversed event order.

The test loader checks each data file against the hardcoded SHA-256 before JSON
decoding; the manifest's version, convention, synthetic flag and hashes are
checked separately. A changed manifest cannot bless changed fixture bytes.
Future updates require an explicit new canonical source commit and reviewed
hash changes, not a mutable download at test or application runtime.
