#!/usr/bin/env bash
# Behaviour suite for henokinho/scripts/check-bot-login.sh.
#
# Exercised through its boundary only: two environment values in, an exit
# status and a message out.
#
# Run from anywhere:  ./henokinho/tests/test-check-bot-login.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/check-bot-login.sh"

total=0
failed=0
case_name=""
case_failed=0
case_msgs=""
RC=0
OUTPUT=""

begin() { case_name="$1"; case_failed=0; case_msgs=""; total=$((total + 1)); }
bad() { case_failed=1; case_msgs="$case_msgs
        - $*"; }
finish() {
  if [ "$case_failed" -eq 0 ]; then
    printf 'PASS  %s\n' "$case_name"
  else
    printf 'FAIL  %s%s\n' "$case_name" "$case_msgs"
    failed=$((failed + 1))
  fi
}

run_check() { # app_slug bot_login
  OUTPUT="$(APP_SLUG="$1" BOT_LOGIN="$2" bash "$SCRIPT" 2>&1)"
  RC=$?
}

assert_has() { # needle haystack where
  case "$2" in
    *"$1"*) ;;
    *) bad "$3 should mention '$1'" ;;
  esac
}

# --------------------------------------------------------------------------

begin "8. a bot_login that does not match the App slug stops the job"
# The wrong value is not rejected for being malformed — it is a plausible login
# that simply is not this App's. It is the value this workflow shipped with.
run_check "little-henok" "henokinho[bot]"
[ "$RC" -ne 0 ] || bad "expected a non-zero exit, got $RC"
assert_has "little-henok[bot]" "$OUTPUT" "the failure message"
assert_has "henokinho[bot]" "$OUTPUT" "the failure message"
# A guard that always fails is no guard: the matching value must pass through.
run_check "little-henok" "little-henok[bot]"
[ "$RC" -eq 0 ] || bad "a matching login should exit 0, got $RC: $OUTPUT"
finish

# --------------------------------------------------------------------------

printf '\n%d behaviours, %d failed\n' "$total" "$failed"
[ "$failed" -eq 0 ]
