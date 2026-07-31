---
description: Investigate and explain a target (PR, ticket, or concept) in full product context
---
Let's contextualize and investigate a target: $ARGUMENTS

First, **identify what the target is** — it may be a pull request, an issue/ticket (e.g. Jira), or a feature/concept/process in the codebase. Resolve it to something concrete: fetch the PR and its diff, pull the ticket, and/or locate the relevant code — whatever fits.

Then **investigate thoroughly**. Dive deep into the implementation and related code, and draw on every source available: git history, project docs, your memories, and the issue/PR tracker where relevant.

Structure your explanation from the outside in:
1. **Product context** — what feature(s) the target relates to, and where they sit in the product as a whole.
2. **Implementation** — briefly, how those features are built and how the relevant pieces fit together. Briefly schematize the main user flows, code paths, and data flows.
3. **The target itself** — a thorough, complete explanation grounded in the context above: what it is, what it does or changes, and why it matters.

Prioritize accuracy. If something is ambiguous or you can't determine it from the available sources, say so rather than guessing.
