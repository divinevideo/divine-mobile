# Automated QA

Automated QA is split by feedback speed and determinism. Pull requests should
get a useful answer quickly; broad regression coverage should not make every
small change wait for a device build.

## Coverage by event

| Event | Automatic coverage | Blocking |
|---|---|---|
| Pull request | Change-scoped Mobile CI and headless service integration; iOS Maestro PR smoke when Codemagic webhooks are connected | Only `Mobile CI` is required; the service check and Maestro are observational |
| Merge to `main` | Change-scoped Mobile CI and all service suites when service dependencies changed | Reports regressions on `main` |
| Nightly | Every deterministic headless service suite | Alert/triage signal |
| Manual | Full headless service suite; platform-specific Maestro workflows | Operator-owned |

`Mobile CI` is the repository's only required status check, and it is the only
workflow with a `merge_group:` trigger, so it is also the only result the merge
queue evaluates. A red `Integration Tests (services)` therefore reports a
regression but does not block a merge; treat it as a signal to act on, not a
gate that stops the branch for you.

The shared classifier is `mobile/scripts/ci/detect_mobile_ci_scope.sh`. It
emits eleven scopes, but only four gate anything today: `app`, `native` and
`goldens` inside Mobile CI, and `service`, which
`mobile_service_integration_tests.yaml` reads across workflows. The rest --
`docs_only`, `android`, `ios`, `maestro_static`, `smoke` and `performance` --
are computed and published for consumers that do not exist yet, so changing one
of them changes nothing until it is wired. Incomplete or unsupported change
data, including a failed GitHub API call, falls open to all scopes.

Documentation-only pull requests and merges still publish the required Mobile
CI result, but skip Flutter analysis, tests and goldens. That skipping is
driven by `app` and `goldens`; `docs_only` is published for readers and gates
nothing.

Codemagic is not gated by this classifier at all. Every Codemagic workflow
declares `triggering: events: []` except `e2e-smoke-ios`, which triggers on
`pull_request` and filters on its own `changeset: includes: - mobile/` -- a
path this file matches. So a documentation change under `mobile/` can still
start the iOS smoke build, and the device builds a docs change "skips" were
never automatic to begin with. Cheap configuration guards remain unconditional
because they protect the filters themselves.

## Maestro policy

The PR suite is `e2e/maestro/tests/loginFreshInstall.yaml` and
`e2e/maestro/tests/removeKeys.yaml`, passed to Maestro individually so each
yields its own JUnit `<testcase>`. Both are launch- and identity-level flows;
neither renders a video. It does not search live content or use a shared
account. Restoring the broader flows is tracked in
[#7619](https://github.com/divinevideo/divine-mobile/issues/7619) and
[#7620](https://github.com/divinevideo/divine-mobile/issues/7620). JUnit, screenshots, hierarchy dumps, Maestro logs, app logs, and
XCTest logs are retained for triage.

Keep the iOS check non-blocking until at least 30 comparable runs achieve both
an infrastructure-clean rate of 95% or better and a p95 duration below 15
minutes. Nothing in this repository counts those runs or computes that p95, so
this is a judgement a maintainer makes by reading Codemagic build history, not
a threshold any job enforces. Reset the observation window after changing a
flow, the Maestro version, the Xcode image, or the fixture. Demote the check immediately if
infrastructure failures block healthy pull requests.

Recorder journeys require physical camera hardware and belong in manual or
scheduled device regression, not the simulator PR gate. A green run that skips
hardware-guarded assertions is not evidence that the recorder path passed.

## Triage and ownership

The author owns product regressions introduced by a pull request. The first
maintainer investigating an infrastructure failure owns classification and
artifact capture; do not rerun blindly until the failure is identified.

1. Read the JUnit case name and screenshot first.
2. Check the hierarchy and app/XCTest logs to distinguish selector, app, driver,
   fixture, and network failures.
3. Reproduce against the same commit, Maestro version, platform image, and
   fixture.
4. Fix product or test defects in the change that exposed them. Do not skip or
   quarantine a failing test to make the gate green.

Codemagic webhook connectivity is external to this repository and tracked in
[#7504](https://github.com/divinevideo/divine-mobile/issues/7504). The team
admin who connected the repository must use Codemagic's **Update webhook**
control. Repository YAML cannot compensate for a missing delivery.
