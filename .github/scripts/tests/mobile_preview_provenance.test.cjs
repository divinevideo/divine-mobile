const { test } = require('node:test');
const assert = require('node:assert/strict');
const { previewProvenance } = require('../mobile_preview_provenance.cjs');

const head = 'a'.repeat(40);
const base = 'b'.repeat(40);
const built = 'c'.repeat(40);
// Main's tip when GitHub built the test merge; differs from the PR's base.sha
// whenever main moved after the branch was last rebased.
const mainTip = '9'.repeat(40);

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
  },
  // Deliberately disagrees with GitHub's run metadata: the helper must ignore it.
  metadata: { pr_number: 999, head_sha: 'f'.repeat(40), build_sha: built },
  commit: {
    sha: built,
    parents: [{ sha: mainTip }, { sha: head }],
    committer: { email: 'noreply@github.com' },
    verification: { verified: true },
  },
  firstParentComparison: 'ahead',
});

test('derives PR identity from the originating GitHub run, not artifact fields', () => {
  assert.deepEqual(previewProvenance(input()), {
    prNumber: 3,
    headSha: head,
    buildSha: built,
    headRef: 'feature',
  });
});

test('accepts a test merge built on a main tip newer than the PR base', () => {
  const v = input();
  assert.notEqual(v.commit.parents[0].sha, v.run.pull_requests[0].base.sha);
  assert.equal(previewProvenance(v).buildSha, built);
  v.firstParentComparison = 'identical';
  assert.equal(previewProvenance(v).buildSha, built);
});

test('rejects a first parent that main does not contain', () => {
  for (const status of ['behind', 'diverged', undefined]) {
    const v = input();
    v.firstParentComparison = status;
    assert.throws(() => previewProvenance(v), {
      message: 'Preview merge provenance is invalid',
    });
  }
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
});

test('requires a GitHub-signed test merge on the fork path', () => {
  for (const alter of [
    (v) => { v.commit.verification.verified = false; },
    (v) => { delete v.commit.verification; },
    (v) => { v.commit.committer.email = 'attacker@example.com'; },
  ]) {
    const v = input();
    v.run.pull_requests = [];
    v.associatedPulls = [{ number: 3 }];
    alter(v);
    assert.throws(() => previewProvenance(v), {
      message: 'Preview merge provenance is invalid',
    });
  }
});
