# shemaobt/.github

Org-level GitHub configuration for [Shema](https://github.com/shemaobt). No
application code lives here — this repo holds the organization profile and the
reusable workflows that every product repo calls.

## Automated PR reviewers

Two bots review pull requests across the org. Each one stands in for a specific
human and runs **only when that person is personally requested as a reviewer** —
a request aimed at a team does not fire either of them, and neither runs on a
draft PR or on a PR opened by a bot.

| Bot | Stands in for | Reusable workflow | Spec |
|---|---|---|---|
| Joãozinho | @joaocarvoli | `.github/workflows/joaozinho-review.yml` | `joaozinho/` |
| Henokinho | @henokteixeira | `.github/workflows/henokinho-review.yml` | `henokinho/` |

Both go first so the human's own pass is cheaper. Neither replaces it, and
**neither ever approves** — approval belongs to the requested reviewer. They
differ on blocking: Joãozinho may request changes when run in `block` verdict
mode; Henokinho never blocks in any circumstance and posts only `--comment`
reviews.

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

Each bot posts as its own GitHub App. The `[bot]` login GitHub derives from the
App slug is not knowable until the App exists, which is why Henokinho takes it
as the `bot_login` input rather than hardcoding it.

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
```

The suite is plain `bash` and `jq` — no framework, no install step. It runs the
real script against fixture JSON shaped like GitHub API responses and asserts on
the outputs and the digest. Run it after any change to that script.

The single most important line in it filters the PR's reviews by **login**, not
by `user.type == "Bot"`. Several bots review these PRs; selecting on the type
makes a bot read the other bots' reviews as its own history and believe it is on
pass 12 before it has ever run.
