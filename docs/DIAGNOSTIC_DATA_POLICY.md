# Diagnostic Data Policy

This policy covers user-initiated bug reports, feature requests, content
reports, and support flows that collect mobile diagnostics.

## Public Support Flows

Bug reports, feature requests, and content reports submitted through Zendesk
may be mirrored into public GitHub issues by the Zendesk-to-GitHub bridge
(`divinevideo/divine-zd-to-gh`). Since 25 September 2026 the bridge publishes
the report and keeps diagnostics and account identity in Zendesk, as decided in
#2636 and #6940.

Reaches the public GitHub issue:

- User-entered subject, description, reproduction steps, and expected behavior.
- App version and coarse platform/device details needed for triage.
- Error counts.
- How many attachments the ticket had, and their types.

Stays in Zendesk (the bridge removes it from the public issue):

- The recent-log summary and any other log output.
- The signed-in account identifier, and any other Nostr identifier, whole or
  truncated.
- The list of screens visited before the report.
- The Zendesk requester's display name.
- Attachment links.

The client still treats everything it sends as potentially public. The bridge is
a second layer, not a reason to send more.

Zendesk requester identity fields are intentionally not redacted: name, email,
and `external_id` must stay intact so Zendesk can connect the ticket to the
right requester. Do not mirror those fields into public GitHub issues unless
the mirror owner has explicitly accepted that exposure.

Public Zendesk/GitHub payloads must not include:

- Nostr private keys, bearer tokens, passwords, or secret values.
- Email addresses collected incidentally from logs or typed fields.
- Device names, host names, or computer names.
- Full raw log archives or unbounded diagnostic dumps.
- Screenshots or attachments that show private keys, recovery material,
  tokens, email addresses, or other secrets. Attachments cannot be made safe by
  regex redaction, so users must avoid including sensitive images.

The mobile client enforces this for tickets it submits itself, by sanitizing
diagnostics before they leave `BugReportService` and by sanitizing user-entered
Zendesk fields at the `ZendeskSupportService` submission boundary. Text composed
inside the native Zendesk SDK screens does not cross that boundary; see
[Residual Risks](#residual-risks).

A content report has three destinations, not one: the Zendesk ticket, the
kind-1984 Nostr event published to relays, and the moderation DM. The
kind-1984 event is the most exposed of the three - world-readable, permanent
and unretractable - so `ContentReportingService.reportContent` redacts the
reporter's details and additional context once at the entry point, before any
of the three projections is built, and the moderation DM redacts the same
details before sending.

The email redaction rule also redacts NIP-05 identifiers such as
`name@divine.video`. That is intentional for public support payloads: NIP-05s
are public handles, but incidentally collected handles still identify people
and can be preserved privately in Zendesk metadata when support needs them.

## Residual Risks

Redaction is applied in Dart, so it only covers text that crosses a Dart
submission boundary. These limits are known and accepted:

- Hex-form private keys are not redacted, because 64-char hex is
  indistinguishable from public event IDs and pubkeys, and blanket redaction
  would remove the triage value the summary exists for. A hex key written under
  a credential-shaped name (`privateKeyHex: <hex>`) is still caught by the
  key-name rule below; a bare hex string on its own is not.
- Redaction is keyword-based, so it cuts both ways and is deliberately tuned to
  lose triage value rather than leak. A key containing `token`, `jwt`,
  `secret`, `password` or `key` has its value redacted even when that value is not a
  secret (`token_count: 5`, `cancellationToken: active`, `passwordReset:
  failed`), because no key-only rule separates those from `token_value` or
  `passwordHash`. Two exceptions: every spelling of the public key (`pubkey`,
  `pub_key`, `public_key`, `publicKey`) is preserved, because it is public by
  construction and support needs it for triage; and bare `key` is preserved,
  because it is an ordinary English word (`Failed to import key: <error>`,
  `Cache key: video_123`, `KeyEvent: KeyDownEvent`) - only compound forms such
  as `api_key` and `sessionKey` count as credential keys. Conversely, a
  credential written without a `:` or `=` separator (`password hunter2`) is not
  redacted, because that shape is indistinguishable from ordinary prose
  ("password reset failed").
- An unquoted multi-word value is redacted only up to the first space
  (`password: correct horse battery staple` keeps everything after the first
  word). Without a closing delimiter there is nothing to mark the end of the
  value. Quoted values, which is how serialized payloads are written, are
  redacted whole.
- A bracketed or braced value (`token: {...}`, `apiKey: [...]`) is redacted
  whole, including nested objects and pretty-printed ones spanning lines, up to
  4000 characters. A credential object larger than that keeps whatever falls
  past the bound. The limit caps what an unclosed `{` typed into a report can
  consume - 4000 characters of surrounding diagnostics rather than everything
  after it - and keeps a long pasted field from making the scan quadratic. The
  cost is paid twice: a serialized credential object larger than 4000
  characters is only partly redacted, and a stray brace still costs up to 4000
  characters of diagnostics around it.
- Redacting such a value consumes what follows it, up to the bound, across
  lines. Anything printed after a credential key - including a pubkey - can be
  redacted along with the value, so the preservation rule above holds only for
  a pubkey that is not within the bound of a credential key.
  Each contributed field is sanitized before the report is assembled, and each
  log entry before the summary is built, so that loss stays inside the field or
  entry that caused it rather than reaching the rest of the ticket.
- A credential key with more than 24 `_`/`-` or camelCase segments is not
  redacted. The cap exists because an uncapped key run costs seconds per 100KB
  of pasted text on the UI thread. No real credential key is that long, so this
  is a bound on pathological input rather than on anything support sees.
- Free-text fields on the bug report, feature request and content report forms
  are capped at 10000 characters and subjects at 200, so a pasted field cannot
  make sanitization slow enough to freeze submission. The cap is an input
  formatter rather than `maxLength`, to keep four Material character counters
  off the support forms, and the form says "that's the maximum length" once a
  field is full. Truncation must not be silent: nothing else in the payload
  carries the dropped tail, since attachments are images only and the log
  summary comes from in-app logs rather than pasted text.
- A credential key written with nothing after it (`...my password:`) consumes
  the start of whatever follows, across the line break, because the separator
  between a key and its value may span whitespace. Between assembled fields
  that costs a few characters of the next heading; inside the log summary,
  where entries abut with no heading between them, it can cost the start of the
  next entry or a braced line. Diagnostic loss, not a leak - the alternative,
  refusing to span a line break, would leave `password:` followed by its value
  on the next line unredacted.
- Text typed inside the native Zendesk SDK screens is never sanitized. The
  ticket list (`ZendeskSupportService.showTicketListScreen`, reachable from the
  support center) opens the SDK's own UI, where a reply to an existing ticket is
  composed and submitted by the SDK without passing through
  `ZendeskSupportService`. The SDK also ignores prefilled subject/description on
  Android, so the user types those natively too. Treat replies sent from that
  screen as unredacted public text.

## Private Support Channels

Private channels, including encrypted support DMs and user-exported logs, may
carry fuller diagnostic context when the user explicitly triggers the flow.
They still must apply the same secret redaction rules before transmission or
export.

Do not upload full user diagnostic logs to public content-addressed blob storage
for public Zendesk/GitHub support flows. If support needs full logs, use a
private store with access controls, retention limits, and an owner for deletion
requests before adding that collection path. See #6941.

## Open Decisions

Two policy details need product and support-owner confirmation before
broadening the implementation:

- Whether public GitHub issues should continue to include the signed-in Nostr
  public key, or whether Zendesk-only private metadata is enough for support
  (#6940).
- Which private log store, retention period, and access controls apply if
  support needs full diagnostic archives beyond the bounded public summary
  (#6941).
