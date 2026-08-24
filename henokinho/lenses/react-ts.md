# Lens pack — React / TypeScript (`sound-necklace`, `facilitator-desk`)

Two front ends, both React + TypeScript + Vite. Measured 2026-08-24 at each
repo's `main` tip: **515** tracked `.ts`/`.tsx` files — 384 in `sound-necklace`,
131 in `facilitator-desk`.

One thing to hold before you assert anything about how he reviews here: of his
185 inline review comments across the org, **8 are in `sound-necklace` and none
at all are in `facilitator-desk`.** There is no review corpus for half this
pair. Lean on the repos' own documents and on §0, not on a house voice nobody
has recorded.

Both carry a `CLAUDE.md` and they are read differently:

- **`sound-necklace/CLAUDE.md` is 101 lines. Read it in full.** It is short and
  every line of it is a rule you will need.
- **`facilitator-desk/CLAUDE.md` is 3348 lines. Do not read it end to end.** Its
  section headings are narrative sentences, not labels — *"State written after an
  `await` must prove it still owns what it writes"*, *"A count is not the only
  fact a served collection cannot carry"* — so `grep` it for the identifiers,
  components and directories the diff actually touches, and read the two or three
  sections that come back. A convention you did not find there is a convention
  you have not checked, and §8 of the core file says what to do about that.

If a repo on this stack has no `CLAUDE.md`, review on §0 alone and assert no
convention you have not measured in that repo yourself.

---

## Lens 1 — Simple code

The shape here is a wrapper that adds nothing: a hook that only calls one other
hook, a component that only spreads its props into one child, a context whose
value is a single constant. Also the reverse — a component that grew a second
responsibility because a prop was added rather than a sibling created.

**Do not** flag file length on its own, and do not propose a decomposition of
working code. The decomposition finding that *is* real is in lens 3, and it needs
duplication as its evidence.

## Lens 2 — Security, where applicable

Client-side rules are presentation, never enforcement: hiding a control, filtering
a list in the browser, or gating a route in the router does not make a rule hold.
A PR whose body claims a client-side check *as* the enforcement is a finding —
name the server path that has to carry it.

Tokens and credentials never reach source or `localStorage` where the repo has a
storage convention; hosts and keys come from config, not literals.

## Lens 3 — Structure, typing and validation

### `any` is a HARD rule here — the opposite of Python

**1** occurrence across all 515 files (0 in `sound-necklace`, 1 in
`facilitator-desk`). This rule genuinely holds, so **state it flatly**: an `any`,
an `as any`, or a `<any>` in new code is a defect and the repo has essentially
none of them. The same word is an aspiration on the Python side against 104
occurrences — read §5 of the core file and never carry the status across.

The same flatness extends to the untyped shape: an API payload, a store slice or
a component prop with no explicit type, and `response.data["some_key"]` reaching
into a shape nobody declared.

### Componentisation — this is the form lens 3 takes here

Henok named it explicitly for this stack: **markup duplicated instead of made a
component.** The finding needs the duplication as evidence — quote both sites with
their `path:line`. Two blocks that render the same thing with different data are a
component with a prop; two blocks that merely look similar are not, and that
distinction is the whole finding.

### Errors — ask narrowly, because the convention is weak

**129** raw `throw new Error(` against **11** custom error classes, and all 11 of
those live in `sound-necklace` (`adapters/*/types.ts` — `ApiError`, `AuthError`,
`LockLostError`, `SessionNotFoundError`, `AudioDecodeError`, and so on).
`facilitator-desk` has none at all.

So: **raise this only when new code adds a third variant of an error that already
has a class**, name the class and where it lives. Never against an existing
`throw new Error(`, and never in `facilitator-desk` as a convention — there is no
convention there to appeal to.

### What the tooling already owns — never duplicate it

`facilitator-desk` ships a custom ESLint rule (`eslint-rules/marks.js`) enforcing
the branded-identifier marks from `src/types/id.ts`. Anything that rule catches is
already caught. The same goes for whatever `tsc -b` and the configured ESLint
report. A finding a gate already produces is noise in a review.

### `sound-necklace` — layers that are actually frozen

`contracts/` and `domain/` are declared FROZEN in `CLAUDE.md`: changing them
requires the golden harness green **and** explicit human approval recorded in the
PR. A diff that touches either without that is a finding, and it is one you can
state flatly because the document says so.

The dependency rule there also genuinely holds — verified at the same date: zero
imports from `domain/` or `contracts/` toward `adapters/` or `ui/`, and zero
framework or IO imports in non-test `domain/` code. An entity or a piece of bead
math that reaches outward is a real violation of a real rule.

Inside `ui/`, atoms and molecules are purely presentational — props in, events
out, copy arrives as props, no domain, adapter or i18n imports. Only
pages/templates/`ui/app` wire adapters.

## Lens 4 — Bugs in the new code

The checks to run, in the order they pay off:

- **Read every `useEffect` against its dependency array.** Does the effect write
  state the array also depends on? That is a loop. Does the array contain an
  object, array or function rebuilt on every render? Then the effect fires every
  render, and the array is decoration. Say which of the two it is.
- **Read every state write that happens after an `await`.** By the time it lands,
  the component may be unmounted or the selection it was computed for may have
  moved. `facilitator-desk/CLAUDE.md` §6 has a whole section on exactly this —
  grep for it before you write the comment.
- **Read every derived value against the thing it derives from.** A count, a
  filter or a sort computed in the client from a page of results is wrong about
  the collection. `facilitator-desk`'s service-layer sections are explicit that
  ordering, filtering and aggregating belong to the service.
- **Read the empty and the single-item case.** Index arithmetic, `slice`, and
  "the first one" are where these break.

## Lens 5 — Performance that bites

`useEffect` loops and effects that fire per render are the critical case Henok
named for this stack, and they are lens-4 defects as often as lens-5 ones — an
effect in a loop is a bug, not a slow path. Report it under whichever it is.

Beyond that, only what a user waits on: re-filtering or re-sorting a full list on
every keystroke, a `fetch` inside a list item, a canvas or audio graph rebuilt on
unrelated state. There are **65** `useEffect` calls and **45**
`useMemo`/`useCallback` calls across the two repos, so memoization here is used
where it is needed, not everywhere — **do not ask for a `useMemo` you cannot
attach to a surface the user waits on.** Name the screen.

## §6 here — comments

Same rule as everywhere: flag comments the diff adds, never request them, and the
only survivor is a non-obvious *why*. Note that `facilitator-desk`'s own
`eslint-rules/marks.js` opens with a long block comment explaining why a rule
exists and what it deliberately does not cover — that is the exemption used
correctly, and it is a fair thing to point at when someone asks what qualifies.
