# Brainstorm: fresh worktrees cannot run gradle-based tooling (#7201)

Date: 2026-09-06
Issue: https://github.com/divinevideo/divine-mobile/issues/7201

## Problem Statement

A fresh clone or `git worktree add` has no `mobile/android/gradlew`,
`gradlew.bat`, or `gradle-wrapper.jar` — they are gitignored — while
`gradle-wrapper.properties` (which pins gradle-8.14) **is** tracked. `flutter build`
recreates the missing launcher on demand, so ordinary app builds never notice. Anything
that calls `android/gradlew` directly fails until some Flutter build has run first.

**The issue conflates two problems with different natures**, and that is the key framing:

1. a missing **file** git could simply carry (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`);
2. a missing **toolchain** git cannot carry (JDK, Android SDK `cmdline-tools`, `ANDROID_HOME`).

The issue's options 1 (docs) and 2 (mise task) apply instruments suited to (2) against
problem (1).

## Constraints

- `mobile/android/.gitignore` is Flutter's `app/android.tmpl/.gitignore` **verbatim** plus
  one line, so changing it is a deliberate divergence from the Flutter template (F13) — it
  needs a written rationale, not a silent edit.
- Git precedence traps (F2, F18, both proven experimentally): editing only the **root**
  `.gitignore` is a no-op; *deleting* the lines from only the **nested** file is also a
  no-op. Only "negate in the nested file" or "delete from both" works.
- `local.properties` must stay ignored — it holds a machine-local absolute `flutter.sdk`
  path and self-heals on `flutter pub get` (F8).
- No CI, release, or test path invokes `gradlew` (F20), so there is neither regression risk
  nor CI benefit. Ergonomics is the entire justification.
- The repo is mise-managed and already pins `flutter = "3.44.9"`, with `setup_hooks` as an
  established per-worktree bootstrap task (F16, F24).
- Severity is **S4**: `shorebird init` is a completed one-off (F17) and a workaround is
  already documented (F5). The fix must stay proportionate.

## Prior Art

- `mobile/docs/SHOREBIRD_CODE_PUSH.md:550-558` — the gotcha and workaround, citing #7201.
- **#5990** (COMPLETED → PR #5989) — "developers had to remember multiple steps" answered
  with `mise run local_android` + shell tests.
- **#6377** (COMPLETED) — `mise run test` for local/CI parity + a docs update.
- `local_stack/android_sdk.sh` — *discovers* an installed SDK; installs nothing, and never
  mentions JDK or Gradle (F25).
- `mise run setup_hooks` — the near-exact structural analogue: one-time, per-worktree,
  idempotent bootstrap.

## Approaches Explored

### Approach A: Track the wrapper
Un-ignore `gradlew`, `gradlew.bat`, `gradle-wrapper.jar`; regenerate them at the pinned
8.14 (`7d3a4ac4…`) rather than committing Flutter's cache copy; commit ~43 KB once.

**Pros.** Zero ongoing human action; works for every consumer including the two actually
hit (`shorebird init`, IDE Gradle sync) which fail *before* any task or doc could help;
completes a contract the repo already half-keeps (pin tracked, launcher not); works
offline; near-zero regression risk (F20/F21); exec bit survives as mode 100755 (F19);
Flutter never overwrites a wrapper that already exists (F8), so it is stable.
**Cons.** Deliberate divergence from Flutter's template; one tracked binary blob with no
provenance ratchet covering it (F21) — mitigated by it being a published, checksum-listed
Gradle artifact (F12); mild upkeep to regenerate on a Gradle version bump.
**Complexity: Low.**

### Approach B: `mise run setup_android` bootstrap task
Keep the wrapper ignored; add a task that writes `local.properties` and runs
`flutter build apk --config-only` to inject it, with shell tests and docs.

**Pros.** Strongest repo precedent (F23); no binary in git; stays on the Flutter template;
can also check JDK/SDK presence.
**Cons.** Another thing to remember per worktree, and it does not help the reported
failures, which occur before the task would be run; needs the Flutter SDK and network;
adds a script + tests + docs to maintain — solving the long way a problem created only by
withholding a file git could carry.
**Complexity: Medium.**

### Approach C: Documentation only
Promote the Shorebird gotcha into `AGENTS.md` / `CONTRIBUTING.md`.
**Pros.** Cheapest; zero risk. **Cons.** Changes no behavior; already ~half-shipped and the
trap remains. **Complexity: Low.**

### Approach D: Close as won't-fix
Defensible on severity alone (S4, no CI impact, one-off trigger, documented workaround).
**Cons.** Leaves the trap for the next person on a repo where fresh worktrees are the
mandated workflow — 21 of 21 existing worktrees are affected (F3). **Complexity: None.**

### Considered and rejected: automatic injection via a git hook
A `post-checkout` hook injecting the wrapper. Rejected on a chicken-and-egg: hooks are
installed by `mise run setup_hooks`, which a fresh worktree has not run either — so the
hook is absent exactly when it is needed. Adds latency and magic to every checkout.

## Recommendation

**Approach A for the wrapper, plus a `mise [tools] java` pin and a short docs section for
the toolchain half.** *(User-selected direction.)*

A is the only option that removes the failure rather than describing or deferring it, and
it is the cheapest of the ones that do. B and C are kept exactly where they earn their
keep: the JDK/Android SDK genuinely cannot be committed, so that half gets the mise pin
(mechanical, self-provisioning, gives local/CI parity in the spirit of #6377) plus prose
for what mise cannot install (Android `cmdline-tools`, `ANDROID_HOME`).

**JDK version is evidence-based, not chosen:** Java **17**, from three independent sources —
`app/build.gradle.kts:25-26` (`sourceCompatibility`/`targetCompatibility = VERSION_17`),
`:115` (`jvmTarget = JVM_17`), and `codemagic.yaml:1058,1255,1423` (`java: 17`). AGP 8.11.1.

## Open Questions for /plan

- [ ] Regenerate the wrapper with `./gradlew wrapper --gradle-version 8.14` and verify the
      committed jar is `7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172`.
- [ ] Negate in the nested `.gitignore`, or delete from both? (Both work — F18.)
- [ ] Add a `gradle/actions/wrapper-validation` CI step, or rely on the checksum assertion
      in review? (No Android CI job exists today — F20 — so a new workflow is real new cost.)
- [ ] Where do the docs live: `AGENTS.md`, `CONTRIBUTING.md`, or a new
      `mobile/docs/ANDROID_LOCAL_SETUP.md`?
- [ ] Does adding `java` to `[tools]` slow or disrupt anyone whose `mise install` is
      currently Flutter-only?

## Prerequisites

- [ ] None blocking. Direction is decided; JDK version is established; no team input needed.

## Next Step

`/plan 7201` — build the implementation plan on Approach A + toolchain pin.

---

## Resolved (implementation, 2026-09-06)

Approach A + toolchain pin shipped. How the open questions above landed:

- **Regenerate at 8.14** — yes. `gradle wrapper --gradle-version 8.14 --distribution-type all`;
  the committed jar is `7d3a4ac4…`, Gradle's published 8.14 wrapper checksum. Regeneration
  also added `networkTimeout=10000` and `validateDistributionUrl=true` to
  `gradle-wrapper.properties` (Gradle 8.x defaults; `distributionUrl` unchanged).
- **Negate, don't delete — and only in the nested file.** The root `.gitignore` is
  untouched: its `**/android/**` rules protect eight *other* android directories (six
  packages, `overrides/`, `test/android`). Deleting them to fix one directory would have
  exposed all nine.
- **Checksum guard, not `gradle/actions/wrapper-validation`.** That action accepts any
  published Gradle wrapper, so a silent version swap would pass it.
  `mobile/scripts/check_gradle_wrapper_checksum.sh` pins one checksum, runs in the existing
  `Generated Files` job gated on `native`, and adds no third-party action.
- **Docs** — a new `mobile/docs/ANDROID_LOCAL_SETUP.md`, linked from `AGENTS.md` and
  `CONTRIBUTING.md`; the obsolete Shorebird gotcha retired.
- **`java` in `[tools]`** — additive; `mise install` picks up a JDK on next run.

Two things learned by doing it, which the exploration missed:

- **`.gitattributes` was required.** `gradlew` is LF and `gradlew.bat` is CRLF, and the repo
  sets neither `core.autocrlf` nor `core.eol` — a contributor whose git converts on checkout
  would rewrite `gradlew` to CRLF, which fails at exec with `bad interpreter`.
- **The fix is narrower than "gradle works now".** `settings.gradle.kts` reads
  `local.properties` with no existence check, and
  `packages/caption_generator/android/build.gradle.kts` throws without `FLUTTER_ROOT`. So a
  direct `./gradlew` still needs `flutter pub get` and an exported `FLUTTER_ROOT`. What this
  change removes is the **`flutter build`** prerequisite, nothing more.
