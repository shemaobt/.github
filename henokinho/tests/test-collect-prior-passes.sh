#!/usr/bin/env bash
# Behaviour suite for henokinho/scripts/collect-prior-passes.sh.
#
# The script is exercised only through its boundary: fixture JSON in, named
# output values and a digest file out. Nothing inside it is visible here.
#
# Run from anywhere:  ./henokinho/tests/test-collect-prior-passes.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="$HERE/fixtures"
SCRIPT="$HERE/../scripts/collect-prior-passes.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BOT="henokinho[bot]"
REPO_UNDER_TEST="shemaobt/shema-api"
PR_UNDER_TEST="77"

SHA_B="bbb2220000000000000000000000000000000000"
SHA_C="ccc3330000000000000000000000000000000000"

# Digest contract: two headings, and two markers for the empty cases.
H_MINE="## Points you raised"
H_OTHERS="## Already raised by other bots"
MARK_NONE="(nothing raised yet)"
MARK_NO_REPLY="(no reply from the author)"

total=0
failed=0
case_name=""
case_failed=0
case_msgs=""
OUT=""
DIGEST=""

begin() {
  case_name="$1"
  case_failed=0
  case_msgs=""
  total=$((total + 1))
}

bad() {
  case_failed=1
  case_msgs="$case_msgs
        - $*"
}

finish() {
  if [ "$case_failed" -eq 0 ]; then
    printf 'PASS  %s\n' "$case_name"
  else
    printf 'FAIL  %s%s\n' "$case_name" "$case_msgs"
    failed=$((failed + 1))
  fi
}

run_collect() { # reviews_fixture comments_fixture head_sha
  local dir rc
  dir="$WORK/case-$total"
  rm -rf "$dir"
  mkdir -p "$dir"
  OUT="$dir/outputs.txt"
  DIGEST="$dir/digest.md"
  : > "$OUT"

  REVIEWS_JSON="$FIXTURES/$1" \
  COMMENTS_JSON="$FIXTURES/$2" \
  BOT_LOGIN="$BOT" \
  HEAD_SHA="$3" \
  REPO="$REPO_UNDER_TEST" \
  PR="$PR_UNDER_TEST" \
  DIGEST_OUT="$DIGEST" \
  GITHUB_OUTPUT="$OUT" \
    bash "$SCRIPT" >"$dir/stdout.txt" 2>"$dir/stderr.txt"
  rc=$?

  if [ "$rc" -ne 0 ]; then
    bad "script exited $rc: $(tr '\n' ' ' <"$dir/stderr.txt" | cut -c1-200)"
  fi
  if [ ! -f "$DIGEST" ]; then
    bad "no digest written to $DIGEST"
  fi
}

out() { sed -n "s/^$1=//p" "$OUT" 2>/dev/null | tail -1; }

# Everything under a "## " heading, up to the next one.
digest_section() {
  [ -f "$DIGEST" ] || return 0
  awk -v hdr="$1" '
    index($0, hdr) == 1 { on = 1; next }
    on && /^## / { on = 0 }
    on { print }
  ' "$DIGEST"
}

assert_out() { # name want
  local got
  got="$(out "$1")"
  [ "$got" = "$2" ] || bad "output $1: want '$2', got '$got'"
}

assert_has() { # needle haystack where
  case "$2" in
    *"$1"*) ;;
    *) bad "$3 should contain '$1'" ;;
  esac
}

assert_lacks() { # needle haystack where
  case "$2" in
    *"$1"*) bad "$3 should NOT contain '$1'" ;;
    *) ;;
  esac
}

# --------------------------------------------------------------------------

begin "1. a PR only other bots have touched is this bot's first pass"
run_collect other-bots-reviews.json other-bots-comments.json "$SHA_C"
assert_out passes 0
assert_out pass_index 1
mine="$(digest_section "$H_MINE")"
assert_has "$MARK_NONE" "$mine" "own-points section"
assert_lacks "acousteme_service.py" "$mine" "own-points section"
assert_lacks "oral.py" "$mine" "own-points section"
finish

begin "2. reviews across two commits count as two passes, not three"
run_collect two-passes-reviews.json empty.json "$SHA_B"
assert_out passes 2
assert_out pass_index 3
finish

begin "3. a re-run against an already-reviewed head reports the head unchanged"
run_collect two-passes-reviews.json empty.json "$SHA_B"
assert_out last_sha "$SHA_B"
assert_out head_unchanged true
run_collect two-passes-reviews.json empty.json "$SHA_C"
assert_out head_unchanged false
finish

begin "4. a raised point is reported with the author's answer and a reply command"
run_collect one-pass-reviews.json answered-thread-comments.json "$SHA_C"
mine="$(digest_section "$H_MINE")"
assert_has "app/foo.py:12" "$mine" "own-points section"
assert_has "Maybe the output here could be typed?" "$mine" "own-points section"
assert_has "Good point, booked on SHEMA-123." "$mine" "own-points section"
assert_has "alice" "$mine" "own-points section"
assert_has "repos/$REPO_UNDER_TEST/pulls/$PR_UNDER_TEST/comments/5001/replies" "$mine" "own-points section"
finish

begin "5. a raised point nobody answered is marked unanswered, not omitted"
run_collect one-pass-reviews.json unanswered-thread-comments.json "$SHA_C"
mine="$(digest_section "$H_MINE")"
assert_has "Maybe the output here could be typed?" "$mine" "own-points section"
assert_has "$MARK_NO_REPLY" "$mine" "own-points section"
assert_lacks "alice" "$mine" "own-points section"
finish

begin "6. other bots' findings are listed separately, with file and line"
run_collect one-pass-reviews.json mixed-comments.json "$SHA_C"
mine="$(digest_section "$H_MINE")"
others="$(digest_section "$H_OTHERS")"
assert_has "app/services/acousteme_service.py:81" "$others" "other-bots section"
assert_has "app/api/routes/oral.py:42" "$others" "other-bots section"
assert_has "coderabbitai[bot]" "$others" "other-bots section"
assert_has "little-joao[bot]" "$others" "other-bots section"
assert_lacks "app/foo.py" "$others" "other-bots section"
assert_has "app/foo.py:10" "$mine" "own-points section"
assert_lacks "acousteme_service.py" "$mine" "own-points section"
finish

begin "7. a reply on another bot's thread is not a point this bot raised"
run_collect one-pass-reviews.json bot-reply-comments.json "$SHA_C"
assert_out passes 1
assert_out pass_index 2
mine="$(digest_section "$H_MINE")"
assert_lacks "HENOKINHO-REPLY-BODY" "$mine" "own-points section"
assert_has "$MARK_NONE" "$mine" "own-points section"
finish

# --------------------------------------------------------------------------

printf '\n%d behaviours, %d failed\n' "$total" "$failed"
[ "$failed" -eq 0 ]
