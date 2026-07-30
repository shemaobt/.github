# Lens pack — Python / FastAPI (`shema-api`)

FastAPI + SQLAlchemy 2 async + Pydantic v2, `uv`, Alembic, Neon Postgres.
`CLAUDE.md` at the repo root is the source of truth — read it. Where it and this
file disagree, **this file wins**, because it was measured against the code and
CLAUDE.md was not.

House style measured by AST-parsing the repo at the Apr 30 2026 tip. João founded
it (~440 commits since 2026-02-27) and is its dominant author, so this **is** the
house style. Counts are exact.

---

## Lens 1 — Typed contracts

**Flag:**

- A public function returning `dict[str, Any]` or `Any` where the shape is known.
  Ask for a Pydantic model (preferred) or a TypedDict.
- `result["some_key"]` string-key access on an internal structure. His exact
  words for this: `⚠️ accessing dict directly with the key via string`.
- A repository/service boundary handing a raw `dict` to a caller that knows the
  fields.

**Do not flag:**

- Missing annotations. `pyproject.toml` sets `disallow_untyped_defs = true`;
  `app/services` is 281/282 return-annotated and `app/api` is 171/171. mypy owns
  this.
- Anything in `tests/` — mypy excludes them, 27% param annotation, deliberate.
- `stmt = select(...)` without an annotation. He rejects annotations that
  duplicate inference: *"the explicit type annotation `stmt: Select[tuple[…]]` is
  verbose"*.

**The typing split:** Pydantic for API schemas and LLM structured output;
TypedDict **only** for LangGraph state; `@dataclass` for internal DTOs. Pydantic
wins ties. The end state he pushed for on #48 was a Pydantic `BaseModel` with
attribute access and `.model_dump()` at the boundary.

---

## Lens 2 — Domain invariants and prompts

- **LLM prompt text is reviewable code.** Permissive modals (`you MAY add…`,
  `PREFER…`, `if useful, infer…`) are correctness bugs. Quote the line back.
- **The generation contract:** the structured source (BHSA) anchors every entity;
  the LLM enriches descriptive fields only. Anything the model emits without a
  lemma anchor is invalid output.
- **Shemá module invariants** (`app/services/shema/`), all enforced service-side:
  - Sensitive-country redaction must hold on **every** output path — map,
    exports, prayer wall, ETEN report, notifications. A new output surface that
    skips it is a defect, not a nit.
  - Consent gates prayer requests, needs and media. Withdrawn consent **clears**
    shared text, it does not merely hide it.
  - The Monthly Pulse import is idempotent and transactional — a double import is
    a no-op.
  - Authorization is by role **and region**, enforced in services.

---

## Lens 3 — Consistency

### Hard rules — verified to genuinely hold, state them flatly

- **Zero DB access in `app/api/`.** No `db.execute()`, `db.add()`, `db.commit()`,
  `select()`, no SQLAlchemy model or query import in a router. `AsyncSession` for
  DI is the only exception. (Verified: zero `select(` in `app/api/`.)
- **Services never import `fastapi.HTTPException`.** (Verified: zero imports.)
  They raise from `app/core/exceptions.py`; routers map them.
- **Every schema change ships an Alembic migration.** Two migrations authored the
  same day create a multi-head that only fails at deploy — check the chain.
- **Async end-to-end.** `time.sleep`, sync `requests.*`, or a sync DB call in an
  async path is a defect.

### Directional — enforce forward only, and gate on evidence

- **Services are functional.** 216 files in `app/services/`: 282 functions, **zero
  service classes.** The only 13 classes are 7 Pydantic LLM schemas, 1 TypedDict,
  1 dataclass, 4 exceptions. You may assert this one confidently.
- **One public function per file, file named after it.** 177/192 service files
  have exactly one public function; 150 (78%) have `function name == filename`.
  The older grouped style coexists — do not flag it, but new code follows this.
- **Routers:** param order is invariant — path params → `payload` → `user` → `db`
  last. Return type annotated *and* `response_model=` set, with explicit
  `.model_validate()`. Names: `payload`, `rows`, `_router` suffix.
- **Schemas:** suffixes `*Response` (70), `*Request` (18), `*Create` (17),
  `*Update` (16). `model_config` is **always a plain dict literal — `ConfigDict`
  appears zero times repo-wide.** Validation is declarative: **91 `Field()` calls
  vs 3 validators total.** `Literal` aliases for small closed sets, `StrEnum` in
  `app/core/enums.py` for status machines. `Update` = all optional; `Response` =
  optionals defaulted `None`.
- **Tests:** 49 files, 494 functions, **0 test classes**, 455
  `@pytest.mark.asyncio`. Flat `tests/`, `test_<domain>_<aspect>.py`, functions
  `test_<subject>_<condition>_<outcome>`. Tests call **service functions
  directly, not HTTP** — commit `6189a78f` deliberately removed API tests in
  favour of service-layer ones.
- **Docstrings:** services get a one-line docstring stating contract or *why*;
  routers, schemas and tests get none. Do not trust the 13% average — it is scar
  tissue from commit `8b59bd46`, which stripped docstrings indiscriminately.
  Greenfield files sit at 100%.
- **Tics:** `datetime.now(UTC)`, never `utcnow()`. Partial updates via
  `model_dump(exclude_unset=True)` + `setattr`. `get_settings()` called inside
  functions, not at module scope. `# type: ignore` always carries an explicit
  code.

### The exception taxonomy — do not misread tier 2

- **Tier 1** — cross-cutting, in `app/core/exceptions.py`, bodiless `Exception`
  subclasses, globally registered, never caught by services (`NotFoundError`,
  `ConflictError`, `AuthorizationError`, `AuthenticationError`, `RoleError`,
  `ValidationError`, `InvalidTokenError`, `UpstreamServiceError`).
- **Tier 2** — operational, defined *next to the raising service*, not in core,
  not registered, translated at the router boundary (`GenerationError`,
  `TranslationError`, `GenerationAlreadyInProgress`).

CLAUDE.md's *"keep service exceptions in `app/core/exceptions.py`"* reads as
absolute, but the real design has this second tier. **Flagging a tier-2 exception
is a false finding.** Chaining with `from err` is consistent; the variable name is
not (`exc` ×10, `e` ×9, `err` ×1) — no convention, do not flag.

### Shemá module

Shemá is a **module inside this repo** (`app/api/shema/`, `app/services/shema/`,
`app/models/shema.py`), not a new service. A PR that scaffolds a second Shemá
service, app or client is off-plan — flag it. Before new capability, check the
reuse table in `project-management-ecosystem/CLAUDE.md` §3.2: auth, roles, org
scope, projects, orgs/languages/phases/places, uploads, notifications and i18n
already exist here.

---

## Lens 4 — Latency

Repeated passes or N+1 I/O over the same data — flag **now**, naming the
user-facing surface it degrades (the Meaning Map UI, the console's project list).
Not "before we scale".

---

## Lens 5 — Intent

Commits are strictly layer-ordered within a PR (`feat(db)` → `feat(schemas)` →
`feat(services)` → `feat(api)` → `test` → `fix(lint)`), Conventional Commits, and
lint/format fixes are always separate commits from logic. A field with no
migration, an endpoint with no service-layer test, or a diff that contradicts its
own title are all lens-5 findings.
