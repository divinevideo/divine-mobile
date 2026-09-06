#!/usr/bin/env bash
# Maestro copy-drift guard: every English string the Maestro suite asserts,
# taps, or waits for is bound to the ARB key it came from in
# scripts/baseline/maestro_copy_manifest.txt, and this check fails when the
# current value of that key in lib/l10n/app_en.arb is no longer one of the
# literals the bound flow file uses. Between 2026-03 and 2026-08 the suite
# silently rotted because copy changes and flow changes live in different
# files with nothing failing when they diverged; this is the failure that
# should have fired.
#
# app_en.arb is the ONLY source of truth for English copy. Two failure modes:
#   DRIFT        — a bound ARB key's current value is no longer one of the
#                  literals the bound flow file asserts (copy changed under the
#                  suite, or the flow edited without regenerating). Literals
#                  are compared whole, so shortened copy is caught too. The
#                  message names the key, the flow file, and the current ARB
#                  value to adopt.
#   UNREGISTERED — a flow literal exactly matches a non-parameterized ARB
#                  value but has no manifest binding (new assertion added
#                  without registering). Regenerate to register it.
#
# Manifest format (one binding per line, '#'-comments allowed):
#   <arb_key><TAB><flow path relative to mobile/>[<TAB>bound:<literal>]
#   <arb_key><TAB><flow path relative to mobile/><TAB>rendered:<literal>]
# The 'bound:' third column records the literal the flow asserted when the row
# was auto-derived; it exists so that regeneration and the base-ref ratchet can
# excuse ONLY removals where the flow genuinely stopped asserting that copy —
# renaming an ARB key does not excuse a vanished binding while its literal is
# still asserted. 'rendered:' rows are for PARAMETERIZED ARB values (ICU
# placeholders like {count}): flows assert the rendered string, not the
# template, so the rendered literal is recorded by hand and checked verbatim
# against the flow AND against the template (every literal segment of the
# template must still appear in it, in order). Rendered entries survive
# regeneration; everything else is auto-derived.
#
# Element ids (id: ...) are NOT copy and are out of scope by design; regex
# selectors (e.g. "Search.*") never exactly equal an ARB value and so never
# bind — that is conservative on purpose, not a gap to close with fuzzy
# matching.
#
# Known v1 limit, tracked in #7213: this guard only binds literals that
# already match app_en.arb, so already-drifted flow copy remains invisible
# until the planned inverse literal check lands.
#
# Regenerate after an intentional copy change (review the printed diff of
# added/removed bindings — regeneration re-blesses whatever ARB says today):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_maestro_copy_drift.sh
# Regeneration REFUSES to drop a binding while the flow still asserts its
# recorded literal — a renamed or deleted ARB key does NOT excuse the removal.
# If the flow genuinely stopped asserting that copy, say so explicitly:
#   ACCEPT_REMOVALS=1 UPDATE_BASELINE=1 bash ...
# The check also ratchets against the base ref (MAESTRO_COPY_DRIFT_BASE_REF,
# default origin/main): a binding present on the base manifest may not vanish
# from the branch manifest while its literal is still asserted — that closes
# the bypass where a PR regenerates away its own regression. Bootstrap:
# skipped with a note until the manifest lands on the base ref. Fails closed
# when the base is unloadable; MAESTRO_COPY_DRIFT_ALLOW_NO_BASE=1 is the
# local-only opt-out.
# Usage (from the repo root or mobile/): bash mobile/scripts/check_maestro_copy_drift.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ARB_FILE="$MOBILE_DIR/lib/l10n/app_en.arb"
E2E_DIR="$MOBILE_DIR/e2e/maestro"
MANIFEST_FILE="$SCRIPT_DIR/baseline/maestro_copy_manifest.txt"

MODE="check"
if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
  MODE="regen"
fi

python3 - "$MODE" "$ARB_FILE" "$E2E_DIR" "$MANIFEST_FILE" <<'PYEOF'
import json
import os
import re
import sys

mode, arb_path, e2e_dir, manifest_path = sys.argv[1:5]

def norm(s):
    # YAML folding and source wrapping can split one logical string across
    # whitespace; compare on collapsed whitespace, both sides.
    return " ".join(s.split())

# ---------- load ARB (the only source of truth for English copy) ----------
with open(arb_path, encoding="utf-8") as fh:
    arb_raw = json.load(fh)

exact_values = {}      # value -> [keys] for non-parameterized strings
param_values = {}      # key -> template (contains ICU {placeholder})
multiline_values = set()
for key, val in arb_raw.items():
    if key.startswith("@") or not isinstance(val, str):
        continue
    if "{" in val:
        param_values[key] = val
    else:
        normalized = norm(val)
        exact_values.setdefault(normalized, []).append(key)
        if "\n" in val:
            multiline_values.add(normalized)

all_keys = {k for ks in exact_values.values() for k in ks} | set(param_values)

# ---------- extract asserted/tapped literals from flow YAML ----------
COMMAND_SCALAR = re.compile(
    r"^\s*-\s*(?:assertVisible|assertNotVisible|tapOn|longPressOn):\s*(?P<v>.+?)\s*$"
)
TEXT_PROP = re.compile(r"^\s*text:\s*(?P<v>.+?)\s*$")
# `visible:` / `notVisible:` scalars are the selectors of extendedWaitUntil
# and runFlow.when. A copy change there does not fail the flow: the wait times
# out or the conditional branch is silently skipped, so they are copy to guard
# too. Their map form (`visible:` then `text:` or `id:`) is already covered:
# TEXT_PROP reads the text and ids are not copy.
CONDITION_SCALAR = re.compile(
    r"^\s*(?:visible|notVisible):\s*(?P<v>.+?)\s*$"
)
EXTRACTION_PATTERNS = (COMMAND_SCALAR, TEXT_PROP, CONDITION_SCALAR)
# A YAML block scalar header is `|` or `>` followed by optional chomping
# (`-`/`+`) and indentation (1-9) indicators, in either order. A header
# the extractor does not recognise skips the whole block silently, and
# the header token itself gets counted as an asserted literal.
BLOCK_SCALAR_HEADER = re.compile(r"^[|>](?:[-+]?[1-9]?|[1-9][-+]?)$")

def is_block_scalar_header(v):
    return BLOCK_SCALAR_HEADER.match(v) is not None

def strip_comment(line):
    out = []
    in_s = in_d = False
    for ch in line:
        if ch == "'" and not in_d:
            in_s = not in_s
        elif ch == '"' and not in_s:
            in_d = not in_d
        elif ch == "#" and not in_s and not in_d:
            break
        out.append(ch)
    return "".join(out)

def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        return v[1:-1]
    return v

def searchable_flow_text(lines):
    """Flow text with YAML comments removed but block content preserved."""
    searchable = []
    block_parent_indent = None
    for raw_line in lines:
        raw = raw_line.rstrip("\n")
        stripped = raw.strip()
        indent = len(raw) - len(raw.lstrip())
        if block_parent_indent is not None:
            if not stripped or indent > block_parent_indent:
                searchable.append(raw)
                continue
            block_parent_indent = None

        line = strip_comment(raw)
        searchable.append(line)
        for pat in EXTRACTION_PATTERNS:
            match = pat.match(line)
            if match and is_block_scalar_header(unquote(match.group("v"))):
                block_parent_indent = indent
                break
    return norm("\n".join(searchable))

def flow_literals(path):
    """Literal copy strings a flow asserts, taps, or waits for. Skips
    ${...} interpolations (environment values, not copy), inline maps, and
    selector properties other than text (ids are not copy). Block-scalar
    accessibility labels emit each non-blank line plus any contained multi-line
    ARB value so titles, subtitles, and paragraph copy receive bindings."""
    lits = []

    def add_literal(value):
        v = unquote(value)
        if not v or "${" in v or v.startswith("{"):
            return
        lits.append(norm(v))

    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()

    index = 0
    while index < len(lines):
        raw = lines[index].rstrip("\n")
        line = strip_comment(raw)
        index += 1
        if not line.strip():
            continue
        for pat in EXTRACTION_PATTERNS:
            m = pat.match(line)
            if not m:
                continue
            v = unquote(m.group("v"))
            if is_block_scalar_header(v):
                parent_indent = len(raw) - len(raw.lstrip())
                block_lines = []
                while index < len(lines):
                    block_raw = lines[index].rstrip("\n")
                    if block_raw.strip():
                        indent = len(block_raw) - len(block_raw.lstrip())
                        if indent <= parent_indent:
                            break
                        # Inside a block scalar, `#` is content rather than a
                        # YAML comment marker.
                        block_line = block_raw.strip()
                        block_lines.append(block_line)
                        add_literal(block_line)
                    index += 1
                normalized_lines = [norm(line) for line in block_lines]
                for multiline_value in multiline_values:
                    if any(" ".join(normalized_lines[start:end]) == multiline_value
                           for start in range(len(normalized_lines))
                           for end in range(start + 1, len(normalized_lines) + 1)):
                        add_literal(multiline_value)
            else:
                add_literal(v)
            break
    return lits

mobile_dir = os.path.abspath(os.path.join(e2e_dir, "..", ".."))

# Duplicate English values are common, but generated localization files make
# every ARB key look referenced. Only consider hand-written Dart under the app
# and package lib trees. Prefer a live candidate before using the stable
# alphabetical fallback; otherwise a row can watch a key the app cannot change.
referenced_keys = set()
source_roots = [os.path.join(mobile_dir, "lib"),
                os.path.join(mobile_dir, "packages")]
generated_suffixes = (".g.dart", ".freezed.dart", ".mocks.dart")
for source_root in source_roots:
    if not os.path.isdir(source_root):
        continue
    for root, dirs, names in os.walk(source_root):
        dirs[:] = [d for d in dirs if d not in {"test", ".dart_tool", "build"}]
        rel_root = os.path.relpath(root, mobile_dir)
        if rel_root == "lib/l10n" or rel_root.startswith("lib/l10n" + os.sep):
            dirs[:] = []
            continue
        for name in names:
            if not name.endswith(".dart") or name.endswith(generated_suffixes):
                continue
            with open(os.path.join(root, name), encoding="utf-8",
                      errors="replace") as fh:
                tokens = set(re.findall(r"\b[A-Za-z_]\w*\b", fh.read()))
            referenced_keys.update(tokens & all_keys)

def binding_keys(keys, rel, previous):
    live = sorted(set(keys) & referenced_keys)
    candidates = live or sorted(keys)
    preserved = [key for key in candidates if (key, rel) in previous]
    return [preserved[0] if preserved else candidates[0]]

flows = []
for root, _dirs, names in os.walk(e2e_dir):
    for name in sorted(names):
        if name.endswith(".yaml"):
            flows.append(os.path.join(root, name))
flows.sort()

# literal_norm -> {flow_relpath: arb_key_candidates}
found = {}
total_literals = set()  # every asserted/tapped literal extracted, bound or not
literals_by_flow = {}   # flow_relpath -> set of extracted literals
for fpath in flows:
    rel = os.path.relpath(fpath, mobile_dir)
    for lit in flow_literals(fpath):
        total_literals.add((lit, rel))
        literals_by_flow.setdefault(rel, set()).add(lit)
        keys = exact_values.get(lit)
        if keys:
            found.setdefault((lit, rel), set()).update(keys)

# ---------- manifest load/save ----------

def load_manifest(path):
    if not os.path.isfile(path):
        return {}
    with open(path, encoding="utf-8") as fh:
        return parse_manifest(fh.read())

def parse_manifest(content):
    # (key, rel) -> (rendered, bound): 'rendered' is the hand-maintained
    # literal for a parameterized ARB value; 'bound' is the literal the flow
    # asserted when the binding was auto-derived. The recorded literal is what
    # lets the regen refusal / base-ref ratchet excuse ONLY removals where the
    # flow genuinely stopped asserting the copy — a renamed ARB key does not
    # excuse a vanished binding while its literal is still asserted.
    bindings = {}
    for line in content.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        key, rel = parts[0].strip(), parts[1].strip()
        rendered = bound = None
        if len(parts) >= 3:
            if parts[2].startswith("rendered:"):
                rendered = norm(parts[2][len("rendered:"):])
            elif parts[2].startswith("bound:"):
                bound = norm(parts[2][len("bound:"):])
        bindings[(key, rel)] = (rendered, bound)
    return bindings

# ---------- base-ref ratchet (B2) ----------
# The branch manifest is compared against the base ref's manifest, the same
# pattern as the sibling check_* ratchets (scripts/lib/list_ratchet.sh):
# a binding on the base ref may not vanish from the branch while its ARB key
# and flow file still exist — otherwise UPDATE_BASELINE=1 lets a PR bless its
# own regression. Skipped (bootstrap) until the manifest lands on the base ref.

BASE_REF = os.environ.get("MAESTRO_COPY_DRIFT_BASE_REF", "origin/main")
ALLOW_NO_BASE = os.environ.get("MAESTRO_COPY_DRIFT_ALLOW_NO_BASE", "0") == "1"
MANIFEST_REPO_PATH = "mobile/scripts/baseline/maestro_copy_manifest.txt"
REPO_ROOT = os.path.abspath(os.path.join(e2e_dir, "..", "..", ".."))

def load_base_manifest():
    """(status, bindings): 'ok' | 'bootstrap' (no manifest on base) |
    'unavailable' (base ref unloadable — caller fails closed)."""
    import subprocess

    def git(*args):
        return subprocess.run(["git", "-C", REPO_ROOT, *args],
                              capture_output=True, text=True)

    if git("rev-parse", "--verify", "--quiet", BASE_REF).returncode != 0:
        git("fetch", "--quiet", "--depth=1", "origin", "main")
    if git("rev-parse", "--verify", "--quiet", BASE_REF).returncode != 0:
        return "unavailable", {}
    if git("cat-file", "-e", f"{BASE_REF}:{MANIFEST_REPO_PATH}").returncode != 0:
        return "bootstrap", {}
    raw = git("show", f"{BASE_REF}:{MANIFEST_REPO_PATH}")
    if raw.returncode != 0:
        return "unavailable", {}
    return "ok", parse_manifest(raw.stdout)

def _flow_text(rel, _cache={}):
    if rel not in _cache:
        fpath = os.path.join(mobile_dir, rel)
        if not os.path.isfile(fpath):
            _cache[rel] = None
        else:
            with open(fpath, encoding="utf-8", errors="replace") as fh:
                _cache[rel] = searchable_flow_text(fh.readlines())
    return _cache[rel]

def _current_value(key):
    return next((v for v, ks in exact_values.items() if key in ks), None)

def vanished_bindings(old, new):
    """Bindings in `old` but not `new` whose loss is NOT explained. A removal
    is excused only when the flow file is gone, or the flow no longer asserts
    the recorded literal (it genuinely stopped checking that copy), or the
    same literal re-bound to another key (a pure rename with unchanged value).
    A renamed/deleted ARB key does NOT excuse a vanished binding while its
    literal is still asserted — that is drift being erased, not cleanup."""
    gone = []
    for key, rel in sorted(set(old) - set(new)):
        text = _flow_text(rel)
        if text is None:
            continue  # flow file deleted
        rendered, bound = old[(key, rel)]
        lit = rendered or bound
        if lit is None:
            # legacy row without a recorded literal: fall back to key existence
            if key not in all_keys:
                continue
            gone.append((key, rel))
            continue
        # Substring on purpose: refusing is the safe direction, so a literal
        # that still appears anywhere in the flow keeps its binding.
        if lit not in text:
            continue  # flow stopped asserting this copy
        if any(k2 != key and (k2, rel) in new and _current_value(k2) == lit
               for k2 in all_keys):
            continue  # literal re-bound to a renamed key, value unchanged
        gone.append((key, rel))
    return gone

HEADER = """# Binding baseline: each English literal the Maestro suite asserts, taps,
# or waits for, bound to the app_en.arb key it comes from. Generated by
# scripts/check_maestro_copy_drift.sh. Format:
#   <arb_key><TAB><flow path relative to mobile/>[<TAB>bound:<literal>]
#   <arb_key><TAB><flow path relative to mobile/><TAB>rendered:<literal>]
# 'bound:' records the literal the flow asserted when the row was derived —
# a vanished row is excused only when the flow no longer asserts that literal
# (key renames do NOT excuse it). 'rendered:' rows are hand-maintained bindings
# for parameterized ARB values (ICU placeholders); they survive regeneration,
# and the guard verifies the ARB template still produces the rendered literal.
# Regenerate after intentional copy changes with UPDATE_BASELINE=1 and review
# the printed diff — regeneration re-blesses whatever app_en.arb says today.
# Duplicate values retain the manifest's reviewed key choice. To correct a
# wrong choice, edit that row to another valid key before regenerating.
# Known v1 limit, tracked in #7213: already-drifted flow literals do not bind
# until the inverse literal check lands.
"""

def save_manifest(path, bindings):
    lines = [HEADER]
    for (key, rel), (rendered, bound) in sorted(bindings.items()):
        row = f"{key}\t{rel}"
        if rendered is not None:
            row += f"\trendered:{rendered}"
        elif bound is not None:
            row += f"\tbound:{bound}"
        lines.append(row)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

# ---------- regenerate ----------

if mode == "regen":
    old = load_manifest(manifest_path)
    new = {}
    for (lit, rel), keys in found.items():
        # Duplicate English values cannot be tied to a call site mechanically.
        # Preserve a reviewed manifest choice instead of reverting it to the
        # alphabetical fallback on every regeneration.
        for key in binding_keys(keys, rel, old):
            new[(key, rel)] = (None, lit)  # record the literal the flow asserts
    # hand-maintained rendered bindings cannot be auto-derived: carry them
    carried = 0
    for (key, rel), (rendered, _bound) in old.items():
        if rendered is not None:
            new[(key, rel)] = (rendered, None)
            carried += 1
    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    # B1: regeneration rebuilds bindings only from literals that CURRENTLY
    # match ARB, so on real drift the stale binding silently drops out and
    # the guard goes green with the flow still broken. A removal is refused
    # while the flow still asserts the recorded literal — including when the
    # ARB key was renamed away — unless ACCEPT_REMOVALS=1 is set explicitly.
    blocked = vanished_bindings(old, new)
    if blocked and os.environ.get("ACCEPT_REMOVALS", "0") != "1":
        print("❌ regen refused: these bindings vanish while their literal is "
              "still asserted in the flow file:", file=sys.stderr)
        for key, rel in blocked:
            rendered, bound = old[(key, rel)]
            lit = rendered or bound or "?"
            where = ("key exists; ARB now says: " +
                     (_current_value(key) or param_values.get(key, "?"))
                     if key in all_keys else
                     "key no longer exists in app_en.arb (renamed?)")
            print(f"  - {key}\t{rel}\n      flow still asserts: {lit}\n"
                  f"      {where}", file=sys.stderr)
        print("A vanished binding is drift being ERASED, not cleanup: the "
              "flow still asserts the old string and the guard would go "
              "permanently green. Update the flow to the current ARB copy "
              "(the binding then re-forms and nothing is removed). If the "
              "flow intentionally stopped asserting that copy, re-run with "
              "ACCEPT_REMOVALS=1 and say so in the PR.", file=sys.stderr)
        sys.exit(1)
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    save_manifest(manifest_path, new)
    print(f"manifest regenerated: {len(new)} bindings "
          f"({len(added)} added, {len(removed)} removed, {carried} hand-maintained)")
    for key, rel in added:
        print(f"  + {key}\t{rel}")
    for key, rel in removed:
        print(f"  - {key}\t{rel}")
    if blocked:
        print(f"WARNING: {len(blocked)} binding(s) removed with "
              "ACCEPT_REMOVALS=1 while their literal is still asserted in "
              "the flow — the base-ref ratchet will still fail CI if the "
              "base manifest carries them.")
    if added or removed:
        print("review the diff above: regeneration re-blesses today's ARB copy.")
    sys.exit(0)

# ---------- check ----------

if not os.path.isfile(manifest_path):
    print(f"❌ manifest missing: {manifest_path}", file=sys.stderr)
    print("run UPDATE_BASELINE=1 bash mobile/scripts/check_maestro_copy_drift.sh",
          file=sys.stderr)
    sys.exit(1)

bindings = load_manifest(manifest_path)
failures = 0

for (key, rel), (rendered, bound) in sorted(bindings.items()):
    fpath = os.path.join(mobile_dir, rel)
    if not os.path.isfile(fpath):
        print(f"❌ DRIFT: bound flow file is missing: {rel} "
              f"(bound to ARB key '{key}')", file=sys.stderr)
        failures += 1
        continue
    # Whole-literal membership, not substring: a shortened ARB value is
    # still a substring of the longer literal the flow asserts, and Maestro
    # matches the whole label, so that flow would fail on device while a
    # substring check stayed green.
    flow_lits = literals_by_flow.get(rel, set())

    if key not in all_keys:
        print(f"❌ DRIFT: ARB key '{key}' no longer exists in "
              f"lib/l10n/app_en.arb (bound from {rel}). If the key was "
              f"renamed, update the flow to the current copy under the new "
              f"key — regenerating will refuse to drop this binding while "
              f"the flow still asserts its recorded literal.",
              file=sys.stderr)
        failures += 1
        continue

    if rendered is not None:
        if key in param_values:
            # The ARB side is the template: every literal segment of it must
            # still appear, in order, in the recorded rendered string —
            # otherwise the copy changed under a hand-maintained binding.
            segs = [norm(s) for s in re.split(r"\{[^}]*\}", param_values[key])
                    if norm(s)]
            pos = 0
            missing = None
            for s in segs:
                i = rendered.find(s, pos)
                if i < 0:
                    missing = s
                    break
                pos = i + len(s)
            if missing is not None:
                print(f"❌ DRIFT: ARB template for '{key}' changed from under "
                      f"the rendered binding in {rel}:\n"
                      f"       template now: {param_values[key]}\n"
                      f"       rendered row: {rendered}\n"
                      f"       segment no longer produced: {missing}\n"
                      f"     Update the flow to the new rendered copy and fix "
                      f"the rendered: binding in "
                      f"mobile/scripts/baseline/maestro_copy_manifest.txt",
                      file=sys.stderr)
                failures += 1
                continue
        else:
            print(f"❌ DRIFT: ARB key '{key}' (bound from {rel}) no longer "
                  f"interpolates a placeholder — the rendered: row is stale.\n"
                  f"       ARB now says: {_current_value(key)}\n"
                  f"     Update the flow if needed, then regenerate: "
                  f"UPDATE_BASELINE=1 bash "
                  f"mobile/scripts/check_maestro_copy_drift.sh",
                  file=sys.stderr)
            failures += 1
            continue
        if rendered not in flow_lits:
            print(f"❌ DRIFT: {rel} no longer asserts the rendered string "
                  f"for parameterized ARB key '{key}':\n"
                  f"       expected: {rendered}\n"
                  f"     update the flow, or fix the binding in "
                  f"mobile/scripts/baseline/maestro_copy_manifest.txt",
                  file=sys.stderr)
            failures += 1
        continue

    if key in param_values:
        print(f"❌ DRIFT: ARB key '{key}' (bound from {rel}) now interpolates "
              f"a placeholder: {param_values[key]}\n"
              f"     flows assert the rendered string — add a hand-maintained "
              f"'rendered:' column to this binding in "
              f"mobile/scripts/baseline/maestro_copy_manifest.txt",
              file=sys.stderr)
        failures += 1
        continue

    current = _current_value(key)
    if current not in flow_lits:
        still = (f"       flow still asserts: {bound}\n"
                 if bound in flow_lits else "")
        print(f"❌ DRIFT: copy changed under the Maestro suite.\n"
              f"       ARB key:  {key}\n"
              f"       flow:     {rel}\n"
              f"       ARB now says: {current}\n"
              f"{still}"
              f"     That exact string is no longer one of the literals the flow "
              f"asserts, taps, or waits for. Update the "
              f"flow to the current copy first. If the flow intentionally stopped "
              f"asserting this copy, regenerate with ACCEPT_REMOVALS=1 "
              f"UPDATE_BASELINE=1 bash mobile/scripts/check_maestro_copy_drift.sh "
              f"and call out the removed binding in the PR.",
              file=sys.stderr)
        failures += 1

# unregistered literals: exact ARB match with no binding for that file
unregistered = []
for (lit, rel), keys in sorted(found.items()):
    if not any((k, rel) in bindings for k in keys):
        unregistered.append((rel, lit, sorted(keys)))

for rel, lit, keys in unregistered:
    print(f"❌ UNREGISTERED: {rel} asserts ARB-backed copy with no manifest "
          f"binding:\n       \"{lit}\"  (key: {', '.join(keys)})\n"
          f"     Register it: UPDATE_BASELINE=1 bash "
          f"mobile/scripts/check_maestro_copy_drift.sh",
          file=sys.stderr)
    failures += 1

# B2: base-ref ratchet — a binding the base manifest carries may not vanish
# from the branch while the flow still asserts its recorded literal. This is
# what makes a regen-erased regression visible in CI even when the branch's
# own check is green, and it keys on the literal, not the key name, so a
# rename-plus-copy-change cannot slip through as a deletion. Bootstrap: the
# manifest does not exist on the base ref until this guard merges, so the
# ratchet is skipped with a note until then.
base_status, base_bindings = load_base_manifest()
if base_status == "ok":
    dropped = vanished_bindings(base_bindings, bindings)
    for key, rel in dropped:
        print(f"❌ ERODED: binding for '{key}' in {rel} exists on {BASE_REF} "
              f"but is gone from this branch's manifest, and the flow still "
              f"asserts its recorded literal. Regenerating away a drifted "
              f"binding does not fix the drift — update the flow to the "
              f"current ARB copy.",
              file=sys.stderr)
        failures += 1
elif base_status == "bootstrap":
    print(f"NOTE: no manifest on {BASE_REF} yet (guard not merged); "
          "skipping base-ref ratchet.")
else:
    if ALLOW_NO_BASE:
        print(f"NOTE: {BASE_REF} unavailable; skipping base-ref ratchet "
              "(MAESTRO_COPY_DRIFT_ALLOW_NO_BASE=1, local opt-out).")
    else:
        print(f"❌ could not load the manifest from {BASE_REF}, so the "
              "base-ref ratchet cannot be verified — failing closed. Ensure "
              f"{BASE_REF} is fetched, or set "
              "MAESTRO_COPY_DRIFT_ALLOW_NO_BASE=1 for a local run.",
              file=sys.stderr)
        failures += 1

if failures:
    print("", file=sys.stderr)
    print(f"{failures} copy-drift failure(s). app_en.arb is the source of "
          f"truth: adopt the current ARB copy in the flow, or regenerate the "
          f"manifest for an intentional copy change.", file=sys.stderr)
    sys.exit(1)

# S2: print the denominator — bindings cover only the literals that exactly
# match a non-parameterized ARB value today; the rest (regexes, ids, rendered
# ICU forms, already-drifted copy) are extracted but invisible to the guard.
print(f"✅ Maestro copy-drift guard: {len(bindings)} bindings verified "
      f"(of {len(total_literals)} asserted literals extracted), "
      f"0 unregistered literals.")
PYEOF
