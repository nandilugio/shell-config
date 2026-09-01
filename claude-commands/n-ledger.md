---
description: Maintain a fact and inference ledger for an ongoing investigation
---
Let's keep a **fact and inference ledger** for this investigation, in a file, updated as we go rather than written up at the end.

The point is to separate what we *measured* from what we *concluded*, and to make the dependency between them explicit. Investigation notes that blend the two are useless the moment a fact turns out wrong, because there's no way to tell which conclusions die with it. Tagging every inference with the facts it rests on means a retraction has a blast radius we can actually trace.

**Structure it in four sections, with stable IDs** so entries can be added and cross-referenced without renumbering:

- **F#** — **Facts.** Things measured, read, or run directly. Every fact states *how* it was established: the command, the file and line, the arithmetic, the sample size. Include negative results and things you tried but could not verify, with the reason (no access, tool failed, out of scope) — ruling something out is a finding, and it matters later that we know it was checked. An assumption must never sit in the ledger looking like a fact.
- **I#** — **Inferences.** Conclusions drawn from facts. Every inference names the specific facts it depends on (e.g. "Depends on F4, F7, F12"), so that when a fact changes we can trace what else has to be revisited.
- **O#** — **Open questions.** Numbered like the rest. Say what is unknown, why it matters, and whether it is currently the bottleneck on the conclusion.
- **X#** — **Retracted or superseded claims.** Anything asserted that later proved wrong, overstated, or based on too small a sample. State what was claimed, what the evidence actually showed, and which F# or I# replaces it. Include your own analysis mistakes and tooling errors, distinguishing them clearly from real problems in the subject under investigation.

**Rules while maintaining it:**

- Keep facts and inferences strictly separate. If something is a guess, a projection, or an extrapolation, it is an inference or an open question — never a fact, however obvious it seems. A number you computed is a fact; a number you expect to see is not.
- Record the sample or scope each fact rests on, and flag explicitly when a conclusion depends on a sample small enough to mislead. Widening a sample later is one of the most common ways facts get retracted.
- When new evidence contradicts an earlier entry, move it to **X#** with the correction rather than editing it in place. Never quietly rewrite history: the retracted list is what lets a reader calibrate how much to trust everything else, and a ledger that only ever shows correct conclusions is a persuasive artifact, not an accurate one.
- Prefer tables for anything quantitative, and keep the numbers exact rather than rounded into vagueness.
- Note the work state at the end: what is committed, what is pushed, what exists only locally, and what is projected but not yet measured.

**Keep it current as findings land, not in a single pass at the end.** Each time you update it, tell me briefly what changed — and call out explicitly when a retraction invalidates something we had already acted on, since that is the case where a stale ledger does real damage.

Put the file somewhere durable rather than a temp dir that gets wiped, and tell me the path. If a ledger for this investigation already exists, update that one instead of starting a new file.

$ARGUMENTS
