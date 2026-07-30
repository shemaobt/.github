# Lens pack — React / TypeScript (`project-management-ecosystem`)

The Shemá Ecosystem console. React + TypeScript 5.9 + Vite 7 + Tailwind v4 +
Zustand + Radix/shadcn + Axios + i18next + react-leaflet.

**`CLAUDE.md` at the repo root is the source of truth — read it in full before
reviewing.** It is unusually detailed and it carries two rules that outrank
everything in this pack.

These conventions have **not** been measured by AST — the repo is new. Follow
João's epistemics: verify a convention against the code before asserting it, and
gate the ask on what you found.

---

## Rule zero and rule one — check these first, every time

**Rule zero: the frontend is derived from `DS-PROJECT/`.** It is the approved,
client-validated prototype. Every screen, layout, component, token, flow, label
and interaction MUST come from it.

- **`DS-PROJECT/` modified in the diff → flag it immediately.** It is read-only
  reference. Every Linear issue's Scope section repeats this.
- A screen invented, redesigned, or built without opening the corresponding
  prototype file is a defect — say which `DS-PROJECT/` file it should have come
  from.
- Option vocabularies (`TRANSLATION_TYPES`, `FINANCIAL_RESOURCES`, `OBJECTIVES`,
  `NEED_CATEGORIES`) are ported **verbatim** from `modals.jsx`, never re-derived
  from the PRD. Copy — labels, eyebrows, empty states, tooltips, toasts — comes
  from `data.js` `I18N.pt`/`I18N.en`.
- `shemaobt/meaning-map-ui` is an **engineering** reference only — versions,
  `src/` layout, the `cn()` + Radix + `cva` pattern, Docker/nginx wiring. Never
  its screens or its appearance. A PR that copies its visuals is a defect.

**Rule one: no backend is built here.** `shema-api` exists and already has a
scaffolded Shemá module (`app/api/shema/`, `app/services/shema/`). A PR that
scaffolds FastAPI, names a repo `shema-backend`, or adds a second Shemá service
is off-plan — flag it and point at `shema-api`.

---

## Lens 1 — Typed contracts

**Flag:**

- `any` where a real type exists. CLAUDE.md §11 states this directly.
- An API payload, store shape or component prop without an explicit type.
- `response.data['some_key']` style access into an untyped shape — his
  `⚠️ accessing dict directly with the key via string`, same defect in TS.
- A screen reading a hand-rolled local copy of the data instead of the **fixture
  layer** (wave 1) or the typed API namespace (wave 2). CLAUDE.md §4.1: every
  screen reads through the *same* fixture module — that is what makes wave-2
  integration mechanical and reversible one screen at a time.
- Types inferred from a sample response rather than read from `shema-api`'s
  OpenAPI schema. FastAPI produces it; use it.

**Do not flag:**

- Inferred types where inference is obvious and correct.
- Anything ESLint and `tsc -b` already report.

Types grown against fixtures are **not throwaway** — they are the input to the
data contract (FE-44). Treat a sloppy fixture type as a real finding.

---

## Lens 2 — Domain invariants

The product's safety properties. These are enforced in `shema-api`'s service
layer; the frontend only reflects them. That asymmetry is itself reviewable:

- **The frontend never *enforces* authorization.** Hiding a control in the UI is
  presentation, not security. A PR that implements a rule client-side only —
  and especially one whose PR body claims it as the enforcement — is a defect.
  Same for sensitive-country redaction and consent: *"a frontend-only rule is not
  a rule."*
- **Sensitive countries** (`sensitiveCountry`) must be handled with due caution on
  every output path: map, exports (JSON/CSV/TXT/HTML/PDF), prayer wall, ETEN
  report, notifications. A new output surface that skips the rule is a defect.
- **Consent** gates prayer requests, needs and media. Withdrawn consent **clears**
  shared text, it does not hide it. The guarantee under test: an unauthorized
  prayer request is absent from **all four** output paths.
- **Team roles resolve by reference** to the Equipe org chart. A role-holder name
  duplicated into another model is a defect.
- **Domain derivations are canonical** and ported from `DS-PROJECT/data.js` — the
  status and health enums, overall health as the worst of four dimensions, the
  60-day staleness rule, the four combinable presets, progress roll-ups appending
  to `progressHistory`. A re-derivation that quietly disagrees is a defect; quote
  the line back.

**Open client gates — do not let a PR freeze a gated contract.** If a diff
implements one of these, that is a lens-2 finding and the PR should say why:

| Gate | Issue |
|---|---|
| ETEN credit counting method | GATE-01 · OBT-387 |
| Final meeting set — Prayer Pulse vs. Governance | GATE-02 · OBT-388 |
| Monthly Pulse file format (`.html` / `.json`) | GATE-03 · OBT-389 |
| Coral: two list views or three | FE-17 · OBT-362 — **do not finish or delete Coral before this lands** |
| What "devida cautela" means per output | — |

If the repo carries prompt text, lens 2 of the core file applies verbatim.

---

## Lens 3 — Consistency

### Hard rules

- **Tailwind v4 only.** No CSS-in-JS, no styled-components, no SASS, no second
  styling system. No Redux, no MobX.
- **No arbitrary hex in JSX.** Tokens come verbatim from
  `DS-PROJECT/design-system/colors_and_type.css`; extend the theme instead.
- **`telha` (`#BE4A01`) is exclusive to CTAs, primary actions and active states.**
  Never decorative.
- **Never `bg-white`.** White is reserved for elevated surfaces, always via
  `bg-elevated`. Pages use `bg-canvas`, subtle fills `bg-muted`.
- **Cards have no borders** — depth is shadow only.
- **No generic greys.** The earthy Shemá palette only.
- **A single global `*:focus-visible` outline.** Components must not add
  `focus:ring-*` utilities.
- **One Axios client** in `src/services/api.ts`, namespaced APIs. Never a second
  client, never duplicated auth handling.
- **No comments for "what"**, and no module-level description comments. See §6 of
  the core file — not evidence-gated. Only a non-obvious *why* survives.

### Directional

- **Functional components only.** No class components.
- **Under 300 lines** per component file; over 400 it almost certainly needs
  splitting. Porting `modals.jsx` (1,525 lines) is a port **and** a decomposition
  — one folder, one component per tab.
- **Extract any UI pattern that appears twice** into `components/common/` or
  `components/ui/`.
- **Keep state local; lift to Zustand only when shared across routes.** Zustand
  for cross-page state, Context for auth/theme/UI, local state for forms and
  modals.
- **Structure:** `src/{components/{common,layout,pages,ui},contexts,stores,hooks,services,fixtures,types,constants,utils,i18n,styles}`.
- **Naming:** PascalCase for components (`ProjetosPage.tsx`), camelCase for
  utilities, hooks and stores (`api.ts`, `cn.ts`).
- **`cn()` for merging, `cva` for variants**, centralized class constants in
  `src/styles/`.
- **Typography:** Montserrat for UI, Merriweather for long-form and quotes only.
- **PT/EN parity.** Every string through i18next, keys ported from `data.js`.
  A hardcoded user-facing string is a finding.
- **Domain vocabulary stays Portuguese** where the product uses it — Ritmo, Pulso,
  Oração, Equipe, telha, verde. Do not anglicize identifiers that map to UI
  concepts the client names in Portuguese.
- **UX:** guided empty states that explain the concept and offer the action, never
  "No data found". Live counts on filters, presets and result rows. `InfoTooltip`
  for contextual guidance — no onboarding wizards, no blocking modals.
- **Dark mode** via Tailwind `@custom-variant dark`, overrides in
  `@layer base { .dark { … } }` using the same token names.

---

## Lens 4 — Latency

Name the surface. The heaviest ones here are the 127-project list, the Atlas
globe, and the filter sidebar.

- The sidebar computes **every facet count in a single pass** in the prototype —
  port that. A per-filter recount over 127 projects is the lens-4 defect to catch.
- Re-filtering or re-sorting the full list on every keystroke without memoization.
- Leaflet or globe layers rebuilt on unrelated state changes.
- Repeated passes over the same array where one would do — flag now, per the core
  file, not "before we scale".

---

## Lens 5 — Intent

Branches carry the Linear issue (`OBT-###`); PR bodies have `## Summary` and
`## Test plan`. Every issue declares **Scope (files this issue may touch)** and
**Out of scope** — a diff reaching outside its declared scope is the clearest
lens-5 finding available in this repo, so check the linked issue.

Watch the shared files, where two people collide: `src/components/ui/**` and the
i18n catalogues.

Several Definition-of-Done checkboxes **are** the product guarantee — the
byte-identical archive round trip, the double-import no-op, the unauthorized
prayer request absent from all four output paths. A PR claiming one of those
without the test is a lens-5 finding.
