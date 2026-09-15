---
description: Investigate and explain a target (PR, ticket, or concept) in full product context
---
Let's contextualize and investigate the target topic referenced below.

First, **identify what the target is** — it may be a pull request or commit, a bug description or trace, an issue/ticket, or maybe a feature/concept/process in the codebase or even an idea to evaluate. Resolve it to something concrete: fetch the PR and its diff, pull the ticket, locate the relevant code — whatever fits.

Then **investigate thoroughly**. Dive deep into the implementation and related code. Understand the involved features and their underlying implementation thoroughly. Make sense of abstraction layers, naming and any patterns in play. Draw on every source available: git history, project and deps documentation, your memories, the issue/PR tracker if relevant, etc.

Before starting the description, ask me whenever the investigation needs something outside your reach — a query against a production datastore, infrastructure config, env vars, access to a private dashboard. I can get that info for you. Don't substitute a guess.

First, describe the feature context. Structure your explanation from the outside in:
**Product context** — what feature(s) the target relates to, and where they sit in the product as a whole.
**Implementation** — how those features are built and how the relevant pieces fit together. Structure it so it's easy to refer to the code as a walkthrough.
    - Schematize the relevant section of the domain model as expressed in the code.
    - Describe the main modules of code involved (classes, modules, etc.) and how they cooperate to implement the features in question. Describe the main intent of the whole module as context to the functions/methods used in the code paths to describe.
    - Schematize the main user flows, code paths, and data flows using that context
Then, describe **the target itself** — a thorough, complete explanation grounded in the context above: what it is, what it does or changes, and why it matters.

Prioritize accuracy. Validate everything. If something is ambiguous or you can't determine it from the available sources, say so rather than guessing.

The target is: $ARGUMENTS
