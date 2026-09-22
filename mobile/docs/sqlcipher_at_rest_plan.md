# SQLite3MultipleCiphers at-rest encryption for the local DB (#570, finding C2)

Status: **device-QA gated before merge.** The Dart implementation, dependency
swap, host tests, and local host probes are in this PR. The final gate is a real
iOS device and real Android device with a pre-existing encrypted database.

## Why

`divine_db.db` stores user data that includes drafts, pending uploads/actions,
reactions, reposts, notifications, bookmarks, NIP-05 state, and DMs. That file
must be encrypted at rest on native platforms. Web / IndexedDB remains out of
scope until the OPFS encryption work.

## Dependency shape

- `drift` is on the 2.34 line and `sqlite3` is on the 3.3 line.
- `sqlcipher_flutter_libs` is removed. The 0.7 line is an EOL no-op for sqlite3
  3.x, and the old Android `open.overrideFor` / SQLCipher workaround is gone.
- `sqlite3_flutter_libs` and `drift_flutter` must stay out of the app. Extra
  native SQLite providers can make plain SQLite win.
- `pubspec.yaml` selects SQLite3MultipleCiphers through the sqlite3 hook:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

`package:sqlite3` 3.3.3 publishes prebuilt sqlite3mc assets for Android, iOS,
iOS simulator, macOS, Linux, Windows, and wasm. Local hook output confirmed the
workspace pubspec define is read and the host build loads `libsqlite3mc.dylib`.

## Key and open sequence

The app stores a 32-byte CSPRNG key in `flutter_secure_storage` under
`db.cipher.key.v1`, represented as 64 lower-case hex characters. db_client never
reads secure storage; the app bootstrap resolves the key and injects it.

**That slot name never changes.** Every build looks in it, old and new, so
moving the key to a second slot leaves an older build reading an empty one,
generating a replacement and wiping the database through key-loss recovery. An
App Store or TestFlight rollback, a downgraded macOS build, a sideloaded older
APK, and a Shorebird patch rolled back to its release baseline all reach that
path, and the slot name is platform-independent so none of them is iOS-only.
When the accessibility changed (#9343) the item was therefore rewritten in
place rather than moved (#9385).

On iOS the item carries `first_unlock`: readable from the first unlock after
boot until the next reboot, locked screen included. Until #9343 it sat under
the package default, `unlocked`, and every launch while the device was locked —
a silent push, a background refresh, a prewarmed launch — failed with
`errSecInteractionNotAllowed` (-25308). On each unlocked launch the bootstrap
rewrites the key into the same slot under the current options; the plugin's iOS
write puts the accessibility into its `SecItemUpdate` query, so an item already
under the current class updates in place and only a mismatched one takes the
delete-and-re-add path. Before rewriting, bootstrap writes and verifies a
recovery copy at `db.cipher.key.v1.accessibility_backup`. A failed backup write
leaves the primary untouched. A failed primary rewrite attempts to restore it;
if restoration also fails, startup fails closed with the recovery copy intact.
The next launch restores a missing primary from that copy before any key-loss
recovery. The copy is removed only after the primary reads back correctly.
The primary slot remains the rollback contract; older builds cannot recover
an interrupted rewrite themselves, so a successful launch of this build is
required before rolling back after such an interruption. The rewrite is skipped
while protected data is unavailable.
macOS keeps `unlocked` (#5563), so nothing is rewritten there.

`first_unlock_this_device` is deliberately **not** used. It is readable at
exactly the same times, so it fixes #9343 just as well, but `SecItem.h` says
its items "will never migrate to a new device, so after a backup is restored to
a new device these items will be missing" — while `divine_db.db` lives under
Application Support and nothing excludes it from backup. The key would then
travel less far than the data it opens, and a restore onto a new iPhone would
find the database, find no key, wipe it through key-loss recovery and leave a
permanently unreadable backup behind. What that costs is the local-only data
nothing can re-fetch: drafts, pending uploads and actions, outgoing DMs,
pending gift wraps, saved caption and title styles.

Keeping an at-rest key out of backups is a defensible threat model, but it is
not this one. The scope above is the device's filesystem, not its backups, and
the same backup already carries the Nostr identity key under `first_unlock`
(`nostr_key_manager`'s `PlatformSecureStorage`) plus `cache_sync.db`, the Hive
boxes and SharedPreferences in the clear. Withholding only the database cipher
key protects strictly less valuable data from an attacker who, by that point,
already holds the identity key.

`flutter_secure_storage`'s iOS `read` reports an item the current device state
cannot decrypt as absent rather than failing: it drops the -25308 status and
retries the query as synchronizable, which finds nothing. So before generating
a key, the bootstrap asks `UIApplication.isProtectedDataAvailable`; while
protected data is unavailable an empty read is not evidence of a fresh install,
and the launch fails closed with `DatabaseCipherStorageUnavailableException`
instead of writing a replacement key that would strand the existing database.

Every keyed native open runs these statements before any database use:

```sql
PRAGMA cipher = 'sqlcipher';
PRAGMA legacy = 4;
PRAGMA key = "x'<64 hex chars>'";
```

The raw-key form skips PBKDF2, which is correct for a random 32-byte key and
preserves compatibility with databases previously written by SQLCipher. The key
must never appear in logs, exceptions, Crashlytics, analytics, or test output.

Fail-closed remains mandatory. The runtime and connection probes use
`PRAGMA cipher`; upstream SQLite returns no rows, while SQLite3MultipleCiphers
returns the active cipher. If MC is not active, startup refuses to open the local
database instead of silently writing plaintext.

## Plaintext-to-encrypted migration

`sqlcipher_export()` is not available under SQLite3MultipleCiphers, so the old
migration path is replaced with a safe side-file flow:

1. Classify the existing `divine_db.db` by opening it unkeyed. Only
   `SQLITE_NOTADB` is treated as already encrypted; transient read failures
   (busy, locked, I/O) stay indeterminate and retry later. `SQLITE_CORRUPT` is
   neither — a legible header over a damaged page classifies the same way on
   every launch, so it fails startup closed rather than retrying forever (#6897).
2. For populated plaintext DBs, copy the source to
   `divine_db.db.sqlcipher_migrating` with `VACUUM INTO`. The classification in
   step 1 reads only `sqlite_master`, so damage anywhere past page 1 reaches
   here looking like healthy plaintext; this copy walks every b-tree and is the
   first thing to see it. `SQLITE_CORRUPT` here takes the same fail-closed path
   as step 1, and for the same reason — it is a property of the bytes, so the
   retry never comes out differently.
3. Open the side file, select `cipher='sqlcipher'` + `legacy=4`, then
   `PRAGMA rekey = "x'<key>'"`.
4. Verify the encrypted copy opens with the raw key and that `user_version` plus
   all user-table row counts match the plaintext source.
5. Rename the plaintext source to a `.pre_cipher_migration_backup*` file and
   promote the verified encrypted artifact into place.

On any failure, the plaintext source is left intact and migration retries next
launch. That deferral opens the database unkeyed in the meantime, which is only
safe because the source is readable plaintext — a structurally corrupt one takes
the fail-closed path above instead, from whichever of the two steps first sees
the damage. After a later successful keyed open, old pre-cipher plaintext backups
are deleted so plaintext does not remain at rest.

## Key-loss recovery

If secure storage loses `db.cipher.key.v1` while an encrypted DB remains, the old
DB is cryptographically unrecoverable. The bootstrap backs up the unreadable DB
and creates a fresh encrypted DB under the new key. This is data-preserving in
the only possible way: the old bytes are retained for forensic/manual recovery,
but the app cannot unlock them without the lost key.

## Cache database

Only `divine_db.db` is keyed. `cache_sync.db` remains opened unkeyed. MC supports
plaintext databases, and the cache contains replaceable local cache state.

## Host verification

Host tests now cover the properties that used to be device-only:

- raw-key MC file-backed open succeeds with `cipher='sqlcipher'` + `legacy=4`;
- the encrypted file is not readable as plaintext SQLite;
- populated plaintext DB migration preserves `user_version` and row counts;
- malformed keys and keying failures do not leak the raw key;
- bootstrap key generation, reuse, key-loss backup, and fail-closed behavior.

Local probes also confirmed keyed in-memory MC databases are unsupported, so
tests use file-backed DBs.

## Device-QA checklist

- [ ] Real iOS device: existing SQLCipher-encrypted `divine_db.db` opens through
      the MC compatibility path with no data loss.
- [ ] Real Android device: existing SQLCipher-encrypted `divine_db.db` opens
      through the MC compatibility path with no data loss.
- [ ] Fresh iOS install creates an encrypted DB and plain `sqlite3` cannot read
      the file.
- [ ] Fresh Android install creates an encrypted DB and plain `sqlite3` cannot
      read the file.
- [ ] Legacy populated plaintext DB migrates once, preserves row counts and
      `user_version`, then removes pre-cipher plaintext backups after a keyed
      open.
- [ ] Force-kill during migration resumes without data loss.
- [ ] Clear secure storage / simulate key loss: app backs up the unreadable DB,
      creates a new encrypted DB, and does not brick.
- [ ] Key material is absent from logs, Crashlytics, analytics, and thrown error
      strings.

Record device, OS version, build number, and exact result for each item before
merging.
