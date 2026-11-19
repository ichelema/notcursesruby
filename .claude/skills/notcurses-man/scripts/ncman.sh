#!/usr/bin/env bash
# ncman.sh - look up the notcurses C API in the installed man pages and headers.
#
# Usage:
#   ncman.sh SYMBOL          man page paragraphs that mention SYMBOL, the generic
#                            RETURN VALUES rules, then the header comment and
#                            declaration (with the body for static inline code)
#   ncman.sh --page NAME     whole rendered page (notcurses_output or output)
#   ncman.sh --search REGEX  paragraphs of every notcurses(3) page matching REGEX
#                            (case-insensitive, extended regex)
#   ncman.sh --list          pages with their one-line description
#
# Environment: NCMAN_DIR (default /usr/share/man/man3),
#              NCMAN_INCLUDE (default /usr/include/notcurses).
set -euo pipefail

MAN_DIR=${NCMAN_DIR:-/usr/share/man/man3}
INC_DIR=${NCMAN_INCLUDE:-/usr/include/notcurses}
BODY_MAX=80

die() { echo "ncman: $*" >&2; exit 2; }

pages() { compgen -G "$MAN_DIR/notcurses*.3.gz" | sort; }

render() { # render FILE.gz -> plain text, one paragraph per line
  MANWIDTH=2000 man -P cat -l "$1" 2>/dev/null | col -bx
}

page_name() { basename "$1" .3.gz; }

version_line() {
  local man_v inc_v first
  first=$(pages | head -n1)
  [[ -n $first ]] || die "no notcurses man pages in $MAN_DIR"
  man_v=$(sed -n 's/^\.TH "[^"]*" "3" "v\{0,1\}\([^"]*\)".*/\1/p' <(zcat "$first") | head -n1)
  inc_v=$(sed -n 's/^#define NOTCURSES_VERSION_\(MAJOR\|MINOR\|PATCH\) "\([0-9]*\)"/\2/p' \
    "$INC_DIR/version.h" 2>/dev/null | paste -sd.) || true
  echo "== notcurses man pages v${man_v:-?}, headers v${inc_v:-?}"
  if [[ -n $man_v && -n $inc_v && $man_v != "$inc_v" ]]; then
    echo "!! WARNING: man pages and headers differ; the headers match the linked library"
  fi
}

# Print paragraphs of a rendered page. mode=symbol: paragraphs (outside
# SYNOPSIS) matching the symbol or its family base, synopsis lines declaring
# it, and the generic RETURN VALUES rules. mode=search: paragraphs matching re.
extract() { # extract MODE PATTERN PAGE_NAME
  awk -v mode="$1" -v pat="$2" -v page="$3" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function emit(s) {
      if (!shown) { print ""; print "-- " page "(3) --"; shown = 1 }
      if (sec != lastsec) { print "[" sec "]"; lastsec = sec }
      print "  " s
    }
    BEGIN { IGNORECASE = 1 }
    /^[A-Z][A-Z ]+$/ { sec = $0; next }
    /^[ \t]*$/ { next }
    sec == "" { next }
    {
      line = trim($0)
      if (mode == "search") { if (line ~ pat) emit(line); next }
      if (sec == "SYNOPSIS") { if (line ~ pat) emit(line); next }
      # generic RETURN VALUES rules do not open with another identifier
      if (line ~ pat || (sec == "RETURN VALUES" && line !~ /^[a-z]+_[A-Za-z0-9_]*/)) emit(line)
    }
  '
}

word_re() { # symbol -> awk regex with identifier boundaries
  printf '(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)' "$1"
}

lookup_man() {
  local sym=$1 base re found=0 f
  base=$(sed -E 's/_(yx|aligned|stained)$//' <<<"$sym")
  re=$(word_re "$sym")
  [[ $base != "$sym" ]] && re="$re|(^|[^A-Za-z0-9_])${base}[(][)]"
  for f in $(pages); do
    # process substitution: an early grep exit must not fail the test via pipefail
    if grep -qw -- "$sym" <(zcat "$f"); then
      found=1
      render "$f" | extract symbol "$re" "$(page_name "$f")"
    fi
  done
  ((found)) || { echo; echo "-- no man page mentions $sym"; }
  return 0
}

# Header lookup: a definition starts at column 0 and contains SYMBOL followed
# by "(" or ends with "{" (struct/enum/union). Calls inside inline bodies are
# indented, so they never match. Prints the comment block above, the type line
# of "static inline T\nname(...)" definitions, and the declaration up to ";"
# or the body up to the closing "}" at column 0.
lookup_header() {
  local sym=$1 out
  out=$(awk -v sym="$sym" -v max="$BODY_MAX" '
    function isword(c) { return c ~ /[A-Za-z0-9_]/ }
    function hasword(s,   i, n, b, a, s2, j) {
      n = length(sym); i = index(s, sym)
      while (i > 0) {
        b = (i == 1) ? "" : substr(s, i - 1, 1); a = substr(s, i + n, 1)
        if (!isword(b) && !isword(a)) return i
        s2 = substr(s, i + n); j = index(s2, sym)
        if (j == 0) return 0
        i = i + n + j - 1
      }
      return 0
    }
    function isdef(s,   i, after) {
      if (s ~ /^[ \t#\/}*]/ || s == "") return 0
      i = hasword(s); if (!i) return 0
      after = substr(s, i + length(sym)); sub(/^[ \t]+/, "", after)
      return after ~ /^\(/ || s ~ /\{[ \t]*$/
    }
    FNR == 1 { n = 0 }
    { buf[++n] = $0 }
    isdef($0) {
      start = n
      if (start > 1 && buf[start-1] !~ /^[ \t]*(\/\/|\/\*|\*|$)/ && buf[start-1] !~ /[;}][ \t]*$/) start--
      while (start > 1 && buf[start-1] ~ /^[ \t]*(\/\/|\/\*|\*)/) start--
      print ""; print "-- " FILENAME ":" FNR " --"
      for (k = start; k < n; k++) print buf[k]
      print $0
      body = ($0 ~ /\{/); done = (!body && $0 ~ /;[ \t]*$/) || ($0 ~ /^}/)
      if (body && $0 ~ /\}[ \t;]*$/ && $0 ~ /\{.*\}/) done = 1
      cnt = 0
      while (!done && (getline l) > 0) {
        buf[++n] = l
        if (++cnt > max) { print "    ... (truncated)"; break }
        print l
        if (l ~ /\{/) body = 1
        if (body) { if (l ~ /^}/) done = 1 } else if (l ~ /;[ \t]*$/) done = 1
      }
    }
  ' "$INC_DIR"/*.h)
  if [[ -n $out ]]; then
    printf '%s\n' "$out"
  else
    out=$(grep -n -w -B3 -- "$sym" "$INC_DIR"/*.h | head -n 40 || true)
    if [[ -n $out ]]; then
      echo; echo "-- header mentions (no definition at column 0) --"; printf '%s\n' "$out"
    else
      echo; echo "-- no header mentions $sym"
    fi
  fi
}

cmd_symbol() {
  local sym=$1
  [[ $sym =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "not a C identifier: $sym"
  version_line
  echo; echo "==== MAN PAGES: $sym"
  lookup_man "$sym"
  echo; echo "==== HEADERS: $sym"
  lookup_header "$sym"
}

cmd_page() {
  local name=$1 f
  name=${name%.3}; name=${name%(3)}
  [[ $name == notcurses* ]] || name="notcurses_$name"
  f="$MAN_DIR/$name.3.gz"
  [[ -f $f ]] || die "no page $name(3); try --list"
  version_line
  render "$f"
}

cmd_search() {
  local re=$1 f
  version_line
  for f in $(pages); do
    render "$f" | extract search "$re" "$(page_name "$f")"
  done
}

cmd_list() {
  local f
  version_line
  for f in $(pages); do
    render "$f" | awk -v p="$(page_name "$f")" '
      done { next }
      /^NAME$/ { getline; sub(/^[ \t]+/, ""); sub(/^[^-]*- /, ""); printf "%-28s %s\n", p, $0; done = 1 }'
  done
}

case ${1:-} in
  ""|-h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --page)   [[ $# -eq 2 ]] || die "usage: --page NAME"; cmd_page "$2" ;;
  --search) [[ $# -eq 2 ]] || die "usage: --search REGEX"; cmd_search "$2" ;;
  --list)   cmd_list ;;
  -*)       die "unknown option $1" ;;
  *)        [[ $# -eq 1 ]] || die "one symbol at a time"; cmd_symbol "$1" ;;
esac
