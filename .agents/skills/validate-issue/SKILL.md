---
name: validate-issue
description: Validate a Divine GitHub issue end to end before anyone fixes it, on a device or simulator, with every claim tagged by how it was observed. Runs only when invoked explicitly, as /validate-issue <issue-url> ($validate-issue in Codex). Covers Flutter/Dart app behaviour, Nostr events, relays and NIP conformance.
argument-hint: <issue-url>
disable-model-invocation: true
---

# Validate an issue

A claim is validated only by an observation that could have come out the other
way. Every claim in the output carries the tag of how it was observed. "1.0"
means the required tags are present; it is never a number someone asserts.

`$ARGUMENTS` is the issue URL. Work the phases in order. Each phase ends by
printing its block; a block with an empty slot is an unfinished phase. Phases
0-2 are read-only; Gate A (10-20 confirming questions) sits between 2 and 3.

The skill never starts on its own. Someone types `/validate-issue <url>`
(`$validate-issue` in Codex), and that is the opt-in to everything below,
the question gate included.

## Standing facts (never ask for these)

| Fact | Value |
|---|---|
| Org remote | `https://github.com/divinevideo` |
| Local root | The parent of this repo's main checkout: `main=$(git worktree list --porcelain \| sed -n '1s/^worktree //p'); echo "${main%/*}"`. Sibling clones live there (`divine-funnelcake`, `keycast`, `divine-blossom`, `divine-relay-manager`, `divine-web`; `gh repo clone divinevideo/<name> <root>/<name>` if absent); `divine-context` may instead be at `DIVINE_CONTEXT_ROOT` |
| NIP text | `<root>/nips`, a reference clone of `nostr-protocol/nips` (`gh repo clone nostr-protocol/nips <root>/nips` if absent). Fast-forwarding it (`git -C <root>/nips pull --ff-only`) is expected, even in a read-only pass; if it will not fast-forward, read `origin/master` with `git show`. Cite `NN.md:<line>` at the SHA |
| Trap notes | `.claude/rules/` (start with `self_review_checklist.md`), the domain skills in `.claude/skills/`, divine-context (`NOSTR.md`, `repo-context/divine-mobile.md`), Divine Brain, and your own agent memory for this repo if you keep one |
| Tools | `gh`, `jq`, `mise`, `websocat`, `nak` (lens commands verified on 0.20.6), `perl`; Xcode's `devicectl` for an iPhone, `adb` for Android |

The two lenses are dated snapshots: each opens with the SDK, NIP commit and tool
versions it was checked against, and says what has not yet run on a device.
When code, NIP text or a tool disagrees with a lens, trust what you observed,
say so in the Gate B report, and correct the lens in its own PR.

## 0. Preflight (no build yet)

```
Issue: <repo>#<n>  state=<…> at <date -u>  author org member=<y/n>  assignee=<…>  source=<human | zendesk bot>
PRs touching it: <open/merged PRs, or none: query used>
On main already?: <fixing sha | no: how checked on origin/main>
Duplicates: <search query → hits>
Pinned: divine-context@<sha>  nips@<sha>  origin/main@<sha>
Traps read: <the rules, repo skills and notes for this issue's area: DMs, feeds, relays, …>
```

Load divine-context the way the repo's `AGENTS.md` says, trust boundary first.
A Zendesk-bot issue is report-only. An issue nobody in the org assigned or
asked for is not started. Re-run the first three lines at every gate; PRs merge
and issues close mid-run.

## 1. Claim sheet

Split the issue into atomic claims, including the ones it implies without
stating ("every cold start", "all accounts", "since the last release").

```
C<n> | claim: expected X, actual Y | reported on: build, OS, account state | falsifier: the observation that would prove it wrong | layer guess
```

Then classify each claim and load the lens it names:

| Claim is about | Read | Cheapest environment that can falsify it |
|---|---|---|
| Widget, state, lifecycle, async, cache, performance | `flutter-lens.md` | unit/bloc test → simulator (debug only) → physical iPhone for hardware, push, background, profile and release |
| Events, relays, signing, DMs, deletion, identity, NIPs | `nostr-lens.md` | local `nak serve` → local stack → staging → production read-only |
| Both (most Divine bugs) | both | the wire first: establish which side is wrong before driving the UI |

## 2. Static grounding (read-only)

- Read code with `git show origin/main:<path>`, never the working tree of a shared checkout.
- Find the introducing change (`git log -S'<symbol>' origin/main -- <path>`): "regression since #N" and "always been so" are different bugs. Check `git rev-parse --is-shallow-repository` first: in a shallow clone the answer is the graft boundary, not the author. Do not deepen a clone other sessions share; read the file's history from GitHub (`gh api "repos/<org>/<repo>/commits?path=<file>&per_page=20"`), or report the introducing change as not established.
- Write 2-4 hypotheses. Each names one observation it predicts and the others do not. A hypothesis that predicts nothing distinct is not ready to test.
- Search before deriving: the trap notes above (`ls .claude/skills | grep -i <domain>`), closed issues. A repo skill can predate the primitive that now handles its problem; check its date against current code before following it.

## Gate A: confirming questions (required before anything is built, launched or posted)

This skill's rule for every run: decide no tiny thing alone, and ask 10-20
confirming questions before reproducing or fixing. It overrides Auto Mode and
any other lean toward fewer questions.

Ground first (phases 0-2), then ask. Whatever the code, NIP text, relay or issue
can settle is found out, then put to the user as a confirmation: "I read C2 as X
because <file:line@sha>. Right?" Every question names the finding that makes it
open, puts your recommendation first, and changes what you do next. A question
you could ask of any issue is not ready.

Use the client's question tool (`AskUserQuestion` in Claude Code; in a client
without one, numbered questions in chat), at most 4 per round, so 3-5 rounds.
One question per row that applies:

| Area | Confirm |
|---|---|
| Claims | Your reading of each C<n>: expected vs actual, the implied claims, the falsifier |
| Cause | Which hypothesis to test first, which layer you think is wrong |
| Reported on | Build, OS, account state to match; LOCAL, STAGING or PRODUCTION |
| Environment | Device or simulator, debug or profile, SHA, shared hardware |
| Risk | Each action in the list below that this run would take |
| Scope | Fix here or follow-up issue; adjacent findings; parity (Android, web) |
| Product | "Should it…" decisions, copy, what counts as fixed |
| Delivery | Test layer, PR shape, what to post on the issue and whether |

The ask-the-user items, always the user's call and never defaulted: writes to
production relays or a real account; wiping app data; replacing an installed
build; profile/release builds (production bundle id); changing global tool
config; anything that notifies on GitHub. If one comes up after this gate, ask
again before taking it.

Facts only the reporter holds (build number, sign-in method, what else they
tried) go in one issue comment, draft shown to the user first. Do not wait for
the answer: test both branches. Product behaviour ("should it…") on an assigned
issue is posted to the issue with a recommendation, after the user has seen the
draft.

Print the ledger after each round:

```
Questions: <answered>/10-20  rounds=<n>
Q<n> | area | question | answer
```

The gate is open when the ledger holds at least 10 answered questions. Fewer is
an unfinished gate and §3 does not start. Later rounds are for forks the earlier
answers opened; past 10, stop when no fork is open. 20 is the ceiling.

## 3. Reproduce live

Before the first build read `.claude/rules/ios_build_troubleshooting.md` and
`flutter-lens.md` §0-1, then print:

```
Run: sha=<…>  mode=<debug | profile | release>  env=<LOCAL | STAGING | PRODUCTION>  device=<udid, iOS version>
Shared hardware: phone=<free | held by session …>  simulator=<udid>  local_stack=<not needed | shared>
Logs: <file>  categories=<…>
```

1. **Provenance.** Prove the binary under test is the SHA, flavor and environment you name (not the install that was already on the device).
2. **Capture first.** Start log capture before launch; one timestamped file per run.
3. **Script the steps** so run 2 equals run 1. Human timing is a last resort.
4. **Probe the boundaries** at the moment of failure: screen, bloc state, cache, wire, relay. The bug lives at the first boundary where expected and actual diverge.
5. **Count.** Report `fails k/n`; one run is an anecdote. A run counts only while `flutter-machine.sh taint` is clean up to its last step (`flutter-lens.md` §4).
6. **Control.** Flip exactly one variable (the suspected cause) and show the outcome flips: A (bug) → B (cause removed) → A′ (bug back).
7. **Conditions you cannot wait for.** "Leave it 30 hours" or "on cellular" is reproduced by setting the thing the condition acts through: a timestamp, a cursor, a token expiry, the device clock; a refused connect, a late EOSE, a lost OK (`scripts/relay-fault-proxy.dart`). Label it simulated. The real condition is a separate, named gap under "Not verified".

## 4. Adjacent sweep

Run the lens rows that touch the same code path (`flutter-lens.md` §6
adversarial rows, `nostr-lens.md` §5 failure classes), and read the
whole run's errors (`get_runtime_errors`, uncaught exceptions, relay `OK false`
and `CLOSED` lines), not only the lines about this issue. Each finding becomes a
claim with its own tags. Findings outside the issue are listed, never fixed here.

## Gate B: validation report, then stop

```
Verdict: <one line>
C<n> | <Confirmed | Confirmed, different cause | Not reproducible | Already fixed on main | Not a client bug → <repo> | Works as specified> | tags: <D C T M R S X> | evidence: <log file:line, event id, NN.md:line@sha, test name>
Cause: <first diverging boundary, file:line at sha, introducing change>
Adjacent findings: <claim | tags | in scope? >
Not verified: <what was only read, or could not be reached, and what would settle it>
Open decisions: <for the user: fix here or follow-up issue for each finding, and anything else only they can decide>
```

| Tag | Meaning |
|---|---|
| D | Observed on device/simulator at a named SHA, with the log line or state read |
| C | Control: one variable flipped, outcome flipped |
| T | Failing-first automated test |
| M | Mutation: fix removed, test goes red |
| R | Relay ground truth: the event JSON itself, from a query that was positively controlled |
| S | Spec text quoted at a SHA |
| X | Read from code only |

At this gate `Confirmed` needs D or T, plus C. A protocol claim also needs R
and S. After the fix, the fix is proven by T plus M, and by D replayed on the
fixed build. X alone never confirms anything; it goes under "Not verified".
Outward posts state the checks in words and carry no scores.

## 5-6. Fix and deliver (only after the user's go on Gate B)

Own worktree from `origin/main`. **REQUIRED SUB-SKILLS:**
superpowers:systematic-debugging, superpowers:test-driven-development (the
team's Superpowers baseline; install it per divine-context `SUPERPOWERS.md`),
then the
repo's verification ladder (`.claude/rules/self_review_checklist.md`, "Before
committing"). The regression test sits at the lowest layer that shows the
bug; removing the fix must turn it red (commit before mutating). Replay the
phase-3 script on the fixed build and report the same `k/n`. Check parity paths:
other callers, Android, web. Draft every PR body, review and comment and show
it before posting.

## Red flags

| Thought | What it means |
|---|---|
| "It reproduced" (once) | No count, no control. Not confirmed. |
| "The query returned nothing" | An empty result is a claim. Show the same query returning something it should. |
| "The logs show nothing" | Which sink? Relay-category lines and `dart:developer` logs are not in the default console. |
| "The NIP says…" from memory | Open `<root>/nips/NN.md` at the pinned SHA and quote the line. |
| "Debug reproduces it" for a TestFlight report | Release is AOT with asserts off. Say which mode you proved it in. |
| "I can find that out, so I won't ask" | Find it out, then ask the user to confirm what you found. |
| "The issue is clear, I'll skip the questions" | The ledger says otherwise. Under 10 answered, Gate A is closed. |
| "Auto Mode says to minimize interruptions" | This skill's 10-20 rule is explicit and wins. |
| "Every recommendation was taken, so I'm done" | Done only once the ledger holds 10 answered. |
| "Probably unrelated" about an error in the run | Unproven. It is an adjacent finding until traced. |
| "A subagent can run the tests" | Brief it: no `integration_test` and no device-picking command. Every device run names `-d` (`flutter-lens.md` §0). |
| "The app threw, so the bug reproduced" | Run `taint` first. A probe that wrote mid-frame makes errors no user can reach; #10439 was filed from one. |
