# Working on an existing PR

This file covers the case where the branch already exists and a pull
request is already open on it — you are pushing to someone's PR rather
than starting fresh work. `agent_workflow.md` covers new work; this
file covers everything that happens after a PR exists.

The cross-repo runbook is `PR_REVIEW.md` in the `divine-context`
handbook. That file is the source of truth for takeover authority, and
it lives outside this repo — loaded via a SessionStart hook for Claude
Code and via `~/.codex/AGENTS.md` for Codex. **Do not depend on it
being loaded.** The gates below are the repo-local minimum and apply
whether or not the handbook is in context. Where the two overlap,
`PR_REVIEW.md` is authoritative and this file is the floor. If
`PR_REVIEW.md` or its team mapping is unavailable, same-repo takeover
must stop: leave the PR open and report the missing runbook as the
blocker.

---

## 1. Establish authorship before you touch anything

**This is the first step, before reading the diff, before running
tests, before planning a fix.** Which of the three cases you are in
changes every rule that follows.

```bash
gh pr view <number> --json number,author,headRefName,isCrossRepository,\
state,isDraft,mergeStateStatus,maintainerCanModify
gh api user --jq .login   # who am I authenticated as?
```

Compare `author.login` against the authenticated account.
`maintainerCanModify` is meaningful only when `isCrossRepository` is
true; same-repo PRs can report `false` even when you can push.

| Case | What it means | Which rules apply |
|---|---|---|
| `author.login` == you | **You are the author.** Not a takeover. | Author gates (§3, §4). Takeover gates do not apply — you cannot review or approve your own PR. |
| `author.login` != you, `isCrossRepository` false | **Same-repo takeover.** | Every gate in `PR_REVIEW.md` §"Shared takeover gates", then §3, §4. |
| `isCrossRepository` true | **Fork PR.** | Takeover gates *plus* `maintainerCanModify` must be true. If false, you cannot push — use suggested changes or a review comment. |

Additional read-only cases, regardless of authorship:

- `isDraft` true → read-only unless the author explicitly asked for
  implementation.
- The request was framed as feedback-only → read-only.

**Never discover authorship by trial and error.** If your first
signal that you are the author is GitHub rejecting the call —
`Review Can not request changes on your own pull request`, or
`Can not approve your own pull request` — you skipped this step and
every downstream decision was made under the wrong model. Back up and
redo the triage.

### When you are the author

Working as the author is not the relaxed path — it is the stricter one:

- You cannot submit `APPROVED` or `CHANGES_REQUESTED` on your own PR.
  Findings you cannot resolve go in a **regular issue comment**,
  clearly labelled as a blocker or an open decision.
- There is nobody downstream to catch a red build. §3 is unconditional.
- "Escalate to the author for a judgment call" resolves to **escalate
  to the human running the session**. Say so plainly and stop; do not
  decide it yourself because you happen to hold the author's
  credentials.

### Ground the review before choosing a review state

These checks apply to every review, including report-only reviews and reviews
where no branch modification is planned.

After establishing authorship, pin the exact commit being reviewed. Verify
every cited path, line range, identifier, and quoted snippet against that
commit, not the current checkout or a reconstructed version of the code:

```bash
gh pr view <number> --json mergedAt,headRefOid
git fetch origin pull/<number>/head
git cat-file -e '<commit>^{commit}'
git cat-file -e '<commit>:<path>'
git show '<commit>:<path>' | sed -n '<start>,<end>p'
git grep -n -F -- '<snippet>' '<commit>' -- '<path>'
git log --all -S'<snippet>' -- '<path>'
```

The commit-object check must succeed before any path or snippet check. Treat a
`fatal:` result or exit status 128 as a broken lookup and stop; it is not
evidence that the cited content is absent. For `git grep`, exit status 1 means
the lookup succeeded and the snippet was not found.

The last command is supporting history only; the reviewed commit is the
authority. A nearby comment that describes a rejected pattern is not evidence
that the implementation contains that pattern. If a citation or claim cannot
be grounded in the reviewed commit, remove the finding rather than softening
or qualifying it.

Check `mergedAt` before choosing a GitHub review state. Never submit
`CHANGES_REQUESTED` after a pull request has merged: it cannot block the merge
and reads as an outstanding author action. Use an authorized ordinary `gh pr comment` for useful
retrospective feedback, or file a separately authorized issue when verified
follow-up work is required.

### Submit an explicit review verdict

Once posting is authorized, completing a review means submitting a GitHub
review with a verdict that matches the findings. A body saying "No actionable
findings" with state `COMMENTED` is not an approval. An issue comment, inline
comments alone, or an unsubmitted `PENDING` review does not deliver a verdict.

| Review outcome on an open pull request | Submit |
| --- | --- |
| Review complete, sufficient evidence, no unresolved merge-blocking findings | `APPROVE` (`gh pr review --approve`), including when there are optional suggestions |
| Verified unresolved finding that must be fixed before merge | `REQUEST_CHANGES` (`gh pr review --request-changes`), with the defect, evidence, and required remediation |
| Partial review, missing evidence needed to decide, draft feedback, or explicitly advisory feedback | `COMMENT` (`gh pr review --comment`), stating why no approval/change-request verdict is possible and what remains |

Do not choose `COMMENT` merely because you are an agent, did not rerun tests
locally, have nonblocking suggestions, or are not the person who will merge.
Assess whether the available evidence is sufficient and disclose validation
limits. Missing essential validation means the review is incomplete, not clean.
Approval records the reviewer's conclusion; it does not waive required CI,
independent review, owner approval, or the author's merge decision.

Posting authority does not grant branch-modification authority. When a blocker
is verified and you are not authorized to fix the branch, request changes.
When remediation is authorized, fix and validate it, then review the resulting
head. Never approve merely because you wrote the fix; satisfy the governing
independent-review requirements.

Before submitting, read the authenticated login and the pull request's author,
`state`, `isDraft`, `mergedAt`, and `headRefOid`. If the acting account is the
PR author, GitHub cannot accept its approval or change request: report that
limitation and identify the eligible reviewer needed. Request their review only
when the task or governing workflow authorizes it. Do not switch accounts to
evade the restriction or describe a comment as approval. If the PR is merged or closed,
use an authorized ordinary comment for useful retrospective feedback instead
of an approval or change request.

Pin the submission to the full commit SHA you actually reviewed. If the head
moved, review the new changes before giving a current-head verdict. The REST
API supports an explicit `commit_id`; write a JSON file containing that SHA,
`event` (`APPROVE`, `REQUEST_CHANGES`, or `COMMENT`), and the review `body`, then
submit it with:

```bash
gh api --method POST repos/OWNER/REPO/pulls/NUMBER/reviews --input review.json
```

With `gh pr review`, use `--repo OWNER/REPO`, the appropriate verdict flag and
`--body-file`; recheck the head immediately before submitting. With either
method, fetch the resulting review and the live PR head afterward. Verify its
`state` is `APPROVED`, `CHANGES_REQUESTED`, or `COMMENTED` as intended, its
`commit_id` equals the reviewed SHA, and `submitted_at` is present. If the head
changed during submission, report that the verdict covers the older commit
and re-review before claiming the current head is approved.

Return the review URL, saved verdict, and reviewed SHA. A successful CLI exit
or an overall `reviewDecision` alone is insufficient: other reviewers and
branch rules affect the aggregate. If submission fails, report the actual
error and remaining action; do not silently fall back to a comment and call
the review delivered. If retrying after an uncertain response, inspect existing
reviews first to avoid duplicate submissions. On an authorized re-review, if
previous blockers are resolved, submit a new approval for the reviewed head
instead of only commenting "fixed"; do not dismiss another reviewer's decision.


---

## 2. Answer every review item, or say why not

Before pushing, enumerate the review items and decide each one. Fetch
inline threads too — a PR can carry substantive findings with zero
inline threads, or findings only in outdated threads:

```bash
gh pr view <number> --json reviews --jq '.reviews[] | "\(.author.login) \(.state)\n\(.body)"'
gh api graphql -f query='
{ repository(owner:"divinevideo",name:"divine-mobile"){ pullRequest(number:NNN){
  reviewThreads(first:100){ nodes { isResolved isOutdated path line
    comments(first:10){ nodes { author{login} body } } } } } } }'
```

Every item lands in exactly one bucket: **fixed**, **escalated**
(needs product/architecture judgment — name the decision), or
**declined** (say why). An item you silently skip reads to the
reviewer as an item you fixed.

State the buckets in the handback comment. A summary that lists four
bullets of what you changed, when the review raised eight items, is a
misleading handback even when every bullet is true.

**Do not add unrequested changes without flagging them.** If you find
a real bug the reviewer did not raise, that is worth fixing — but call
it out separately as *not requested by the review*, especially when it
carries user-visible blast radius (cache-key bumps that invalidate
every device, migrations, schema changes, defaults). Bury it in a
bullet list of review fixes and nobody signs off on it.

---

## 3. Do not hand back until checks are green

**Pushing is not the end of the task. Green CI is.**

After every push to a PR branch, wait for the checks to finish and
read the result:

```bash
gh pr checks <number> --watch
```

Then, and only then, post the handback comment.

**Forbidden:**

- Posting "I pushed the fixes" before checks have completed. The
  comment must be written *after* you have read the result, not
  optimistically alongside the push.
- Ending the turn with red checks and no explanation.
- Reporting a subset of checks as "green" when others are red or
  still running.

If checks are red, fix them and push again. Repeat until green. A
failure you introduced is yours to fix — see
`agent_workflow.md` §5.

The **only** acceptable red handback is a failure you have positively
proven is not caused by your diff. Proving it means naming the actual
cause — the commit, the PR, or the ref that broke it — following the
procedure in `agent_workflow.md` §5 ("When the failure is not yours").
"Looks unrelated" is not proof. When you do hand back red, the comment
must state the blocking cause and what unblocks it.

---

## 4. Scope, commits, and history

- Keep changes within the intent and reasonable scope of the PR.
- Push each distinct finding as its own commit where practical, so the
  author can revert one without losing the others.
- Do not force-push someone else's branch unless a rebase is required
  by merge conflicts or stale-base policy, or the author authorized
  the rewrite. When you must, use `--force-with-lease`.
- If GitHub reports no merge conflicts and your push only addresses
  review feedback, do not rebase to refresh history — see
  `agent_workflow.md` §2.
- Never modify workflows, security-sensitive code, permission
  boundaries, infrastructure, deploy config, or release automation
  through takeover without separate explicit authorization.

The author keeps the merge decision. Takeover never includes merging.
