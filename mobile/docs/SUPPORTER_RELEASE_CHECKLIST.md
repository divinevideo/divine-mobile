# Supporter release and purchase recovery

The store is the source of payment evidence. The supporter service verifies store
proofs and owns account entitlement. Firebase events measure the client funnel;
an analytics revenue number or subscription-renewal event is not a paid-account
ledger, and renewal events are not a count of distinct supporters.

## Before enabling purchases

- Record the exact public iOS and Android version/build, source commit, and any
  applicable Shorebird patch. Confirm each artifact contains the verification
  configuration guard and purchase recovery code. A fix merged to main is not
  evidence that a public binary contains it. Builds made without Shorebird need
  a new store release.
- Verify `SUPPORTERS_API_BASE_URL` in the built artifact and authenticate `/v1/me`
  using the account's signer. The purchase path checks this before opening the
  store, but `/health` and `/v1/me` do not prove store-verifier credentials work.
- Verify each offered product is approved and available in its store. The native
  product list currently offers the monthly plan; do not advertise additional
  plans before the app can deliver them.
- Deploy and verify the supporter service's transient-claim retry and current
  snapshot replay behavior before enabling the mobile recovery changes.
- Keep sandbox/TestFlight/test purchases separate from paid production reporting.
  Verify receipt environment on the server; do not infer it from a release build
  or the configured Apple endpoint alone. The verifier can fall back to sandbox.
- Confirm store notifications, scheduled reconciliation, and expired/grace
  handling update the canonical account after the app is closed.

## Device acceptance matrix

Run these with store-backed builds on both supported purchase platforms. Unit
and widget tests cover the failure modes but do not replace these checks.

| Scenario | Required result |
| --- | --- |
| New subscription | Store confirmation, verified account entitlement, active supporter badge, then store acknowledgment |
| Missing verifier URL or failed authenticated preflight | Billing does not start; actionable failure appears |
| Verification temporarily unavailable after payment | No false success; transaction remains recoverable; identical proof succeeds after recovery |
| Kill app after payment or before acknowledgment | Same account recovers and acknowledges without charging again |
| Account switch during or after purchase | Purchase remains bound to its initiating account; another account cannot claim it |
| Canceled purchase or store refuses to start | No entitlement; no leftover pending account lock |
| Existing subscription on a fresh installation | Explicit Restore claims the purchase with the intended account; a rejected wrong-account restore does not block the rightful owner |
| Automatic restore with no known local owner | Does not silently assign a legacy purchase to the current account |
| Renewal, billing grace, expiry, refund/revocation | UI follows current canonical state; replaying an old claim cannot restore an obsolete entitlement |
| Active supporter presses subscribe | Server preflight returns existing entitlement without opening billing |
| Analytics unavailable or consent declined | Purchase and restoration still work |

Verify both Settings entry visibility and the supporter screen in the actual
release artifact. Existing purchasers need a reachable Restore path and clear
account-selection guidance. Do not enable purchase access more broadly than the
restore and entitlement display paths have been tested. A renewal can have a new
store transaction identifier without a saved local owner. Such proofs currently
require explicit Restore; this change does not establish unattended renewal
acknowledgment. Test that case before rollout, including a stale canonical account
and termination before StoreKit finishes the transaction.

## Reconciliation and monitoring

Use credentialed store sales/financial reports and verified transaction state to
reconcile the same period, platform, product, environment, and currency. Keep the
following counts separate: unique paying store subscriptions, verified
transactions, distinct entitled Divine accounts, and renewal events. Investigate
production purchases without an account claim and active entitlements without
production payment evidence. Keep receipts, tokens, and identity-linked reports
out of public issues and PRs.

The screen sends `supporter_subscribe_tapped`,
`supporter_subscribe_succeeded`, and `supporter_subscribe_failed` through the
configured analytics sink. Success means canonical entitlement became active
during that screen's purchase flow; it is not a financial revenue event and may
include an already-active account. `supporter_restore_completed` means the store
restore call returned, not that every proof has been verified. Use server
entitlement and claim outcomes to measure recovery and renewals across app
restarts or screen closure.

During a limited rollout, inspect claim failure status, pending processing age,
verified environment, acknowledgment recovery, webhook/reconciliation failures,
and the store-to-entitlement discrepancy. Stop expanding purchase access when a
paid transaction cannot be restored or recognized. Preserve restoration and
entitlement access while resolving the failure.

## Product scope and rollout decision

The current mobile supporter screen provides subscription status and a thank-you
badge. A public profile halo, discovery directory, recognition preferences, and
other advertised benefits need their own delivery and acceptance evidence; a
server preference field alone does not deliver the benefit in the app. Align
public copy with what the release actually provides before accepting payments.

Open rollout only after the store report reconciliation, device matrix, shipped
artifact provenance, and advertised-benefit checks are recorded. Keep the
feature flag gated until those checks pass and the release owner approves the
rollout. This checklist does not itself change production configuration.
