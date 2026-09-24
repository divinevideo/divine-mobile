#!/bin/bash
# Install git hooks for divine-mobile development
# Run this once after cloning the repo, or via: cd mobile && mise run setup_hooks
#
# The hooks directory is shared by every worktree of a clone, so what goes in
# it is a thin shim, not the checks themselves. At run time the shim finds the
# worktree it was invoked from and execs that worktree's tracked
# scripts/hooks/<name>. Each worktree therefore runs the checks its own branch
# carries, an edit to them needs no re-install, and nothing a worktree does
# rewrites the hooks another worktree is using.

set -e

# An exported CDPATH makes `cd` print where it lands, or land in a same-named
# directory elsewhere, and the command substitution below captures either.
unset CDPATH

GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
if [[ "$GIT_COMMON_DIR" != /* ]]; then
  GIT_COMMON_DIR="$(cd "$GIT_COMMON_DIR" && pwd)"
fi
HOOKS_DIR="$GIT_COMMON_DIR/hooks"
mkdir -p "$HOOKS_DIR"

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required but not found on PATH."
  echo "Install mise: https://mise.jdx.dev/getting-started.html"
  exit 1
fi

# Stage inside the hooks directory: the rename then stays on one filesystem,
# so it is atomic, and files created here get the umask's mode rather than
# mktemp's 0600, which would leave other accounts unable to run the hooks.
STAGING_DIR="$(mktemp -d "$HOOKS_DIR/.install-hooks.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

# Install by rename. A rename leaves the inode an already-running hook is
# reading untouched, so a hook still running in another worktree finishes the
# script it started instead of resuming at its old byte offset inside the new
# one — which matters most for the first install over a pre-shim hook.
install_shim() {
  local name="$1" staged="$STAGING_DIR/$1"
  sed "s/@HOOK_NAME@/$name/g" > "$staged" << 'EOF_SHIM'
#!/bin/bash
# divine-mobile @HOOK_NAME@ shim, installed by scripts/install-hooks.sh.
# Runs the tracked scripts/hooks/@HOOK_NAME@ of whichever worktree git invoked
# it from. Do not edit; edit scripts/hooks/@HOOK_NAME@ instead.

unset CDPATH

if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || [ -z "$REPO_ROOT" ]; then
    echo "warning: @HOOK_NAME@ hook skipped: not inside a divine-mobile worktree." >&2
    exit 0
fi

HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/@HOOK_NAME@"
if [ ! -f "$HOOK_SCRIPT" ]; then
    # Fail open: a branch older than the tracked hooks has none to run, and
    # blocking it would make old branches uncommittable.
    echo "warning: @HOOK_NAME@ checks skipped: this branch has no scripts/hooks/@HOOK_NAME@." >&2
    echo "         Rebase onto origin/main to get the local checks back." >&2
    exit 0
fi

exec bash "$HOOK_SCRIPT" "$@"
EOF_SHIM
  chmod +x "$staged"
  mv "$staged" "$HOOKS_DIR/$name"
}

echo "Installing git hooks..."

install_shim pre-commit
install_shim pre-push

echo "Git hooks installed!"
echo ""
echo "Pre-commit: format check, codegen verification"
echo "Pre-push:   merge conflict check, analyze, codegen verification,"
echo "            ARB locale consistency, untested-services floor, tests for changed files"
echo ""
echo "The hooks run each worktree's scripts/hooks/, so edits there need no re-install."
echo "To bypass hooks (not recommended): --no-verify"
