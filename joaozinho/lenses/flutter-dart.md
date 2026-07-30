# Lens pack — Flutter / Dart (`oral-collector`)

The Oral Capture mobile + web app for collecting monolingual audio. Flutter,
Dart 3, Riverpod, go_router, http/dio, flutter_secure_storage.

**`AGENTS.md` at the repo root is the source of truth — read it in full before
reviewing.** Every rule below is drawn from it; where you need a detail this file
does not cover, AGENTS.md has it.

Unlike the Python pack, these conventions have **not** been measured against the
code by AST. Treat them as stated rules, and follow João's own epistemics: check
the convention against the repo before asserting it, and gate the ask on what you
found — *"if X is majority on the codebase, adapt this file"*.

---

## Lens 1 — Typed contracts

The Dart analogue of his `dict[str, Any]` concern is **raw JSON leaking upward**.

**Flag:**

- A repository returning `Map<String, dynamic>` — or `jsonDecode(response.body)`
  directly — instead of mapping to a domain entity. AGENTS.md §8: *"Do not pass
  raw `Map<String, dynamic>` to the presentation layer."*
- `json['some_key']` string-key access surfacing outside a `fromJson`. This is
  exactly his `⚠️ accessing dict directly with the key via string` — use those
  words.
- A screen or widget parsing JSON. Parsing belongs in the repository.
- `dynamic` where a real type exists.

**Do not flag:**

- Missing explicit types where Dart infers them. `var`/`final` with an obvious
  initialiser is idiomatic and the analyzer owns it.
- Anything `analysis_options.yaml` + `flutter_lints` already reports.
- Test typing.

---

## Lens 2 — Domain invariants

The app's governing invariant, and the highest-value thing to catch here:

**The app is a thin client.** It authenticates, calls APIs, maps responses to
typed entities, manages UI state and renders. **Business logic lives on the
backend.** Flag as a real defect:

- Filtering by role, computing scores, deriving domain values, or validating
  beyond basic form checks, done locally.
- A repository that computes derived data or decides what to show.
- A local database, ORM or persistence layer added "for future offline support".
  Local storage is justified only by a concrete feature: secure credentials,
  offline support, user preferences, caching. Anything else is speculative
  extensibility — a Rule 0 defect.

**Secrets and config**, from AGENTS.md §9 — treat these as hard:

- No hardcoded API host, base URL, key or credential. Config comes from
  `Env`/dotenv/envied; `.env` is gitignored and `.env.example` carries names only.
- Tokens go in `flutter_secure_storage`, never `shared_preferences`, never code.
- Fail fast on missing required config rather than defaulting to a production URL
  or an empty string that hides the misconfiguration.

If this repo contains prompt text or generation instructions, lens 2 of the core
file applies verbatim — permissive modals are correctness bugs.

---

## Lens 3 — Consistency

### Hard rules

- **Clean architecture, dependencies point inward.** Domain entities import
  neither Flutter nor HTTP/storage packages. Presentation depends on data; data
  depends on domain; domain depends on nothing. An entity importing `material.dart`
  is a violation.
- **No HTTP or JSON parsing in a screen or widget.**
- **Riverpod only.** No GetX, no Bloc, no second state or navigation system.
- **Stack is closed:** Flutter, Dart 3, Riverpod, go_router (or `MaterialApp.home`),
  http/dio, flutter_secure_storage, path_provider, shared_preferences,
  dotenv/envied, lucide/cupertino icons, google_fonts, flutter_lints. A new
  dependency outside this list needs justification in the PR body.
- **No comments explaining *what*.** See §6 of the core file — this is not
  evidence-gated. AGENTS.md §1 also bans module-level docstrings at the top of a
  file. The only exception is a non-obvious *why*: a platform constraint or
  workaround, e.g. `// iOS requires entitlement for Sign in with Apple`.

### Directional

- **Prefer functions and composition over classes and inheritance.** Pure helpers
  where possible. Classes only for genuine identity or lifecycle — repositories,
  entities, notifiers. A "Manager" class doing auth + HTTP + storage + navigation
  is the anti-pattern AGENTS.md names explicitly.
- **Feature-based layout:** `lib/features/<name>/{data,domain,presentation}`, with
  `lib/core/{config,theme,router,providers,constants}`. Code landing outside this
  shape needs a reason.
- **One provider per logical state.** No mirroring server state in both a provider
  and a `StatefulWidget`. Screens `ref.watch`; actions call
  `ref.read(p.notifier).method()`.
- **Widgets:** prefer `StatelessWidget` / `ConsumerWidget`; `StatefulWidget` only
  for local UI state that providers cannot express. Screens suffixed `Screen`.
  Keep files under ~200–300 lines. Extract a UI pattern that appears twice.
- **Theme over raw values.** `Theme.of(context)`, `AppColors.*` — not
  `Colors.blue` or a scattered `TextStyle(fontSize: 16, color: Color(0xFF333333))`.
- **Reuse before adding.** A wrapper provider that only forwards to an existing
  provider with no added behaviour is overengineering — flag it.
- **Async:** `async`/`await` over raw `Future.then`; `AsyncValue` for async UI
  state; check `context.mounted` after an await before navigating.

---

## Lens 4 — Latency

This is a **field app on an old Android phone with no connectivity**. That is the
user-facing surface to name when you flag something.

- Network calls in `build()`, or per-item calls in a list builder — N+1 over the
  wire.
- Repeated passes over the same data where one would do.
- Missing `context.mounted` guards causing work after dispose.
- Rebuild storms: watching a whole provider where a `select` would narrow it.
- Anything that makes a recording or an upload lose work when connectivity drops.

Flag now, not "before we scale".

---

## Lens 5 — Intent

Semantic commits, `type(scope): short description`. Read the diff against the PR
title. A screen added with no provider wiring, a repository method with no caller,
or a diff that quietly widens past its stated scope are lens-5 findings.
