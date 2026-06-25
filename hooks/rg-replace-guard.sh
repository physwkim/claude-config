#!/usr/bin/env bash
# PreToolUse(Bash) guard against accidental ripgrep --replace usage.
#
# ripgrep recurses by DEFAULT, so `-r` is NOT "recursive" (that is grep). In
# ripgrep `-r`/`--replace` is an OUTPUT-only replacement flag that REQUIRES a
# value, so `-rn` parses as `--replace=n` and silently rewrites every match to
# "n". This guard blocks the mistakes — short-flag bundles where `r` is followed
# by another letter (e.g. `-rn`, `-irn`) and UNQUOTED replacement values — while
# letting intentional, quoted replacement through (`rg 'foo(\w+)' -r 'bar$1'`).
#
# Reads the hook JSON on stdin; exit 2 blocks the tool call (message on stderr).
set -u

cmd="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

# An rg invocation: rg as a command word (start, or after a shell separator),
# followed by whitespace. Catches `rg `, `| rg `, `&& rg `, `;rg `, `(rg `,
# `command rg `. `[^|;&]*` keeps each check inside one rg call (no crossing a
# pipe/;/& into an unrelated command).
#
# B = rg word boundary + a SHORT-flag token boundary: the offending `-` is the
# first arg after `rg `, OR follows an arg group that ends in whitespace. This
# anchors `-r...` to a single-dash short flag so the long `--replace` (whose
# literal letters "re" would otherwise match `-...r[letter]`) is NOT caught here.
B='(^|[[:space:];&|(])rg[[:space:]]([^|;&]*[[:space:]])?'
# L = rg word boundary, then `--replace` anywhere in the same call.
L='(^|[[:space:];&|(])rg[[:space:]][^|;&]*--replace'

msg="ripgrep is recursive by default; use 'rg -n PATTERN PATH' for recursive search. '-r'/'--replace' is OUTPUT-only replacement and must be intentional+quoted (e.g. rg 'foo(\\w+)' -r 'bar\$1')."

block() { printf '%s\n' "$msg" >&2; exit 2; }

# 1) Short-flag bundle with `r` not last: -rn, -irn, -ri, ... (always a mistake;
#    the letters after `r` become the replacement string).
printf '%s' "$cmd" | grep -Eq "${B}-[A-Za-z]*r[A-Za-z]" && block

# 2) Unquoted short replacement value: `-r foo` / `-nr foo`
#    (allow `-r 'foo'` and `-r \"foo\"`).
printf '%s' "$cmd" | grep -Eq "${B}-[A-Za-z]*r[[:space:]]+[^'\"[:space:]]" && block

# 3) Unquoted long replacement value: `--replace foo` / `--replace=foo`
#    (allow `--replace 'foo'`, `--replace='foo'`, `--replace=\"foo\"`).
printf '%s' "$cmd" | grep -Eq "${L}([[:space:]]+[^'\"[:space:]]|=[^'\"])" && block

exit 0
