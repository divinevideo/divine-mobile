// This helper runs from the trusted default-branch deployment workflow.
const BUILD_WORKFLOW_PATH = '.github/workflows/mobile_pr_preview_build.yml';
const SHA_PATTERN = /^[a-f0-9]{40}$/;
// compareCommitsWithBasehead(`${firstParent}...main`) statuses meaning main
// contains the first parent.
const ON_MAIN_STATUSES = new Set(['ahead', 'identical']);
const GITHUB_COMMITTER_EMAIL = 'noreply@github.com';

// GitHub builds pull_request runs on a test merge of the PR head into main's
// tip at event time, so the first parent is any commit main contains, not the
// PR's recorded base.sha. Fork runs carry an untrusted artifact, so they also
// require the merge to be GitHub's own signed commit.
function isGitHubTestMerge(commit) {
  return (
    commit.verification?.verified === true &&
    commit.committer?.email === GITHUB_COMMITTER_EMAIL
  );
}

function previewProvenance({
  run,
  pr,
  metadata,
  commit,
  firstParentComparison,
  associatedPulls = [],
}) {
  const association = run.pull_requests?.find((p) => p.number === pr.number);
  const fallback =
    !association &&
    !run.pull_requests?.length &&
    associatedPulls.some((p) => p.number === pr.number);

  if (
    run.event !== 'pull_request' ||
    run.conclusion !== 'success' ||
    run.path !== BUILD_WORKFLOW_PATH ||
    (!association && !fallback) ||
    pr.head.sha !== run.head_sha ||
    pr.head.ref !== run.head_branch ||
    pr.head.repo.id !== run.head_repository.id ||
    pr.base.ref !== 'main'
  ) {
    throw Error('Preview run does not match PR');
  }

  const build = metadata.build_sha;
  if (
    !SHA_PATTERN.test(build) ||
    commit.sha !== build ||
    commit.parents.length !== 2 ||
    commit.parents[1].sha !== run.head_sha ||
    !ON_MAIN_STATUSES.has(firstParentComparison) ||
    (fallback && !isGitHubTestMerge(commit))
  ) {
    throw Error('Preview merge provenance is invalid');
  }

  return {
    prNumber: pr.number,
    headSha: run.head_sha,
    buildSha: build,
    headRef: run.head_branch,
  };
}

module.exports = { previewProvenance };
