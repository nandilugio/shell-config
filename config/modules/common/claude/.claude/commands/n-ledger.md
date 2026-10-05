---
description: Maintain a fact and inference ledger for an ongoing investigation
---
Let's keep a **fact and inference ledger** for our findings, in a file, updated as we go rather than written up at the end.

The point is to separate what we *measured* from what we *concluded*, and to make the dependency between them explicit. Investigation notes that blend the two are useless the moment a fact turns out wrong, because there's no way to tell which conclusions die with it. Tagging every inference with the facts it rests on means a retraction has a blast radius we can actually trace.

**Structure it in four sections, with stable IDs** so entries can be added and cross-referenced without renumbering:

- **F#: Facts.** Things measured, read, or run directly. Every fact states *how* it was established: the command, the file and line, the arithmetic, the sample size, and when it was measured. An assumption must never sit in the ledger looking like a fact.
- **I#: Inferences.** Conclusions drawn from facts. Every inference names the specific facts it depends on (e.g. "Depends on F4, F7, F12"), so that when a fact changes we can trace what else has to be revisited.
- **O#: Open questions.** Numbered like the rest. Say what is unknown, why it matters, and whether it is currently the bottleneck on the conclusion.
- **X#: Retracted or superseded claims.** Anything asserted that later proved wrong, overstated, or based on too small a sample. State what was claimed, what the evidence actually showed, and which F# or I# replaces it. Include your own analysis mistakes and tooling errors, distinguishing them clearly from real problems in the subject under investigation.

**What belongs in the ledger:**

- A fact goes in when an inference depends on it, or when it rules something out. Prefer what is expensive to rediscover and slow to change: how a mechanism works (verified in code), history and intent (git history, commit messages, tickets), structural gaps, and decisions or proposals with their status.
- Negative results count: a check that ruled something out, or that could not be done (no access, tool failed, out of scope), goes in with its reason, because it matters later that we know it was checked. Record the conclusion or the limit it revealed, not the step-by-step of attempts and retries.
- Leave out point-in-time snapshots nothing depends on (current counts, queue sizes, per-run output). They go stale within days and anyone can re-query them; they only bury the findings that took real work to establish.

**Rules while maintaining it:**

- Keep facts and inferences strictly separate. If something is a guess, a projection, or an extrapolation, it is an inference or an open question, never a fact, however obvious it seems. A number you computed is a fact; a number you expect to see is not.
- Record the sample or scope each fact rests on, and flag explicitly when a conclusion depends on a sample small enough to mislead. Widening a sample later is one of the most common ways facts get retracted.
- When new evidence contradicts an earlier entry, remove it from F# or I# and add an **X#** entry saying what was claimed, what the evidence showed, and which inferences depended on it and what happened to them. If the correction establishes something new, add it as a new F# or I# with a new ID and point to it from the X# entry. Retired IDs are never reused. F# and I# hold only what is currently believed, with no strike-throughs; the history of what changed lives in X#. Never quietly rewrite history: the retracted list is what lets a reader calibrate how much to trust everything else, and a ledger that only ever shows correct conclusions is a persuasive artifact, not an accurate one.
- Keep numbers exact, with their date and scope, rather than rounded into vagueness. Prefer tables for anything quantitative.
- Note the work state at the end: what is committed, what is pushed, what exists only locally, and what is projected but not yet measured.

**Keep it current as findings land, not in a single pass at the end.** Each time you update it, tell me briefly what changed, and call out explicitly when a retraction invalidates something we had already acted on, since that is the case where a stale ledger does real damage.

Put the file somewhere durable rather than a temp dir that gets wiped, and tell me the path. If a ledger for this investigation already exists, update that one instead of starting a new file.

$ARGUMENTS
