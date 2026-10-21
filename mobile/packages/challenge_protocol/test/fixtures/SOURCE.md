# Challenge convention v1 fixture provenance

Source repository: https://github.com/divinevideo/divine-challenges

Immutable merged source commit: 49c3e2ee8e9aa3d1a34af042c2edc78b3d2c4de6

Source paths: fixtures/v1/manifest.json, fixtures/v1/events.json,
fixtures/v1/scenarios.json. The files in v1 are verbatim byte copies obtained
with git show at that commit. No fixtures were regenerated for this port.

| File | SHA-256 |
| --- | --- |
| manifest.json | 1f24ca176c6245f203b99e3bf990aa1324de90f7740e3e75d2b1f2e78d4f1659 |
| events.json | 7a070f57f2246ab2897fc5bd7e5442ec5fc698058a2bdf10df6cc124a8858b37 |
| scenarios.json | 003ceae2356b3e5324f21adad253539f68f01eb895530deb366722c723d1d20b |

Schema version: 1. Convention: divine-challenge. All identities, prompts, relay
and media URLs are synthetic. The corpus contains exactly 89 parser cases and
26 replay scenarios; replay runs in both original and reversed event order.

The test loader checks each data file against the hardcoded SHA-256 before JSON
decoding; the manifest's version, convention, synthetic flag and hashes are
checked separately. A changed manifest cannot bless changed fixture bytes.
Future updates require an explicit new canonical source commit and reviewed
hash changes, not a mutable download at test or application runtime.
