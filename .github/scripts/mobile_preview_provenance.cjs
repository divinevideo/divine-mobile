// This helper runs from the trusted default-branch deployment workflow.
const BUILD_WORKFLOW_PATH = '.github/workflows/mobile_pr_preview_build.yml';
const SHA_PATTERN = /^[a-f0-9]{40}$/;

function previewProvenance({ run, pr, metadata, commit, associatedPulls = [] }) {
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
    (association
      ? commit.parents[0].sha !== association.base.sha
      : build !== pr.merge_commit_sha) ||
    commit.parents[1].sha !== run.head_sha
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
