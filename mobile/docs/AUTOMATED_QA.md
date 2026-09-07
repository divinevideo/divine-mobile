# Automated QA

Automated QA is split by feedback speed and determinism. Pull requests should
get a useful answer quickly; broad regression coverage should not make every
small change wait for a device build.

## Coverage by event

| Event | Automatic coverage | Blocking |
|---|---|---|
| Pull request | Change-scoped Mobile CI and headless service integration; iOS Maestro PR smoke when Codemagic webhooks are connected | Mobile CI and service checks are blocking; Maestro is observational |
| Merge to `main` | Change-scoped Mobile CI and all service suites when service dependencies changed | Reports regressions on `main` |
| Nightly | Every deterministic headless service suite | Alert/triage signal |
| Manual | Full headless service suite; platform-specific Maestro workflows | Operator-owned |

The shared classifier is `scripts/ci/detect_mobile_ci_scope.sh`. It is the
source of truth for documentation-only, app, native platform, service, golden,
Maestro, smoke, performance, and CI-configuration applicability. Incomplete or
unsupported change data fails open to all scopes.

Documentation-only pull requests and merges still publish the required Mobile
CI result, but skip Flutter analysis, tests, goldens, and device builds. Cheap
configuration guards remain unconditional because they protect the filters
themselves.

## Maestro policy

The PR suite is limited to launch readiness, an authenticated Home shell, and
one immutable video fixture. It does not search live content or use a shared
account. JUnit, screenshots, hierarchy dumps, Maestro logs, app logs, and
XCTest logs are retained for triage.

Keep the iOS check non-blocking until at least 30 comparable runs achieve both
an infrastructure-clean rate of 95% or better and a p95 duration below 15
minutes. Reset the observation window after changing a flow, the Maestro
version, the Xcode image, or the fixture. Demote the check immediately if
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
