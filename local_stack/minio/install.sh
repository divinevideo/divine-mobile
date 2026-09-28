#!/bin/sh
# Usage: install.sh <module> <release tag> <commit>
#
# Builds a MinIO module at <commit> with the ldflags MinIO's own release build
# sets (buildscripts/gen-ldflags.go), so `--version` reports the release the
# way the published binaries did.
set -eu

module="$1"
release="$2"
commit="$3"

stamp="${release#RELEASE.}"
version="$(printf '%s' "$stamp" | sed -E 's/T([0-9]{2})-([0-9]{2})-([0-9]{2})Z$/T\1:\2:\3Z/')"
short_commit="$(printf '%s' "$commit" | cut -c1-12)"
pkg="${module}/cmd"
max_attempts=3

# Unlike `docker pull`, `go install` does not retry a dropped download. The
# module cache mount keeps what already arrived, so a retry fetches only the
# rest.
attempt=1
until go install -trimpath -ldflags "-s -w \
  -X ${pkg}.Version=${version} \
  -X ${pkg}.ReleaseTag=${release} \
  -X ${pkg}.CommitID=${commit} \
  -X ${pkg}.ShortCommitID=${short_commit} \
  -X ${pkg}.CopyrightYear=${stamp%%-*}" \
  "${module}@${commit}"; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    exit 1
  fi
  echo "go install ${module} failed (attempt ${attempt} of ${max_attempts}); retrying" >&2
  attempt=$((attempt + 1))
done
