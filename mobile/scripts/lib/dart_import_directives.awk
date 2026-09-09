# Emit complete Dart import directives on one line each.
#
# Line and nested block comments are removed while string literals are kept,
# allowing callers to inspect every URI in a conditional import. Semicolons
# inside strings or comments do not terminate the directive.
# Bash 3.2 / POSIX awk compatible.

BEGIN {
  block_depth = 0
  in_string = 0
  quote = ""
  directive = ""
}

function finish_statement() {
  if (directive ~ /^[[:space:]]*import[[:space:]]+/) {
    gsub(/[[:space:]]+/, " ", directive)
    print directive
  }
  directive = ""
}

{
  line = $0
  i = 1
  length_of_line = length(line)

  while (i <= length_of_line) {
    character = substr(line, i, 1)
    pair = substr(line, i, 2)

    if (block_depth > 0) {
      if (pair == "*/") {
        block_depth--
        i += 2
      } else if (pair == "/*") {
        block_depth++
        i += 2
      } else {
        i++
      }
      continue
    }

    if (in_string) {
      directive = directive character
      if (character == "\\") {
        if (i < length_of_line) {
          directive = directive substr(line, i + 1, 1)
          i += 2
        } else {
          i++
        }
      } else if (character == quote) {
        in_string = 0
        quote = ""
        i++
      } else {
        i++
      }
      continue
    }

    if (pair == "//") break
    if (pair == "/*") {
      block_depth++
      directive = directive " "
      i += 2
      continue
    }
    if (character == "'" || character == "\"") {
      in_string = 1
      quote = character
      directive = directive character
      i++
      continue
    }

    directive = directive character
    if (character == ";") finish_statement()
    i++
  }

  directive = directive " "
}
