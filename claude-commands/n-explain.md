---
description: Investigate and explain a target (PR, ticket, or concept) in full product context
---
Let's contextualize and investigate the target topic referenced below.

First, **identify what the target is** — it may be a pull request or commit, a bug description or trace, an issue/ticket, or maybe a feature/concept/process in the codebase or even an idea to evaluate. Resolve it to something concrete: fetch the PR and its diff, pull the ticket, locate the relevant code — whatever fits.

Then **investigate thoroughly**. Dive deep into the implementation and related code, and draw on every source available: git history, project docs, your memories, and the issue/PR tracker where relevant.

Ask the user (me) whenever the investigation needs something outside your reach — a query against a production datastore, infrastructure config, env vars, access to a private dashboard. They can run it for you. Don't substitute a guess.

Structure your explanation from the outside in:
1. **Product context** — what feature(s) the target relates to, and where they sit in the product as a whole.
2. **Implementation** — briefly, how those features are built and how the relevant pieces fit together. Briefly schematize the main user flows, code paths, and data flows. It helps also to describe the main pieces of code (classes, modules, functions, etc.) and how they cooperate to implement the features in question.
3. **The target itself** — a thorough, complete explanation grounded in the context above: what it is, what it does or changes, and why it matters.

Prioritize accuracy. Validate everything. If something is ambiguous or you can't determine it from the available sources, say so rather than guessing.

The target is: $ARGUMENTS
