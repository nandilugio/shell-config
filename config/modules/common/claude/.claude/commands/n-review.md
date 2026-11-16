---
description: Review a code change (PR, branch, diff, etc.) in full product and technical context
---
Let's contextualize and investigate the target code change referenced below.

**Phase 1 — Identify.** Work out what the target is — it may be a pull request, a branch, a commit, a diff or similar. Resolve it to something concrete: fetch and read it fully. Also establish its state where applicable: how old it is, whether it's up to date with its base and conflicts with it, its CI status, and any related work in flight (tickets, other open changes) it depends on or interacts with.

**Independent review.** As soon as the target is resolved, start the built-in code review (`/code-review`) on it. Pass the target explicitly (PR number, branch or revision range) and the effort given in the arguments; if none was given, don't pass one, so it keeps the level last used. Never pass `--comment` or `--fix`; in general we don't want effects without my approval. It takes no other input: it builds its own context from the repository and `CLAUDE.md`, so its view stays independent of yours. It runs in the background, so carry on meanwhile. Its findings are input for Phase 4, not part of the output: don't report them on their own.

**Phase 2 — Investigate.** Dive deep into the changes and related code. Understand the involved features and their underlying implementation thoroughly. Make sense of abstraction layers, naming and any patterns in play. Draw on every source available: git history, project and deps documentation, your memories, the issue/PR tracker if relevant, etc.

Be extensive here: this phase is for you, not for the output. Ask me whenever the investigation needs something outside your reach (a query against a production datastore, infrastructure config, env vars, a private dashboard, missing product context, etc.), and do it before producing the output. I can run it for you. Don't substitute a guess.

**Phase 3 — Describe**
First, describe the target's context. Describe the change against what it replaces: what was there before, what changes and what stays, so the difference is visible without having to reconstruct the old state. Use the comparison where it carries meaning, mostly for users and their flows, and keep it light where it would only add noise. Structure your explanation from the outside in:
1. **Who it's for and why.** Identify who the change affects: end users (customers, ...), internal users (support, ops, ...), or developers and agents working with a tool or the codebase itself. From their point of view, explain what problem it addresses, how they deal with it today, and what changes for them.
2. **Background.** The domain and operational knowledge needed to follow the rest: what the surrounding systems are and do, where their inputs and configuration come from, and the concepts and terms the explanation relies on, introduced before they're used. Describe what things are and do, not how the code implements them: keep code internals for the Implementation section.
3. **User flows.** The flows the change touches, framed by the goals users pursue through them: what they need before starting (knowledge, data, access, setup), what they do and with what (screens, files, commands, APIs), what each of those is for and what it acts on, what they get as a result, and what happens when something goes wrong or their case isn't covered. Compare with how they reach those goals today, and say why the new way is better, or where it isn't. Schematize the flows if it helps.
4. **Implementation.** How the target is built and how the pieces fit together, structured so it's easy to use as a walkthrough of the code.
    - Schematize the relevant section of the domain model as expressed in the code.
    - Describe the main code pieces involved (classes, modules, scripts, config, etc.), the intent of each, and how they cooperate.
    - Schematize the main code paths and data flows.

For every mechanism, explain what it's for and how it behaves, not only what it's called. Use terms consistently and pin down what each reference means (which machine, which file, which value), so the explanation is self-contained and unambiguous. Keep facts apart from inferences.

Before writing, ask yourself the questions a newcomer in the affected user's role would ask to understand and use this change, and make sure the description answers them.

Then, describe **the target itself**, thoroughly and grounded in the context above: what it is, what it does or changes, and why it matters.

This description is what I read *before* looking at the diff myself, so that reading the code afterwards is easy. Give me the broad picture and the map, not a line-by-line re-narration of the diff.

**Phase 4 — Review.** Assess the change along these axes, in roughly this order of importance:

*Does it meet its objective?*
- The objectives described in any specification available (ticket, PR description, etc. if present)
- Scope: not implementing anything not requested or clearly valuable (code is liability)

*Does it work for the people who use it?*
- Usability and operability of the affected flows: interfaces, error messages, recovery paths
- Documentation and discoverability, for humans and agents, where its users need them

*Is it correct?*
- Bugs, unhandled edge cases, error handling
- Concurrency, ordering and failure modes where relevant
- Backward compatibility, migrations, and data integrity
- Security: secrets, permissions, and exposure of data or access
- Test coverage: whether the change is verified, and whether the tests are worth their cost

*Is it the right design?*
- Structure and modelling. Abstractions correctness and simplicity, following the codebase patterns and rules
- New dependencies: whether they're necessary, and whether they're unnecessarily complex or risky in any other way

*Is it well executed?*
- Code quality, readability, maintainability, naming

These axes are a checklist for you, not an output structure, and they're not exhaustive. Write the review as a series of points ranked most to least blocking, each tagged **[blocking]**, **[worth fixing]** or **[nit]**. Focus on the most important things. Don't pad with praise or with points that don't change anything.

Wait for the built-in review's findings and fold them in: verify each one yourself, deeply, before including it, since reviewers state wrong things with full confidence. Merge duplicates into your own points, and list the ones you discard, one line each with the reason.

**Phase 5 — Verdict.** Emit a clear verdict, one of: approve, approve with comments, comment, request changes. It should follow from the tags above. Then draft a review comment.

The review comment is read by its author while being critiqued, so write it to be taken in and welcomed. Respect their time: say only what they need to act on, as briefly as possible, since a long critique gets skimmed, dismissed or read as hostile. Put in the comment only what's worth the author's time; the full list stays in the review. _Skip flattery and praise;_ when there's nothing worth raising, the best review is a plain approval with no comment. Open directly with the first finding: no opener of any kind (no "nice work", "looks good", "makes sense"). Assume competence: a problem is more likely an overlooked detail, or a reason we can't see, than a misunderstanding, so don't frame it as the author being wrong. And leave room for them to be right: when we might be missing context, ask rather than assert.

Produce the full output (state, description, review, verdict and comment) in one pass, and refer only to things it actually contains.

Keep the wording of the whole output brief: brevity applies to how things are said, not to what the description must cover.

Again, prioritize accuracy. Validate everything. If something is ambiguous or you can't determine it from the available sources, say so rather than guessing.

The target, the effort for the built-in code review, and any further instructions: $ARGUMENTS
