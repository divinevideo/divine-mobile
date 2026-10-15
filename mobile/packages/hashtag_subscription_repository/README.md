# Hashtag subscription repository

Owns device-local follows for one authenticated account. Inject a
`HashtagSubscriptionStore` scoped to the account's full public key. The
repository normalizes membership, preserves display spelling, serializes writes,
and publishes immutable confirmed snapshots. Failed reads can be retried and
never authorize overwriting unread storage. Dispose the repository on account
changes; subscriptions do not sync across devices or Nostr clients.

Run `dart test` and `dart analyze` from this package. Its CI workflow enforces
100% line coverage.
