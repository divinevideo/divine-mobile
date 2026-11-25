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

Three facts decide what counts as the cause:

1. **Who first saw the symptom**: the person you are talking to, end users, a
   tester, a monitor, CI.
2. **Which build they saw it on**: version and build number, release or debug,
   device or simulator, operating system.
3. **Whether anyone sees it outside this machine.**

Only the user, the issue or the ticket can settle them. A reproduction on this
machine does not: it shows that the symptom can happen here, and that can be a
different failure that looks the same.

**If any of the three is missing, ask the user, and wait for the answer before
you report a cause.** Read enough first to make the questions specific. Then:

- With a question tool, call it. Four questions at most.
- Without one, end your turn with the questions.
- Before the questions, give at most three lines on what you have found so
  far, labelled as what happens on this machine.
- Send no report and name no root cause until the answer comes back.

These do not replace the question:

| Instead of asking | Why it does not count |
|---|---|
| "No issue in the tracker reports it" | Reports also arrive through support, chat and conversation. An empty search answers nothing. |
| "Outside this machine: unknown" in the report | A note is not a question. The user reads it under a cause you have already named. |
| "If users see it too, tell me" at the end | The same. It sits below a conclusion they may act on. |
| "They showed it to me on their own device" | That is where they are looking now, not who first saw it. |

If you are about to write "if anyone sees it on a real device" or "if users
report it", stop. That sentence is the question you have not asked. Ask it and
wait.

If you cannot reach the user (they said they are away, or you are running as a
subagent or a scheduled job), write the report, head its cause section "On
this machine", and make the open questions its first line.

A fault in the local environment blocks reproduction of the reported failure.
Say so and keep looking for the reported failure. That covers the machine's
network, VPN, proxy, simulator, caches, local configuration and unreleased
commits.

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

Write this report only when step 1 is settled. If its first line would say
"unknown" or "not checked", stop and ask the question instead.

```markdown
## Investigation: <title> (#<issue>)

**Seen by**: <who> · **Build**: <version and build, mode, platform> · **Outside this machine**: <yes / no>
**Type**: Bug | Regression | Crash | Performance | Build failure · **Severity**: S1 to S4
**Confidence**: <0.0 to 1.0>

### Summary
<what is broken, for whom, since when>

### Already known
| # | Title | State | Relation |
|---|-------|-------|----------|

### Root cause
<the chain of whys, each with its evidence: file and line, log line, commit>
<the first build that has the cause and, if a fix exists, the first build that has the fix>

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
