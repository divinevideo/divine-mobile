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

- You cannot submit `APPROVED` or `CHANGES_REQUESTED` on your own PR. The
  conclusion still gets delivered: submit it as a **`COMMENT`-state review**,
  or a regular issue comment when no review can be submitted, with findings
  you cannot resolve clearly labelled as a blocker or an open decision.
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

The commit-object check must succeed before any path or snippet check: a
`fatal:` result or exit status 128 from `git cat-file -e '<commit>^{commit}'`
means that lookup itself is broken (unfetched commit, wrong ref) and is not
evidence about the cited content — stop and fix the lookup rather than
reasoning about the finding. Once the commit resolves, a `fatal:`/128 from the
*path* check (`git cat-file -e '<commit>:<path>'`) means the opposite: the
path does not exist at that commit, which is real evidence for a finding
about a deleted, renamed, or relocated file — do not discard it as
inconclusive. For `git grep`, exit status 1 means the lookup succeeded and the
snippet was not found.

The last command is supporting history only; the reviewed commit is the
authority. A nearby comment that describes a rejected pattern is not evidence
that the implementation contains that pattern. If a citation or claim cannot
be grounded in the reviewed commit, remove the finding rather than softening
or qualifying it.

Check `mergedAt` before choosing a GitHub review state. Never submit
`CHANGES_REQUESTED` after a pull request has merged: it cannot block the merge
and reads as an outstanding author action. On a merged pull request, use an
authorized plain `COMMENT` review (`gh pr review <n> --comment --body-file
<file>`) for useful retrospective feedback, or file a separately authorized
issue when verified follow-up work is required.

---

## Submit an explicit review verdict

Once posting is authorized, completing a review means submitting a GitHub
review with a verdict that matches the findings. A body saying "No actionable
findings" with state `COMMENTED` is not an approval. An issue comment, inline
comments alone, or an unsubmitted `PENDING` review does not deliver a verdict.

| Review outcome on an open pull request | Submit |
| --- | --- |
| Review complete, sufficient evidence, no unresolved merge-blocking findings | `APPROVE` (`gh pr review --approve`), including when there are optional suggestions |
| Verified unresolved finding that must be fixed before merge and that you are not authorized to resolve directly (or that needs a named owner decision) | `REQUEST_CHANGES` (`gh pr review --request-changes`), with the defect, evidence, and required remediation |
| Partial review, missing evidence needed to decide, draft feedback, or explicitly advisory feedback | `COMMENT` (`gh pr review --comment`), stating why no approval/change-request verdict is possible and what remains |
| Review complete, but the acting account authored the pull request | `COMMENT` (`gh pr review --comment`), stating the conclusion, that GitHub cannot accept a self-approval, and which eligible reviewer owes the verdict |

The table assumes a non-draft pull request. `state: OPEN` alone does not
imply that — a draft is also open, and nothing above gates on `isDraft`.
[Establish authorship](#1-establish-authorship-before-you-touch-anything)
already makes a draft read-only unless the author explicitly asked for
implementation, and that read-only status covers submitting a formal
`APPROVE` the same way it covers pushing code: report findings as advisory
feedback and hold the verdict until the PR is marked ready.

Do not choose `COMMENT` merely because you are an agent, did not rerun tests
locally, have nonblocking suggestions, or are not the person who will merge.
Assess whether the available evidence is sufficient and disclose validation
limits. Missing essential validation means the review is incomplete, not clean.
Approval records the reviewer's conclusion; it does not waive required CI,
independent review, owner approval, or the author's merge decision.

Posting authority does not grant branch-modification authority. When a blocker
is verified and you are not authorized to fix the branch, request changes.
When remediation is authorized, fix and validate it, then review the resulting
head. Approving after you fixed the branch yourself is the normal takeover
flow, not an exception to it — `PR_REVIEW.md`'s "Branch modification
responsibilities" says to submit `APPROVED` after pushing validated fixes.
The one thing that does defeat it is a repository rule naming independent
re-derivation specifically, such as funnelcake's adversarial performance
review (`PR_REVIEW.md`, "Independent verification by a separate agent
session"). Only when a rule like that governs the change does writing the fix
yourself fail to satisfy it; an ordinary takeover fix-and-approve needs
nothing further.

Before submitting, read the authenticated login and the pull request's author,
`state`, `isDraft`, `mergedAt`, and `headRefOid`. If the acting account is the
PR author, GitHub cannot accept its approval or change request. That limits
the *state*, not the delivery: submit the conclusion as a `COMMENT`-state
review — or a plain top-level comment when no review can be submitted — say
plainly that the state is a delivery mechanism and not an approval, and
identify the eligible reviewer needed. Request their review only when the task
or governing workflow authorizes it. Do not switch accounts to evade the
restriction or describe a comment as approval. If the PR is merged or closed,
use an authorized plain `COMMENT` review (`gh pr review <n> --comment
--body-file <file>`) for useful retrospective feedback, or, only when a review
cannot be submitted at all, an ordinary comment (`gh pr comment <n>
--body-file <file>`), instead of an approval or change request.

Pin the submission to the full commit SHA you actually reviewed. If the head
moved, review the new changes before giving a current-head verdict. The REST
API supports an explicit `commit_id`. Write the request body to a scratch file
outside the repository — a bare `review.json` in the working tree is untracked
and trips the clean-workspace rule — then submit it:

```bash
gh api --method POST repos/OWNER/REPO/pulls/NUMBER/reviews \
  --input "${TMPDIR:-/tmp}/review.json"
```

```json
{
  "commit_id": "<full 40-character SHA>",
  "event": "APPROVE",
  "body": "<review body>"
}
```

`event` is load-bearing: omit it and GitHub stores the review as `PENDING`,
which this section already counts as delivering no verdict. Send one of
`APPROVE`, `REQUEST_CHANGES`, or `COMMENT` every time.

With `gh pr review`, use `--repo OWNER/REPO`, the appropriate verdict flag and
`--body-file`; recheck the head immediately before submitting. With either
method, fetch the resulting review and the live PR head afterward:

```bash
gh api repos/OWNER/REPO/pulls/NUMBER/reviews --paginate \
  | jq -s 'add | map(select(.user.login == "<authenticated-login>"))
           | if length == 0
             then error("no review found for <authenticated-login>")
             else .[-1] end
           | {state, commit_id, submitted_at, html_url}'
gh pr view NUMBER --repo OWNER/REPO --json headRefOid --jq .headRefOid
```

Verify its `state` is `APPROVED`, `CHANGES_REQUESTED`, or `COMMENTED` as
intended, and that `submitted_at` is present. Then compare three values: the
SHA you reviewed, the review's saved `commit_id`, and the live `headRefOid`.

A review submitted with `gh pr review` carries no explicit commit, and GitHub
defaults an omitted `commit_id` to the pull request's most recent commit as of
when the submission is processed — so if the head moved between your review
and submission, the saved review attaches to that newer, unreviewed commit,
not the one you read. That is worse than stale: the verdict now certifies code
nobody looked at. It is the `gh pr review` CLI that cannot pin a commit, not
the API: the REST body above and GraphQL `addPullRequestReview`'s `commitOID`
input both take an explicit SHA, so either one works where the CLI does not.

Pinning is necessary but not sufficient, and the failure it leaves behind is
the quiet one. A `commit_id` equal to the SHA you reviewed proves only that
the verdict landed where you aimed it; it says nothing about whether that
commit is still the head. GitHub carries a stale pin forward as a current
approval — #9144 merged with `reviewDecision: APPROVED` whose only approval
was pinned to a commit that was no longer the head — so the newer commits
merge uncertified while this verification passes. Check both directions: if
`commit_id` does not equal the SHA you reviewed, the verdict covers the wrong
commit; if it equals it but `headRefOid` has moved since, the verdict covers a
commit that is no longer current. Either way, review the new head and submit a
verdict pinned to it before treating the review as covering the pull request.

Return the review URL, saved verdict, and reviewed SHA. A successful CLI exit
or an overall `reviewDecision` alone is insufficient: other reviewers and
branch rules affect the aggregate. For who currently blocks or clears the pull
request, read `latestReviews`, which is GitHub's per-reviewer *current* state,
rather than reasoning from the `reviews` history:

```bash
gh pr view NUMBER --repo OWNER/REPO --json latestReviews,reviewRequests \
  --jq '{effective: [.latestReviews[] | {who: .author.login, state: .state}],
         pending: [.reviewRequests[] | (.login // .name)]}'
```

The two disagree whenever a re-request supersedes an earlier verdict: once a
new review is requested from an account, GitHub drops that account's previous
approval from `latestReviews` and lists it under `reviewRequests` instead,
while the full `reviews` history still shows the `APPROVED`. So the
`.[-1]`-by-login filter above answers only "what did I last submit", which is
a different question from "does my verdict still count". `reviewRequests`
carries users as `.login` and teams as `.name`, hence the fallback in the
filter. If submission fails, report the actual
error and remaining action; do not silently fall back to a comment and call
the review delivered. If retrying after an uncertain response, inspect existing
reviews first to avoid duplicate submissions. On an authorized re-review, if
previous blockers are resolved, submit a new approval for the reviewed head
instead of only commenting "fixed"; do not dismiss another reviewer's decision.

---

## 2. Answer every review item, or say why not

Before pushing, enumerate the review items and decide each one. Fetch
inline threads too — a PR can carry substantive findings with zero
inline threads, or findings only in outdated threads. The GraphQL query below
shows only its first page: inspect `pageInfo` and paginate the threads and each
thread's comments until all are read before claiming complete coverage:

```bash
gh pr view <number> --json reviews --jq '.reviews[] | "\(.author.login) \(.state)\n\(.body)"'
gh api repos/OWNER/REPO/pulls/NUMBER/reviews --paginate \
  --jq '.[] | "\(.user.login) \(.state)\n\(.body)"'
gh api graphql -f query='
{ repository(owner:"divinevideo",name:"divine-mobile"){ pullRequest(number:NNN){
  reviewThreads(first:100){ pageInfo{ hasNextPage endCursor }
    nodes { id isResolved isOutdated path line
    comments(first:10){ pageInfo{ hasNextPage endCursor }
      nodes { author{login} body } } } } } } }'
```

`gh pr view --json reviews` already paginates internally and returns every
review regardless of count; the REST form above is here because the
verification step later in this file reads the review's `html_url`, which the
REST payload carries and `--json reviews` does not expose at all. For
`reviewThreads` itself, page with `pageInfo.hasNextPage` / `endCursor` as
shown. The nested `comments` connection is different: it is a separate
connection *per thread node*, so adding `after:` to the shared
`comments(first:10)` selection applies that one cursor to every thread's
comments in the batch, not to a single thread. To read comment 11+ of one
specific thread, query that thread by id instead:

```bash
gh api graphql -f query='
{ node(id: "<thread-id>") { ... on PullRequestReviewThread {
  comments(first: 10, after: "<cursor>") { pageInfo{ hasNextPage endCursor }
    nodes { author{login} body } } } } }'
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

### Close the loop on requested changes

A posted change request creates follow-up work for both the author and the
reviewer. Within an authorized review workflow, closing out your own findings
is part of the job. Report-only instructions still control external actions.
Do not leave an obsolete blocking verdict behind after verifying its resolution.

**Author or fixing agent:** enumerate every finding from review bodies and
inline threads, including outdated and resolved threads. Paginate the threads
and each thread's comments; a truncated first page is not a complete review
history. For each item, link the original finding and record the fixing commit
and validation, or explain why it is disputed, deferred, or awaiting a named
owner. After pushing and inspecting required checks, request re-review from the
original reviewer when authorized (do not duplicate a pending request). Say
"ready for re-review," not "review resolved": the author's response is not the
reviewer's acceptance. Do not dismiss their blocking review or resolve their
thread merely because a fix was pushed.

**Reviewer returning to their findings:**

1. Fetch the current head, open/closed and draft state, previous verdict,
   every original finding and the author's responses. Inspect the actual
   fixes and all intervening changes, with enough surrounding code and
   validation to check for regressions. Do not approve solely from "fixed,"
   green CI, a resolved/outdated thread, or the fact that another reviewer
   approved. A scoped check of your findings alone must not be presented as
   approval of an otherwise unreviewed PR.
2. Give each original finding a disposition: **verified fixed** (commit and
   evidence), **withdrawn** (explain why the finding was wrong), **accepted as
   nonblocking** (explain the remaining risk and any required owner decision),
   or **still blocking / unverified** (state exactly what remains and who owns
   it). Disputed, deferred, or unverified does not mean fixed. Do not invent a
   code change to justify withdrawing an incorrect finding.
3. Reply in each original thread with the disposition and evidence, then
   resolve threads you raised only when their finding is verified fixed,
   withdrawn, or explicitly accepted as nonblocking. Resolve with the
   `resolveReviewThread` mutation, then re-fetch `isResolved` to verify it:

   ```bash
   gh api graphql -f query='
   mutation { resolveReviewThread(input: {threadId: "<thread-id>"}) {
     thread { id isResolved } } }'
   ```

   `<thread-id>` is the `id` of the `reviewThreads` node, which the thread
   query earlier in this section selects. A body-only finding has no
   thread to resolve: link it in the new review's itemized closeout. Leave
   another reviewer's threads to that reviewer unless explicitly delegated;
   write access or a shared posting account alone is not delegation.
4. When the PR is open and non-draft, and the complete current-head review has
   sufficient evidence and no unresolved merge blockers, submit a new `APPROVE`
   review through the same GitHub identity that requested changes, if that is
   the authorized identity available. This is the normal way to supersede your
   own change request; do not merely comment "fixed" or dismiss the old
   review. Recheck the live head immediately before submitting, and prefer the
   SHA-pinned REST form from
   [Submit an explicit review verdict](#submit-an-explicit-review-verdict)
   when the head could move — an unpinned `gh pr review` attaches to whatever
   is newest at submission time, not the commit you just re-reviewed. Keep the
   historical review as the audit trail. If another identity owns the blocking
   verdict, identify that reviewer and request their re-review when
   authorized; your approval does not clear their change request. Never switch
   credentials to impersonate the original reviewer.
5. If verified blockers remain, retain or submit `REQUEST_CHANGES` and update
   the outstanding list. If re-review is incomplete, explain the missing
   evidence without clearing the prior blocker. Do not submit a duplicate
   verdict solely to restate an unchanged finding. For a draft, report the
   verified findings as advisory feedback and leave approval until it is ready.
   If the PR is already merged or closed, follow the retrospective-comment rule
   instead of approving it.
6. Re-fetch the review and thread state. Verify your saved verdict and reviewed
   SHA, check the live head has not moved, and confirm which threads remain
   unresolved and which reviewers still request changes. Thread resolution
   does not clear `CHANGES_REQUESTED`; approval does not resolve threads.
   Report any failed mutation or unavailable permission as incomplete closeout,
   with its next owner, rather than claiming success.

Finish with: **reviewed SHA; each finding's disposition and evidence; review URL
and saved verdict; unresolved threads or other blocking reviewers; next owner
and action**. Distinguish "my findings are closed" from "the PR is ready to
merge." Closing a review is not closing the PR, merging it, closing a linked
issue, or waiving CI, independent review, or owner approval. Those retain their
own authorization and verification requirements.

---

## 3. Do not hand back until checks are green

**After pushing, finish validation before handing back for re-review. Green CI
does not close review findings or clear a change request.**

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
