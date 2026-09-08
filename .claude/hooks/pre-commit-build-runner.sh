#!/bin/bash
# Git pre-commit hook component
# Runs build_runner if any staged Dart files contain code generation annotations
#
# Annotations: @riverpod, @Riverpod, @JsonSerializable,
#   @GenerateMocks, @HiveType, @DriftDatabase, @DriftAccessor

set -e

# Filter: only run on git commit commands
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0
FIRST_CMD=$(echo "$COMMAND" | head -1 | sed 's/\s*&&.*//' | sed 's/\s*|.*//' | sed 's/\s*;.*//')
echo "$FIRST_CMD" | grep -qE '^\s*git\s+commit\b' || exit 0

# Get staged Dart files (excluding generated files)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$' | grep -v '\.g\.dart$' || true)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# Collect package roots that need build_runner
PACKAGE_ROOTS=""

for FILE in $STAGED_FILES; do
  # Skip if file doesn't exist
  [ -f "$FILE" ] || continue

  # Check if file contains code generation annotations
  if grep -qE '@(riverpod|Riverpod|JsonSerializable|GenerateMocks|HiveType|DriftDatabase|DriftAccessor)' "$FILE"; then
    # Find the package root
    PACKAGE_DIR="$FILE"
    while [ "$PACKAGE_DIR" != "." ] && [ "$PACKAGE_DIR" != "/" ]; do
      PACKAGE_DIR=$(dirname "$PACKAGE_DIR")
      if [ -f "$PACKAGE_DIR/pubspec.yaml" ]; then
        # Add to set of package roots (dedup)
        if ! echo "$PACKAGE_ROOTS" | grep -q "^${PACKAGE_DIR}$"; then
          PACKAGE_ROOTS="${PACKAGE_ROOTS}${PACKAGE_DIR}
"
        fi
        break
      fi
    done
  fi
done

# Run build_runner for each unique package root
if [ -n "$PACKAGE_ROOTS" ]; then
  echo "$PACKAGE_ROOTS" | while read -r ROOT; do
    [ -z "$ROOT" ] && continue
    echo "Running build_runner in $ROOT..."
    (cd "$ROOT" && dart run build_runner build --delete-conflicting-outputs 2>&1) || {
      echo "ERROR: build_runner failed in $ROOT"
      exit 1
    }
  done

  # Stage any regenerated files
  for FILE in $STAGED_FILES; do
    GENERATED="${FILE%.dart}.g.dart"
    [ -f "$GENERATED" ] && git add "$GENERATED"
  done
fi

exit 0
