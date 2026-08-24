# Lens pack — Flutter / Dart (`oral-collector`, `internalization-room`)

**This pack is deliberately thin, and the reason is the point of it.**

Measured 2026-08-24:

- `oral-collector` — 620 Dart files, `AGENTS.md` 315 lines. 242 PRs; Henok
  reviewed 4 of them and left **3** inline comments in the repo's history.
- `internalization-room` — **not measured at all.** No local clone existed when
  this pack was written, so no count in it has been run: not files, not
  `dynamic`, not conventions. 49 PRs; Henok reviewed 3 and left **8** inline
  comments.

So the corpus behind every rule below is **11 inline comments across 291 pull
requests**, and the repo that holds two thirds of them is the one nobody has
counted. The other stacks in this spec each rest on a measured codebase plus a
full review of a real PR. This one rests on neither.

**Nothing in this pack is stated flatly, and you may not state anything flatly on
this stack either.** A pack that invents rules for a stack nobody measured is
exactly the false-finding machine §5 of the core file exists to prevent. When you
need a rule here, get it from the repo's own `AGENTS.md` and cite the section, or
get it from the code and cite `path:line` — §8, first filter. If the repo has
neither, review on §0 alone: the code's contracts, checked, and nothing else.

---

## The five lenses here

Read §1 of the core file. It applies unchanged. What follows is only the local
form of the two lenses that have a Dart-specific shape, plus the one measurement
that was actually run.

### Lens 3 — typing discipline in Dart

The Dart form of a typing *gambiarra* is `dynamic` and the unchecked cast:
`dynamic` where a real type exists, `as` with nothing proving the shape,
`json['some_key']` reaching out of a `fromJson` and into a widget, a repository
handing `Map<String, dynamic>` to the presentation layer.

**And here is the measurement that stops you from asserting it.** In
`oral-collector`: **263** occurrences of `Map<String, dynamic>` and **174** other
uses of `dynamic`, across 620 files. Most of the first group are the idiomatic
`fromJson`/`toJson` signature and are not findings at all.

So `dynamic` on this stack is **directional at best** — closer to Python's `Any`
than to TypeScript's `any`, and nowhere near a rule you can state flatly. Ask
when new code carries raw JSON *past* the boundary that was supposed to map it,
name the layer it should have stopped at, and let everything else alone. Never
flag a missing type Dart infers; the analyzer and `flutter_lints` own that.

### Lens 5 — rebuild cost in `build()`

The local form of performance-that-bites is work done in `build()`: a network
call, a `jsonDecode`, a sort or a filter over a list, an object allocated on
every frame, or a whole provider watched where a narrower read would do. The
user-facing surface to name is the one this stack actually has — a field app on a
low-end Android phone with poor connectivity — and naming it is still required.

Everything else under lens 5 is off: no big-O, no micro-optimisation, and nothing
you cannot attach to a screen.

### Lenses 1, 2 and 4

Unchanged from the core file. Lens 4 is where the value is here, as everywhere:
run the new code's write path twice, run it with a field omitted, read every
`await` for what happens to the widget underneath it while it is in flight, and
read every claim a doc comment makes against the code below it.

## §6 here — comments

The rule from §6 of the core file holds on this stack, and unusually for this
pack there is a document to cite: `oral-collector/AGENTS.md` §1 carries
*"Self-documenting code (no comments)"* as a named section. Flag comments the
diff adds; never request them; the only survivor is a non-obvious *why*.

Do not extend that citation to `internalization-room` without opening its own
`AGENTS.md` first and quoting it.

## What this pack does not do

It does not tell you the state management library, the routing package, the
folder shape, the widget conventions or the error-handling style of either repo.
Those exist and they are written down — in each repo's `AGENTS.md`, which is the
authority. Read the sections that bear on the changed files and cite them. This
pack asserts none of it, because none of it was checked.
