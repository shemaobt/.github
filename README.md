# shemaobt/.github

Org-level GitHub configuration for [Shema](https://github.com/shemaobt). No
application code lives here — this repo holds the organization profile and the
reusable workflows that every product repo calls.

## Automated PR reviewers

Two bots review pull requests across the org. Each one stands in for a specific
human, and there are **two ways to ask for one**: request that person as a
reviewer, or label the pull request with the bot's own name. A request aimed at
a team fires neither of them, and neither runs on a draft PR or on a PR opened
by a bot.

The label is there for the case a review request cannot reach. GitHub refuses a
request aimed at a pull request's own author — `422 Review cannot be requested
from pull request author` — so on a repository where the stand-in's human opens
the pull requests himself, there is no login left to request and the bot can
never fire. The name is the `label_name` input and defaults to the bot's own.
**A caller only gets that second way in by putting `labeled` into its own
`on: pull_request: types:`**; a caller that has not is unchanged.

| Bot | Stands in for | Reusable workflow | Spec |
|---|---|---|---|
| Joãozinho | @joaocarvoli | `.github/workflows/joaozinho-review.yml` | `joaozinho/` |
| Henokinho | @henokteixeira | `.github/workflows/henokinho-review.yml` | `henokinho/` |

Both go first so the human's own pass is cheaper. Neither replaces it, and
**neither ever approves** — approval belongs to the requested reviewer. They
differ on blocking: Joãozinho may request changes when run in `block` verdict
mode; Henokinho never blocks in any circumstance and posts only `--comment`
reviews.

They also differ on how a re-review behaves. Joãozinho may raise something new
on any pass, under a budget that shrinks as passes go on. Henokinho closes its
finding set after the first pass: pass 1 produces the complete list and declares
it closed, and every later pass only verifies that list against the code at
head. The one exception is a bug introduced by the fix itself, in lines added
since the previous pass. When every item closes, it says so and stops — that is
the nearest it comes to approving.

That behaviour is a response to a specific complaint about the first bot: a
reviewer that finds something different every time it is asked has told the
author their code is never good enough, and left no version of the diff that
ends the conversation. The price is recall — a defect missed on pass 1 stays
missed, because the register cannot be reopened. That trade was made on purpose
and accepted by the bot's owner; it is not an oversight to be fixed by loosening
the rule.

They are deliberately separate files rather than one parameterised workflow.
The duplication is the chosen design: the two reviewers have different policies
and different specs, and coupling them would mean every change to one is a risk
to the other.

### How a repo turns one on

Each product repo carries its own thin caller workflow that listens for
`pull_request` review requests and delegates:

```yaml
jobs:
  review:
    uses: shemaobt/.github/.github/workflows/henokinho-review.yml@main
    with:
      lens_pack: python-fastapi   # or flutter-dart | react-ts
      app_id: ${{ vars.HENOKINHO_APP_ID }}
    secrets:
      app_private_key: ${{ secrets.HENOKINHO_APP_PRIVATE_KEY }}
      claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Each bot posts as its own GitHub App, and **the login does not match the
workflow name**. GitHub builds it from the App's slug plus a `[bot]` suffix, and
both Apps in this family are named `little-*`: `joaozinho-review.yml` posts as
`little-joao[bot]`, and `henokinho-review.yml` posts as `little-henok[bot]`.
Read the login off the App, never off the workflow. Henokinho takes it as the
`bot_login` input rather than hardcoding it, because the slug is not knowable
until the App exists.

Getting that value wrong is not cosmetic: it is what the prior-passes script
filters on, so a wrong login makes the bot match none of its own history,
report pass 1 forever, and read its own comments as another bot's. It used to
fail this way in silence, with nothing in the run erroring. Henokinho now
compares the login against the App slug it actually authenticated as, before it
reads anything, and stops the job if they disagree — a review under the wrong
login is worse than no review, because it quietly disables the closed ledger.

### Where the behaviour lives

A bot's spec directory is the single source of truth for how it reviews:
`review-style.md` carries the voice, the lenses and the calibration, and
`lenses/<stack>.md` says what those lenses mean in a given stack. Editing a
spec here changes the behaviour in every repo at once — that is the point of
keeping it in this repo instead of in each product repo.

### Prior passes

Before it opens a diff, Henokinho works out what it has already done on the PR:
how many head SHAs it has reviewed, what it raised, what the author answered,
and what the *other* bots have already said so it does not repeat them. That
logic lives in `henokinho/scripts/collect-prior-passes.sh` rather than inline in
the workflow, so it can be tested:

```
./henokinho/tests/test-collect-prior-passes.sh
./henokinho/tests/test-check-bot-login.sh
```

The suite is plain `bash` and `jq` — no framework, no install step. It runs the
real script against fixture JSON shaped like GitHub API responses and asserts on
the outputs and the digest. Run it after any change to that script.

The single most important line in it filters the PR's reviews by **login**, not
by `user.type == "Bot"`. Several bots review these PRs; selecting on the type
makes a bot read the other bots' reviews as its own history and believe it is on
pass 12 before it has ever run.
