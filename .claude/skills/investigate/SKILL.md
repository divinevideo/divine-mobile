---
name: investigate
description: Use when a bug, regression, crash, slowdown or build failure has no obvious cause, when the cause may sit in another repository or service, or when the user asks why something is happening or what the root cause is.
argument-hint: "[issue number, issue URL, or a description of the symptom]"
---

# Investigate

Find the cause of a problem and write it up so that someone else can act on it.

This skill adds three things to ordinary debugging: a check on where the
symptom was seen, a search for work that already exists, and a report shape.
For the debugging method itself, use the project's debugging workflow, or
`superpowers:systematic-debugging` when it is available.

Take everything specific to a codebase from the project's own instructions:
`CLAUDE.md`, `AGENTS.md`, `.claude/rules/` and the docs they point to. That
covers its layers, build system, test commands, storage and protocol rules.
Read the rule file for a layer before you analyse that layer. Where this skill
and the project's instructions disagree, follow the project.

## 1. Establish where the symptom was seen

Collect the facts that distinguish the reported failure from a similar symptom:

1. **Who first saw the symptom**: the person you are talking to, end users, a
   tester, a monitor, CI.
2. **Which build they saw it on**: version and build number, release or debug,
   device or simulator, operating system.
3. **Whether anyone sees it outside this machine.**

Use the report, build metadata, CI artifacts, logs, and other available
evidence. A local reproduction establishes what happens in that environment.
Use matching evidence from the reported failure before attributing it to the
same cause. An empty issue search leaves reports from other sources unknown.

Ask the user for a missing fact when the answer would materially change the
diagnosis and the evidence cannot settle it. If the user is unavailable or
the answer is pending, continue the independent work and share the evidence
you have with its scope and open questions.

When a local fault prevents exercising the reported path, document that
limitation and keep investigating the original report. Label any diagnosis
that applies only to the local environment "On this machine".

## 2. Look for work that already exists

Do this before deep analysis. The bug may already be fixed, filed or in
review.

- Search issues and pull requests, open and closed, by issue number and by the
  symptom's key words:
  `gh issue list --state all --search "<words>"` and
  `gh pr list --state all --search "<number or words>"`.
- Read the recent history of the affected area:
  `git log --oneline -30 -- <path>`. For a symptom tied to a release, list
  what changed between the last good build and the first bad one.
- Read the project's own notes on the area: earlier investigations, lessons
  files, and any plan or findings for this issue (for example under
  `docs/superpowers/`, or in a local `tasks/` folder).
- If the code path runs through a dependency, check that package's issue
  tracker for the exact version in the lockfile.

A known bug with the same symptom belongs in the report even when it does not
explain what you see on this machine. It may be what the reporter has. If a
fix is already merged, find the first build that contains it and compare that
with the build from step 1.

## 3. Find the cause

1. Classify the problem (bug, regression, crash, performance, build failure)
   and name the layer or service you suspect, with the evidence for it. Look
   there first, not everywhere.
2. Reproduce it on the build from step 1, or say why you cannot.
3. Compare expected and actual state at each boundary the data crosses
   (service, client, repository or cache, state, UI) until you find the first
   boundary where they differ.
4. For a regression, find the change that broke it.
5. Trace the cause to a file and line. If you cannot, say so and list what you
   ruled out.
6. Ask why until the answer is a decision or a missing check, not another
   symptom.

Rate each hypothesis from 0.0 to 1.0 while you work, so the user knows what to
check first.

## 4. Report

Start with the facts from step 1 and mark any unknowns. Use "Root cause" for
a cause supported by evidence from the reported failure. Use "On this
machine" for a cause verified only locally, or "Current evidence" when the
cause is unconfirmed. Say what would distinguish the remaining hypotheses.

```markdown
## Investigation: <title> (#<issue>)

**Seen by**: <who or unknown> · **Build**: <version, mode, platform or unknown> · **Outside this machine**: <yes / no / unknown>
**Type**: Bug | Regression | Crash | Performance | Build failure · **Severity**: S1 to S4
**Confidence**: <0.0 to 1.0>

### Summary
<what is broken, for whom, since when>

### Already known
| # | Title | State | Relation |
|---|-------|-------|----------|

### <Root cause / On this machine / Current evidence>
<the chain of whys, each with its evidence: file and line, log line, commit>
<the first affected build and first fixed build, when known>

### Fix
<files to change, the change, the regression risk, the test that would have caught it>

### Workaround
<what works today, why it works, and when it can be removed>

### Not verified
<what you did not run or could not see, and what would settle it>

### Next actions
1. <first action>
```

Severity: S1 is a crash, data loss or security problem. S2 is a core feature
broken with no workaround. S3 is a degraded feature with a workaround. S4 is
cosmetic.
