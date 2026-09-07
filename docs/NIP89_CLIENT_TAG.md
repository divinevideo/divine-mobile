# NIP-89 Client Tag

Divine emits a canonical NIP-89 `client` tag on publishable events unless the
user opts out in Nostr settings.

Current identity:

- `name`: `Divine`
- `handler pubkey`: `d95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540`
- `d`: `divine-mobile`
- `relay hint`: `wss://relay.divine.video`

Tag shape:

```json
["client", "Divine", "31990:d95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540:divine-mobile", "wss://relay.divine.video"]
```

The app injects this through both `nostr_client`'s publish preparation and
`SignerFactory.createAndSignEvent`, with both paths skipping protocol-sensitive
kinds. That includes every NIP-59 outer wrapper — both the `kind:1059` gift
wrap and the ephemeral `kind:21059` — because those are broadcast in the clear
and a public `client` tag on one would undercut NIP-17's metadata guarantee.

## Handler event

`mobile/tools/build_nip89_handler_event.dart` builds the Divine `kind:31990`
handler event. Without any environment variables it prints the unsigned event
JSON. With `NIP89_HANDLER_NSEC` set to the matching handler key, it signs the
event, and `--publish` also sends it to `wss://relay.divine.video`.

Examples:

```bash
cd mobile
dart run tools/build_nip89_handler_event.dart
```

```bash
cd mobile
NIP89_HANDLER_NSEC=nsec1... dart run tools/build_nip89_handler_event.dart --publish
```

If the handler identity changes, update `Nip89ClientTag` in
`packages/nostr_client/lib/src/nip89_client_tag.dart` and republish the handler
event before shipping a client that references the new coordinate.
