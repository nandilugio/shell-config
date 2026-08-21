---
description: Review a code change (PR, branch, diff, etc.) in full product context
---
Let's contextualize and investigate the target code change referenced below.

**Phase 1 — Identify.** Work out what the target is — it may be a pull request, a branch, a commit, a diff or similar. Resolve it to something concrete: fetch and read it fully.

**Phase 2 — Investigate.** Dive deep into the changes and related code. Understand the involved features and their underlying implementation thoroughly. Make sense of abstraction layers, naming and any patterns in play. Draw on every source available: git history, project and deps documentation, your memories, the issue/PR tracker if relevant, etc.

Be extensive here — this phase is for you, not for the output. Ask me whenever the investigation needs something outside your reach: a query against a production datastore, infrastructure config, env vars, access to a private dashboard, etc. I can run it for you. Don't substitute a guess.

**Phase 3 — Describe** the change and its surroundings, from the outside in:
1. **Product context** — what feature(s) the target relates to, and where they sit in the product as a whole.
2. **Implementation** — how those features are built and how the relevant pieces fit together. Schematize the relevant section of the domain model as expressed in the code. Also the main user flows, code paths, and data flows. Describe the main pieces of code (classes, modules, functions, etc.) and how they cooperate to implement the features in question. Structure it so it's easy to refer to the code as a walkthrough.
3. **The target itself** — a thorough, complete explanation grounded in the context above: what it is, what it does or changes, and why it matters.

This description is what I read *before* looking at the diff myself, so that reading the code afterwards is easy. Give me the broad picture and the map, not a line-by-line re-narration of the diff.

**Phase 4 — Review.** Assess the change along these axes, in roughly this order of importance:

*Does it meet its objective?*
- The objectives described in any specification available (ticket, PR description, etc. if present)
- Scope: not implementing anything not requested or clearly valuable (code is liability)

*Is it correct?*
- Bugs, unhandled edge cases, error handling
- Concurrency, ordering and failure modes where relevant
- Backward compatibility, migrations, and data integrity
- Test coverage: whether the change is verified, and whether the tests are worth their cost

*Is it the right design?*
- Structure and modelling. Abstractions correctness and simplicity, following the codebase patterns and rules
- New dependencies: whether they're necessary, and whether they're unnecessarily complex or risky in any other way

*Is it well executed?*
- Code quality, readability, maintainability, naming

These axes are a checklist for you, not an output structure, and they're not exhaustive. Write the review as a series of points ranked most to least blocking, each tagged **[blocking]**, **[worth fixing]** or **[nit]**. Focus on the most important things. Don't pad with praise or with points that don't change anything.

**Phase 5 — Verdict.** Emit a clear verdict (approve, comment, request changes) — it should follow from the tags above — and draft a review comment.

Keep the whole output brief. Keep the review comment *especially* brief: NO MORE THAN ONE OR TWO PARAGRAPHS. Too long of a review is often ignored or dismissed, or even felt outright aggressive. We don't want that. Avoid any flattery and go straight to the point. Also allow for the possibility of us being mistaken; when it makes sense, structure the comment more as questions rather than stating "this is wrong". All of that while still keeping it short!

Prioritize accuracy. Validate everything. If something is ambiguous or you can't determine it from the available sources, say so rather than guessing.

The target is: $ARGUMENTS
