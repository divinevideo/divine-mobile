const { test } = require('node:test');
const assert = require('node:assert/strict');
const { previewProvenance } = require('../mobile_preview_provenance.cjs');

const head = 'a'.repeat(40);
const base = 'b'.repeat(40);
const built = 'c'.repeat(40);

const input = () => ({
  run: {
    event: 'pull_request',
    conclusion: 'success',
    path: '.github/workflows/mobile_pr_preview_build.yml',
    head_sha: head,
    head_branch: 'feature',
    head_repository: { id: 1 },
    pull_requests: [{ number: 3, base: { sha: base } }],
  },
  pr: {
    number: 3,
    state: 'open',
    draft: false,
    head: { sha: head, ref: 'feature', repo: { id: 1 } },
    base: { ref: 'main' },
    merge_commit_sha: built,
  },
  // Deliberately disagrees with GitHub's run metadata: the helper must ignore it.
  metadata: { pr_number: 999, head_sha: 'f'.repeat(40), build_sha: built },
  commit: { sha: built, parents: [{ sha: base }, { sha: head }] },
});

test('derives PR identity from the originating GitHub run, not artifact fields', () => {
  assert.deepEqual(previewProvenance(input()), {
    prNumber: 3,
    headSha: head,
    buildSha: built,
    headRef: 'feature',
  });
});

test('rejects mismatched head/repository, unassociated PRs and unrelated build commits', () => {
  const alterations = [
    (v) => { v.pr.head.sha = 'd'.repeat(40); },
    (v) => { v.pr.head.repo.id = 2; },
    (v) => { v.run.pull_requests = []; },
    (v) => { v.commit.parents = [{ sha: base }, { sha: 'e'.repeat(40) }]; },
    (v) => { v.run.path = 'untrusted.yml'; },
    (v) => { v.metadata.build_sha = 'x\noutput=value'; },
  ];
  for (const alter of alterations) {
    const v = input();
    alter(v);
    assert.throws(() => previewProvenance(v));
  }
});

test('uses trusted commit-associated PRs when fork runs omit pull_requests', () => {
  const v = input();
  v.run.pull_requests = [];
  v.associatedPulls = [{ number: 3 }];
  assert.equal(previewProvenance(v).prNumber, 3);
  v.pr.merge_commit_sha = 'd'.repeat(40);
  assert.throws(() => previewProvenance(v));
});
