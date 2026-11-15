const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  previewProvenance,
  selectPreviewPr,
} = require('../mobile_preview_provenance.cjs');

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

const RUN_MISMATCH = { message: 'Preview run does not match PR' };
const MERGE_INVALID = { message: 'Preview merge provenance is invalid' };

const assertRejects = (alter, expected) => {
  const v = input();
  alter(v);
  assert.throws(() => previewProvenance(v), expected);
};

test('rejects runs that are not a successful pull_request preview build', () => {
  assertRejects((v) => {
    v.run.event = 'pull_request_target';
  }, RUN_MISMATCH);
  assertRejects((v) => {
    v.run.conclusion = 'failure';
  }, RUN_MISMATCH);
  assertRejects((v) => {
    v.run.path = 'untrusted.yml';
  }, RUN_MISMATCH);
});

test('rejects a PR the run is not associated with', () => {
  // Association path: the run names a different PR.
  assertRejects((v) => {
    v.run.pull_requests = [{ number: 4, base: { sha: base } }];
  }, RUN_MISMATCH);
  // Fallback path: commit-associated PRs name a different PR.
  assertRejects((v) => {
    v.run.pull_requests = [];
    v.associatedPulls = [{ number: 4 }];
  }, RUN_MISMATCH);
  // Fallback is only for runs without pull_requests.
  assertRejects((v) => {
    v.run.pull_requests = [{ number: 4, base: { sha: base } }];
    v.associatedPulls = [{ number: 3 }];
  }, RUN_MISMATCH);
  assertRejects((v) => {
    v.run.pull_requests = [];
  }, RUN_MISMATCH);
});

test('rejects a PR whose head or base differs from the run', () => {
  assertRejects((v) => {
    v.pr.head.sha = 'd'.repeat(40);
  }, RUN_MISMATCH);
  assertRejects((v) => {
    v.pr.head.ref = 'other';
  }, RUN_MISMATCH);
  assertRejects((v) => {
    v.pr.head.repo.id = 2;
  }, RUN_MISMATCH);
  assertRejects((v) => {
    v.pr.base.ref = 'release';
  }, RUN_MISMATCH);
});

test('rejects a build SHA that is not a full lowercase hex SHA', () => {
  for (const malformed of [
    'x\noutput=value',
    built.slice(0, 39),
    built.toUpperCase(),
    [built],
  ]) {
    // Echo the malformed value so SHA validation is the only rejecting check.
    assertRejects((v) => {
      v.metadata.build_sha = malformed;
      v.commit.sha = malformed;
    }, MERGE_INVALID);
  }
});

test('rejects build commits that are not a two-parent merge of the run head', () => {
  assertRejects((v) => {
    v.commit.sha = 'd'.repeat(40);
  }, MERGE_INVALID);
  assertRejects((v) => {
    v.commit.parents = [
      { sha: mainTip },
      { sha: head },
      { sha: 'e'.repeat(40) },
    ];
  }, MERGE_INVALID);
  assertRejects((v) => {
    v.commit.parents = [{ sha: mainTip }, { sha: 'e'.repeat(40) }];
  }, MERGE_INVALID);
});

test('uses trusted commit-associated PRs when fork runs omit pull_requests', () => {
  const v = input();
  v.run.pull_requests = [];
  v.associatedPulls = [{ number: 3 }];
  assert.equal(previewProvenance(v).prNumber, 3);
});

test('requires a GitHub-signed test merge on the fork path', () => {
  for (const alter of [
    (v) => {
      v.commit.verification.verified = false;
    },
    (v) => {
      delete v.commit.verification;
    },
    (v) => {
      v.commit.committer.email = 'attacker@example.com';
    },
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

const candidate = (overrides = {}) => ({
  number: 3,
  base: { ref: 'main', repo: { full_name: 'divinevideo/divine-mobile' } },
  head: { sha: head, ref: 'feature', repo: { id: 1 } },
  ...overrides,
});

const select = (pulls) =>
  selectPreviewPr({
    run: input().run,
    pulls,
    repoFullName: 'divinevideo/divine-mobile',
  });

test('selects the one PR matching the run', () => {
  const match = candidate();
  const stale = candidate({ number: 5 });
  stale.head = { ...stale.head, sha: 'd'.repeat(40) };
  assert.equal(select([stale, match]), match);
});

test('returns null when no PR matches, such as after the head moved', () => {
  assert.equal(select([]), null);
  const c = candidate();
  for (const alter of [
    (p) => {
      p.base.repo.full_name = 'attacker/divine-mobile';
    },
    (p) => {
      p.base.ref = 'release';
    },
    (p) => {
      p.head.sha = 'd'.repeat(40);
    },
    (p) => {
      p.head.ref = 'other';
    },
    (p) => {
      p.head.repo.id = 2;
    },
  ]) {
    const p = structuredClone(c);
    alter(p);
    assert.equal(select([p]), null);
  }
});

test('throws when more than one PR matches the run', () => {
  assert.throws(() => select([candidate(), candidate({ number: 4 })]), {
    message: 'Preview run matches more than one PR',
  });
});

// Execute the actual github-script blocks so workflow wiring is covered too.
const fs = require('node:fs');
const path = require('node:path');
const workflow = fs.readFileSync(
  path.join(__dirname, '../../workflows/mobile_pr_preview_deploy.yml'),
  'utf8',
);
const workflowScript = (name) => {
  const step = workflow
    .split(`      - name: ${name}\n`)[1]
    ?.split('\n      - name: ')[0];
  assert.ok(step, `Missing workflow step: ${name}`);
  const script = step.split('          script: |\n')[1];
  assert.ok(script, `Missing script: ${name}`);
  return script
    .split('\n')
    .map((line) => line.replace(/^            /, ''))
    .join('\n');
};
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const resolveScript = new AsyncFunction(
  'require',
  'github',
  'core',
  'context',
  workflowScript('Resolve preview provenance from the originating run'),
);

const resolvePreview = async (alter = () => {}) => {
  const v = input();
  v.pr.base.repo = { full_name: 'divinevideo/divine-mobile' };
  alter(v);
  const outputs = {};
  const calls = [];
  const github = {
    rest: {
      actions: { getWorkflowRun: async () => ({ data: v.run }) },
      pulls: { get: async () => ({ data: v.pr }) },
      git: {
        getCommit: async () => {
          calls.push('commit');
          return { data: v.commit };
        },
      },
      repos: {
        listPullRequestsAssociatedWithCommit: 'associatedPulls',
        compareCommitsWithBasehead: async (args) => {
          assert.equal(args.basehead, `${mainTip}...main`);
          calls.push('compare');
          return { data: { status: v.firstParentComparison } };
        },
      },
    },
    paginate: async () => v.associatedPulls ?? [],
  };
  const mockedRequire = (name) =>
    name === 'fs'
      ? {
          readFileSync: () => {
            calls.push('metadata');
            return JSON.stringify(v.metadata);
          },
        }
      : require('../mobile_preview_provenance.cjs');
  await resolveScript(
    mockedRequire,
    github,
    {
      setOutput: (key, value) => {
        outputs[key] = value;
      },
    },
    {
      repo: { owner: 'divinevideo', repo: 'divine-mobile' },
      payload: {
        workflow_run: { id: 1 },
        repository: { full_name: 'divinevideo/divine-mobile' },
      },
    },
  );
  return { outputs, calls };
};

test('workflow compares the built first parent to main and emits trusted identity', async () => {
  const { outputs, calls } = await resolvePreview();
  assert.equal(outputs.matched, 'true');
  assert.equal(outputs.pr_number, 3);
  assert.equal(outputs.head_sha, head);
  assert.equal(outputs.build_sha, built);
  assert.deepEqual(calls, ['metadata', 'commit', 'compare']);
});

test('workflow skips stale, closed and draft PRs before inspecting their artifacts', async () => {
  for (const alter of [
    (v) => {
      v.pr.head.sha = 'd'.repeat(40);
    },
    (v) => {
      v.pr.state = 'closed';
    },
    (v) => {
      v.pr.draft = true;
    },
  ]) {
    const { outputs, calls } = await resolvePreview(alter);
    assert.equal(outputs.matched, 'false');
    assert.equal(outputs.build_sha, undefined);
    assert.deepEqual(calls, []);
  }
});

test('workflow rejects invalid merge provenance and non-string build SHAs', async () => {
  await assert.rejects(
    resolvePreview((v) => {
      v.firstParentComparison = 'diverged';
    }),
    MERGE_INVALID,
  );
  await assert.rejects(
    resolvePreview((v) => {
      v.metadata.build_sha = [built];
    }),
    {
      message: 'Invalid build SHA',
    },
  );
});
