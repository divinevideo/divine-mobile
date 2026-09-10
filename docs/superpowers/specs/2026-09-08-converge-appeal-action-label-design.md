# Converge the appeal action label across account-status and minor-review (#8248, button-first slice) — design

**Problem.** The account-status and minor-review screens name the same appeal destination
with different labels ("Contact support" vs "Open Support Center"). #8248 asks to converge
on #8239's approved wording; it explicitly says do the button label first, separately.

**Corrected premise (verified on origin/main).** The issue says account-status copy is
translated and minor-review is English-only. In fact, `accountStatusContactSupport` ("Contact
support") is translated only in Telugu and falls back to English in the other 21 locales (as
tracked by `_knownUntranslatedDebt`), while `minorAccountReviewOpenSupportCenter` ("Open Support
Center") is translated in all 22 locales. So converging to "Open Support Center" is both the
approved direction and the already-translated one — the button slice ships clean with no new
translation.

## Scope (this PR)

Action-label convergence ONLY. The heading/body convergence (legal-load-bearing paragraphs
needing a 22-locale speaker-reviewed pass) stays deferred to a follow-up, as the issue frames it.

## Change

1. Introduce a neutral shared key `appealOpenSupportCenter` by renaming
   `minorAccountReviewOpenSupportCenter` -> `appealOpenSupportCenter` across `app_en.arb` and all
   22 locale ARBs, preserving each locale's existing approved translation verbatim.
2. Point both `minor_account_review_screen` and `account_status_screen` at the shared key.
3. Remove the now-unused `accountStatusContactSupport` from every ARB that carries it and delete
   its `_knownUntranslatedDebt` entry (a debt reduction).
4. gen-l10n.

## Tests (TDD)

- Widget test: the account-status appeal button resolves `appealOpenSupportCenter` from
  `AppLocalizations` and reads "Open Support Center" (not the old "Contact support"); the
  minor-review screen resolves the same shared key. Both name the destination identically.
- ARB parity passes; no orphaned old key; debt entry removed.

## Deferred (not this PR)

Heading/body convergence (`accountStatusAppealHeading`/`Body` -> #8239's title/bodies), which
needs the speaker-reviewed 22-locale translation pass Matt/Liz arrange.
