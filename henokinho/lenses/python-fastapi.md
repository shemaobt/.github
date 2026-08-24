# Lens pack — Python / FastAPI (`shema-api`)

FastAPI + SQLAlchemy 2 async + Pydantic v2, `uv`, Alembic, Neon Postgres.

**`CLAUDE.md` at the repo root (188 lines) is the authority — read it and do not
contradict it.** Where it and this file disagree about a *count*, this file wins,
because these numbers were measured against the code on 2026-08-24 at `4bd7ec0`
and `CLAUDE.md` was not. Where it and this file disagree about a *rule*,
`CLAUDE.md` wins.

If a repo on this stack has no `CLAUDE.md`, drop the rows below that cite it and
review on §0 alone: the code's own contracts, checked.

---

## Lens 1 — Simple code that solves what it set out to solve

The shape this takes here: a service function that only forwards to another
service function; a Pydantic model that duplicates a sibling with one field
renamed; a `try/except` around an intermediate call that re-raises with a new
message. That last one is worth its own sentence — **`try/except` belongs at
system boundaries, and wrapping an intermediate call destroys the traceback that
says where the failure started.**

**Do not flag** a long function that is genuinely doing one long thing. Service
functions here run 40–80 lines routinely and splitting them is your taste, not a
defect.

## Lens 2 — Security, where applicable

The real surfaces on this repo: signed GCS URLs (expiry present and short),
secrets (GCP Secret Manager per `CLAUDE.md` §6 — never a committed `.env`, never
a literal in code), and the auth dependencies in `app/core/auth_middleware.py`.
A new router that skips the auth dependency its siblings carry is a finding; say
which sibling.

## Lens 3 — Structure, typing and validation

### Hard rules — verified, state them flatly

Counted at `4bd7ec0` over the 491 files in `app/`:

- **Zero `HTTPException` in `app/services/`.** Services raise from
  `app/core/exceptions.py`; routers map them. (0 occurrences.)
- **Zero `select(` in `app/api/`.** No `db.execute()`, `db.add()`, `db.commit()`,
  no SQLAlchemy model import in a router. `AsyncSession` for DI is the only
  exception. (0 occurrences.)
- **Every schema change ships an Alembic migration.** Two migrations authored the
  same day create a multi-head that only fails at deploy — check the chain.
- **Async end-to-end.** `time.sleep`, sync `requests.*`, or a sync DB call in an
  async path is a defect.
- **The layers are separate and named:** `app/api` HTTP only, `app/services`
  business logic and *all* data access, `app/models` request/response schemas and
  DTOs (28 files), `app/db/models` SQLAlchemy tables only (23 files).

### `Any` is directional here — this is the single biggest false-finding risk

**104** `dict[str, Any]` / `-> Any` in `app/`. `CLAUDE.md` §5 says *"prefer
explicit typed models over generic `dict` when shape is known"* and the code does
not. So:

- Ask on a **new** public function whose shape is known and which returns
  `dict[str, Any]`. Name the fields you can see it returns; that is your evidence.
- **Never** demand retro-typing of a file the diff merely touched. All 104 of
  those are pre-existing and none of them is your finding.
- **Never** flag a missing annotation. The type checker owns those.
- **Never** flag a `type: ignore` or a `cast(`. There are **55** in `app/` and
  they are the accepted escape hatch.

### What the gates already own — never duplicate them

A finding a CI gate already produces is noise: the author sees it from the gate
before they see it from you, and it spends the credibility the review needs for
the findings only a reader can make.

`ruff` (config in `pyproject.toml`, run by `.github/workflows/lint.yml`) selects
`E, F, I, B, UP, C4, SIM, PIE, PGH, RUF` and ignores `B008`. So **import order,
unused imports and variables, un-modernised syntax, comprehension style,
simplifiable branches and a stale `# noqa` are all already caught.** Do not open
any of them. `alembic/versions` is excluded from ruff entirely.

`mypy` runs with `disallow_untyped_defs = true` and `warn_return_any = true`, and
excludes `alembic/` and `tests/`. So a missing annotation is never your finding —
and **typing in `tests/` is not a finding either**, because the relaxation is
deliberate.

### The exception hierarchy — and the tier that lives outside it by design

**22** custom exception classes: **14** in `app/core/exceptions.py`, **8**
deliberately outside it, next to the service that raises them
(`GenerationAlreadyInProgress`, `TranslationError`, `BackTranslationError`,
`GenerationError`, `InterviewIncompleteError`, `SessionLockedByOther`,
`StateVersionConflict`, `TranscriptConfirmConflict`).

`CLAUDE.md` §10 reads *"Keep service exceptions in `app/core/exceptions.py`"* as
if it were absolute. **It is not, and flagging one of those 8 is a false
finding.** Cross-cutting exceptions that the global handlers register live in
core; operational ones translated at a single router boundary live next to their
service.

Against that hierarchy sit **20** bare builtin raises in `app/` (9 `ValueError`,
11 `RuntimeError`). So the standardised-exception rule is aspirational: ask when
**new** code raises a generic exception for a case that already has a class, name
the class, and let the surrounding module alone.

### JSON columns — concentrated, and the concentration is the rule

**18** `JSON` columns, all inside 3 of the 23 files in `app/db/models/`:
`book_context.py` (11), `project_health.py` (5), `meaning_map.py` (2). The other
20 model files have none. Zero `JSONB` repo-wide.

Say nothing about a `JSON` column in those three modules. Ask when new code adds
one to a model that has none today, and say which typed shape you would expect
instead.

### Tics worth knowing before you call something inconsistent

`datetime.now(UTC)`, never `utcnow()`. Partial updates via
`model_dump(exclude_unset=True)` + `setattr` — and note that this is exactly the
pattern whose *absence* produces the unconditional-assignment bug lens 4 catches.
`get_settings()` called inside functions, not at module scope.

## Lens 4 — Bugs in the new code

The highest-value lens on this stack. These are the checks to **run**, not a list
of defects to recognise — each one is a question the diff has to answer, and the
answer is your §0 evidence whichever way it comes out.

- **Read every docstring in the diff as a claim, then check it against the code
  under it.** Words like immutable, write-once, idempotent, never, always and
  exactly one are assertions the function has to keep. Where it does not, quote
  the docstring back — the contract is the repo's, not yours, which is what makes
  the finding cheap to accept.
- **Run the write path twice.** Most bugs of this kind are invisible on the first
  call. What does a second call with the same input do — insert, overwrite, raise?
  Is that what the caller expects, and what the docstring promised?
- **Run the write path with a field omitted.** The house pattern for partial
  updates is `model_dump(exclude_unset=True)` + `setattr`. A path that assigns
  unconditionally nulls the column whenever the caller leaves the field out.
  Whether that fires today depends on the callers — count them and say so.
- **Read every query against the table's real key and the table's real filters.**
  Look at the model and the migration in the same diff: what does the primary key
  actually contain, which columns carry status or a version, and which of those
  does the query constrain? A query is only correct for the rows the table can
  hold, not for the rows it holds today. Say what the second row of a kind does to
  it.
- **Read every "pick one row out of many" as two questions.** What orders them,
  and what is excluded before ordering? An ordering that ties, or a filter that
  admits a row not yet in a usable state, silently returns the wrong one.
- **Anything used as an identity — digest, hash, cache key, dedup key — gets
  computed twice.** Serialisations are not automatically deterministic: gzip
  embeds an mtime, `json.dumps` without `sort_keys` follows insertion order, `set`
  iteration is unordered. Run it, paste both outputs, and let the two values be
  the argument.

**Do not** carry this lens into the surrounding code. If a check above fires on a
line the diff did not add, that is not your finding — §5, last row.

## Lens 5 — Performance that bites

The concrete form here is **N+1 in SQLAlchemy**: an `await db.*` call inside a
`for` loop. There are 10 such loops in `app/` today across 9 files, so it is not
unheard of — which means the finding is not "you did the thing nobody does", it is
"this one is on a path a user waits on". **Name the surface.**

**Do not** demand eager loading as a convention. There are **3** `selectinload`
and **0** `joinedload` calls in the whole of `app/` — asking for one because it
is good practice is asserting a convention the repo does not have, which §8
forbids.

## §6 here — comments

`CLAUDE.md` §5: *"Use docstrings, not inline comments. A `#` comment explaining
why belongs in the module or function docstring instead."* Measured: 324
standalone `#` comments in 31,426 lines of `app/`, about 1%.

`app/core/exceptions.py` is the model for the exemption that survives — its `#`
comments explain why two error codes that land on the same route cannot share a
code. That is a non-obvious *why* no name could carry. A comment restating the
line below it is not.

`alembic/versions/` is exempt entirely — generated files, never hand-edited.

## §7 here — test naming

1176 test functions in `tests/`; 81% carry five or more underscore-separated
words. Files are `test_<domain>_<aspect>.py`, functions
`test_<subject>_<condition>_<outcome>`. Tests run on SQLite and call service
functions directly. Hold new tests to the sentence form; do not ask for renames.
