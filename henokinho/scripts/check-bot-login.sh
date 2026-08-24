#!/usr/bin/env bash
# Fails the job when the bot_login input is not this App's login.
#
# Inputs, as environment variables:
#   APP_SLUG   the App's slug, from the token step's app-slug output
#   BOT_LOGIN  the bot_login input the caller resolved to
#
# Exits non-zero if they disagree. This runs before the review, and it stops
# it, because a review with the wrong login is worse than no review at all:
# the login is what the prior-passes script filters on, so a wrong one matches
# none of this bot's own history. It reports pass 1 on every run, so the closed
# ledger never closes and the bot re-opens the whole review every time it is
# asked — the exact complaint the ledger was built to answer. Its own comments
# then fall into the "already raised by other bots" section, which §8 of the
# spec tells it to read only so as not to repeat and never to reply on, so it
# also goes silent on its own open findings. None of that errors on its own.

set -euo pipefail

: "${APP_SLUG:?APP_SLUG is required}"
: "${BOT_LOGIN:?BOT_LOGIN is required}"

expected="${APP_SLUG}[bot]"

if [ "$BOT_LOGIN" != "$expected" ]; then
  echo "::error::bot_login does not belong to the App this job authenticated as. Expected '${expected}' (App slug '${APP_SLUG}'), got '${BOT_LOGIN}'. GitHub builds the login from the App slug, not from the workflow name — set the bot_login input to '${expected}', or point app_id at the App whose login is '${BOT_LOGIN}'. Refusing to review: with a login that is not its own, the bot reports pass 1 forever, never closes its ledger, and reads its own comments as another bot's."
  exit 1
fi
