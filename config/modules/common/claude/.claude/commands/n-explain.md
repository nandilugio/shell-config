---
description: Investigate and explain a target (PR, ticket, bug, or concept) in full product and technical context
---
Let's contextualize and investigate the target referenced below.

First, **identify what the target is**: a pull request or commit, a bug description or trace, an issue or ticket, a feature, concept or process in the codebase, or an idea to evaluate. Resolve it to something concrete: fetch the PR and its diff, pull the ticket, locate the relevant code, whatever fits. When it's a change or a ticket, also note where it stands: how old it is, whether it's open, merged or deployed, and any related work in flight.

Then **investigate thoroughly**. Dive deep into the implementation and related code. Understand the involved features and their underlying implementation thoroughly. Make sense of abstraction layers, naming and any patterns in play. Draw on every source available: git history, project and deps documentation, your memories, the issue/PR tracker if relevant, etc.

Be extensive here: this phase is for you, not for the output. Ask me whenever the investigation needs something outside your reach (a query against a production datastore, infrastructure config, env vars, a private dashboard, missing product context, etc.), and do it before producing the output. I can run it for you. Don't substitute a guess.

Then **explain it**, in two parts.

**The context**: the part of the product the target belongs to, as it stands without the target, from the outside in:
1. **Product context.** Where the target sits in the product as a whole: the features or areas involved, the people they serve (end users (customers, ...), internal users (support, ops, ...), or developers and agents working with a tool or the codebase itself), and what those people need from them. Its centre is the user flows: the flows users go through toward their goals, with what they need before starting (knowledge, data, access, setup), what they do and with what (screens, files, commands, APIs), what each of those is for and what it acts on, what they get as a result, and what happens when something goes wrong or their case isn't covered. Schematize them if it helps. Before the flows, introduce the domain and operational background they rely on: what the surrounding systems are and do, where their inputs and configuration come from, and the concepts and terms used. Describe what things are and do, not how the code implements them.
2. **Implementation.** How it's built and how the pieces fit together, structured so it's easy to use as a walkthrough of the code.
    - Schematize the relevant section of the domain model as expressed in the code.
    - Describe the main code pieces involved (classes, modules, scripts, config, etc.), the intent of each, and how they cooperate.
    - Schematize the main code paths and data flows.

**The target itself**, grounded in that context: what it is and what it does to the picture above. For a change or a proposal, what it changes for those people and their flows, what stays, and why it's better, or where it isn't, describing the new or changed flows with the same detail as today's (what people need before starting, what they do and with what, what they get, and what happens when something goes wrong); for a bug, the expected behaviour against the actual one, where they diverge, its cause, its impact and what a fix needs to address; for a concept or process, how it works end to end, edge cases included; for an idea, what it would take, its trade-offs and how it fits.

For every mechanism, explain what it's for and how it behaves, not only what it's called. Use terms consistently and pin down what each reference means (which machine, which file, which value), so the explanation is self-contained and unambiguous. Keep facts apart from inferences.

Before writing, ask yourself the questions someone new to this would ask to understand it, and make sure the explanation answers them.

This explanation is what I read *before* looking at the target myself, so that understanding it afterwards is easy. Give me the broad picture and the map, not a line-by-line re-narration.

Keep the wording brief: brevity applies to how things are said, not to what the explanation must cover.

Prioritize accuracy. Validate everything. If something is ambiguous or you can't determine it from the available sources, say so rather than guessing.

The target is: $ARGUMENTS
