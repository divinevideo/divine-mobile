#!/bin/bash
# Git pre-commit hook component
# Runs build_runner if any staged Dart files contain code generation annotations
#
# Annotations: @riverpod, @Riverpod, @JsonSerializable,
#   @GenerateMocks, @HiveType, @DriftDatabase, @DriftAccessor

set -e

HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/dart-runner.sh
source "$HOOK_DIR/lib/dart-runner.sh"

emit_deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Filter: only run on git commit commands
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0
FIRST_CMD=$(echo "$COMMAND" | head -1 | sed 's/[[:space:]]*&&.*//' | sed 's/[[:space:]]*|.*//' | sed 's/[[:space:]]*;.*//')
echo "$FIRST_CMD" | grep -qE '^[[:space:]]*git[[:space:]]+commit([[:space:]]|$)' || exit 0

# Collect staged Dart inputs and their package roots without word-splitting paths.
STAGED_FILES=()
PACKAGE_ROOTS=()

while IFS= read -r -d '' FILE; do
  case "$FILE" in
    *.g.dart|*.mocks.dart)
      continue
      ;;
    *.dart)
      ;;
    *)
      continue
      ;;
  esac

  STAGED_FILES[${#STAGED_FILES[@]}]="$FILE"
  [ -f "$FILE" ] || continue

  if grep -qE '@(riverpod|Riverpod|JsonSerializable|GenerateMocks|HiveType|DriftDatabase|DriftAccessor)' "$FILE"; then
    PACKAGE_DIR=$(dirname "$FILE")
    while [ "$PACKAGE_DIR" != "." ] && [ "$PACKAGE_DIR" != "/" ]; do
      if [ -f "$PACKAGE_DIR/pubspec.yaml" ]; then
        ROOT_PRESENT=false
        for ROOT in "${PACKAGE_ROOTS[@]}"; do
          if [ "$ROOT" = "$PACKAGE_DIR" ]; then
            ROOT_PRESENT=true
            break
          fi
        done
        if [ "$ROOT_PRESENT" = false ]; then
          PACKAGE_ROOTS[${#PACKAGE_ROOTS[@]}]="$PACKAGE_DIR"
        fi
        break
      fi
      PACKAGE_DIR=$(dirname "$PACKAGE_DIR")
    done
  fi
done < <(git diff --cached --name-only --diff-filter=ACM -z)

# Run build_runner for each unique package root
if [ ${#PACKAGE_ROOTS[@]} -gt 0 ]; then
  if ! resolve_dart_runner; then
    emit_deny "Unable to run build_runner with the repository Dart SDK: $DART_RESOLUTION_REASON"
  fi

  for ROOT in "${PACKAGE_ROOTS[@]}"; do
    echo "Running build_runner in $ROOT..." >&2
    BUILD_OUTPUT=""
    if ! BUILD_OUTPUT=$(run_repo_dart "$ROOT" run build_runner build --delete-conflicting-outputs 2>&1); then
      BUILD_TAIL=$(printf '%s\n' "$BUILD_OUTPUT" | tail -20)
      emit_deny "build_runner failed in $ROOT:\n$BUILD_TAIL"
    fi
  done

  # Stage any regenerated files
  for FILE in "${STAGED_FILES[@]}"; do
    GENERATED="${FILE%.dart}.g.dart"
    MOCKS="${FILE%.dart}.mocks.dart"
    if [ -f "$GENERATED" ]; then
      git add "$GENERATED"
    fi
    if [ -f "$MOCKS" ]; then
      git add "$MOCKS"
    fi
  done
fi

exit 0
