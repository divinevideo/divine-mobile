# Emit Dart source with comments and string-literal bodies removed, so the
# purely textual design-system drift detectors (#6145) match real code only.
#
# Removed: line comments (`// …`, `/// …`), nestable block comments (`/* … */`,
# including multi-line), and the CONTENTS of string literals ('…', "…", '''…''',
# """…""", and r'…' raw forms). Interpolated expressions (`${…}`) are PRESERVED
# as code, since a token there is a real reference. Quote delimiters are kept so
# neighbouring tokens cannot fuse. Line count is preserved.
# With `-v preserve_tag_literals=1`, string bodies inside a real `@Tags(...)`
# annotation are retained. This lets callers classify semantic test tags while
# still removing `@Tags(...)` text that occurs inside comments or other strings.
#
# Why not `sed 's|//.*||'`: that truncates at the `//` of a URL (`'https://…'`)
# or a path literal (`startsWith('//')`), silently DROPPING a real detector match
# later on the same line. Undercounting is the dangerous direction for a ceiling
# ratchet — it lets drift through and can fake a STALE win. This pass tracks
# string state, so a `//` inside a literal is never mistaken for a comment.
#
# Pinned by test/tools/design_system_ceiling_detectors_test.dart.
# Bash 3.2 / POSIX awk compatible.

BEGIN {
  blk = 0
  instr = 0
  israw = 0
  q = ""
  qlen = 0
  keepbody = 0
  tagann = 0
  tagdepth = 0
}

{
  line = $0
  out = ""
  i = 1
  n = length(line)

  while (i <= n) {
    c = substr(line, i, 1)
    c2 = substr(line, i, 2)

    # --- inside a block comment: consume, honouring Dart's nesting ---
    if (blk > 0) {
      if (c2 == "*/") { blk--; i += 2 }
      else if (c2 == "/*") { blk++; i += 2 }
      else i++
      continue
    }

    # --- inside a string literal: drop the body, keep ${…} as code ---
    if (instr) {
      if (!israw && c == "\\") {
        if (keepbody) out = out substr(line, i, 2)
        i += 2
        continue
      }
      if (c == "$" && substr(line, i + 1, 1) == "{") {
        out = out " "
        i += 2
        depth = 1
        while (i <= n) {
          ci = substr(line, i, 1)
          if (ci == "{") depth++
          else if (ci == "}") {
            depth--
            if (depth == 0) { i++; break }
          }
          out = out ci
          i++
        }
        out = out " "
        continue
      }
      if (substr(line, i, qlen) == q) {
        if (keepbody) out = out q
        instr = 0
        keepbody = 0
        i += qlen
        continue
      }
      if (keepbody) out = out c
      i++
      continue
    }

    # --- ordinary code ---
    if (c2 == "//") break                       # rest of the line is a comment
    if (c2 == "/*") { blk++; i += 2; continue }

    if (!tagann && substr(line, i) ~ /^@Tags[[:space:]]*\(/) {
      tagann = 1
      tagdepth = 0
    }

    if (tagann && c == "(") tagdepth++
    else if (tagann && c == ")") {
      tagdepth--
      if (tagdepth == 0) tagann = 0
    }

    if (c == "'" || c == "\"") {
      israw = (i > 1 && substr(line, i - 1, 1) == "r")
      if (substr(line, i, 3) == c c c) { q = c c c; qlen = 3 }
      else { q = c; qlen = 1 }
      instr = 1
      keepbody = (preserve_tag_literals && tagann)
      out = out q
      i += qlen
      continue
    }

    out = out c
    i++
  }

  print out
}
