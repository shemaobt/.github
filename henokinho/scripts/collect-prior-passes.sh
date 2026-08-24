#!/usr/bin/env bash
# Works out what Henokinho has already done on this PR and writes it down for
# the reviewer to read before it opens the diff.
#
# Inputs, all as environment variables:
#   REVIEWS_JSON   path to the PR's reviews, as GitHub returns them
#   COMMENTS_JSON  path to the PR's review comments, as GitHub returns them
#   BOT_LOGIN      this bot's login, e.g. henokinho[bot]
#   HEAD_SHA       the head SHA about to be reviewed
#   REPO           owner/name, used only to print reply commands
#   PR             PR number, used only to print reply commands
#   DIGEST_OUT     path to write the digest to
#   GITHUB_OUTPUT  optional; when unset the named values are simply not emitted
#
# Named outputs: passes, pass_index, last_sha, head_unchanged.
#
# Digest contract, which the suite asserts on: two "## " headings, one for this
# bot's own points and one for the other bots'; each entry titled "path:line";
# "(nothing raised yet)" for an empty section and "(no reply from the author)"
# for a thread the author has not answered.

set -euo pipefail

: "${REVIEWS_JSON:?REVIEWS_JSON is required}"
: "${COMMENTS_JSON:?COMMENTS_JSON is required}"
: "${BOT_LOGIN:?BOT_LOGIN is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
: "${REPO:?REPO is required}"
: "${PR:?PR is required}"
: "${DIGEST_OUT:?DIGEST_OUT is required}"

# One pass is one head SHA this bot has already reviewed, not one review object
# — a single sitting posts several review objects. Selecting on the login and
# not on .user.type matters: several bots review these PRs, and reading their
# reviews as this bot's own history would put it on pass 12 before it has run.
passes=$(jq --arg bot "$BOT_LOGIN" \
  '[.[] | select(.user.login == $bot) | .commit_id] | unique | length' "$REVIEWS_JSON")
last_sha=$(jq -r --arg bot "$BOT_LOGIN" \
  '[.[] | select(.user.login == $bot)] | sort_by(.submitted_at) | last | .commit_id // ""' "$REVIEWS_JSON")

pass_index=$((passes + 1))
if [ "$last_sha" = "$HEAD_SHA" ]; then
  head_unchanged=true
else
  head_unchanged=false
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "passes=$passes"
    echo "pass_index=$pass_index"
    echo "last_sha=$last_sha"
    echo "head_unchanged=$head_unchanged"
  } >> "$GITHUB_OUTPUT"
fi

# Points are read from the comments and passes from the reviews; a PR may have
# either without the other, so neither may assume the other is non-empty.
own_points=$(jq --arg bot "$BOT_LOGIN" \
  '[.[] | select(.in_reply_to_id == null and .user.login == $bot)] | length' "$COMMENTS_JSON")
other_points=$(jq --arg bot "$BOT_LOGIN" \
  '[.[] | select(.in_reply_to_id == null and .user.type == "Bot" and .user.login != $bot)] | length' "$COMMENTS_JSON")

{
  echo "# Prior Henokinho passes on this PR"
  echo
  echo "- passes already done: $passes"
  echo "- this is pass: $pass_index"
  echo "- head SHA you last reviewed: ${last_sha:-none}"
  echo "- head SHA now: $HEAD_SHA"
  echo

  echo "## Points you raised, with the author's replies"
  echo
  if [ "$own_points" -gt 0 ]; then
    jq -r --arg bot "$BOT_LOGIN" --arg repo "$REPO" --arg pr "$PR" '
      (map(select(.in_reply_to_id != null))
        | group_by(.in_reply_to_id)
        | map({key: (.[0].in_reply_to_id | tostring), value: .})
        | from_entries) as $replies
      | map(select(.in_reply_to_id == null and .user.login == $bot))
      | .[]
      | "### \(.path):\(.line // .original_line // "?")\nreply on this thread with: gh api repos/\($repo)/pulls/\($pr)/comments/\(.id)/replies -f body=\"...\"\n\nYOU RAISED:\n\(.body)\n\n"
        + (($replies[(.id | tostring)] // [])
            | map("REPLY from @\(.user.login):\n\(.body)")
            | join("\n\n")
            | if . == "" then "(no reply from the author)" else . end)
        + "\n"
    ' "$COMMENTS_JSON"
  else
    echo "(nothing raised yet)"
    echo
  fi

  echo "## Already raised by other bots — do not raise these again"
  echo
  if [ "$other_points" -gt 0 ]; then
    jq -r --arg bot "$BOT_LOGIN" '
      map(select(.in_reply_to_id == null and .user.type == "Bot" and .user.login != $bot))
      | .[]
      | "### \(.path):\(.line // .original_line // "?") — \(.user.login)\n\(.body)\n"
    ' "$COMMENTS_JSON"
  else
    echo "(nothing raised yet)"
    echo
  fi
} > "$DIGEST_OUT"
