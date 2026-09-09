---
description: Summarize work done from session transcripts, defaulting to today
---
Let's reconstruct and summarize the work done in past Claude Code sessions, reading them from the local session transcripts.

The transcripts live in `~/.claude/projects/<encoded-project-path>/<session-uuid>.jsonl`. Each directory is one project (its path with `/` replaced by `-`), each file one session, each line one JSON record. Records have a `type` (`user`, `assistant`, …), a `message` with the content, and an ISO 8601 UTC `timestamp`.

**Scope.** Default to today. The argument may narrow it by time range (a date, a range, "yesterday", "this week") and/or by project, matched loosely against the encoded directory names. Interpret it sensibly and state the scope you settled on. A session can span days, so select by message timestamp rather than file mtime.

**Timestamps.** Stored times are UTC. Convert to my local timezone before showing any time, and sanity-check against any local time mentioned in the messages themselves.

**Method.** Transcripts are large — some run to tens of megabytes — so never read them into context wholesale. Write a script (in the scratchpad) that walks the files and extracts only what you need, and iterate on it. Start with my own prompts: they carry the intent and are a small fraction of the bytes. Skip system reminders, command scaffolding, tool results, and interrupted turns. Then go back for the specific assistant turns that settle how each thread ended — was the bug fixed, did the PR land, how did a discussion resolve.

Be thorough here: the brevity the output calls for governs what you write, never what you read. A thread often changes direction late — a first diagnosis overturned, a conclusion reversed on pushback, an approach abandoned — and the prompts alone will not show it. Read far enough to see each thread's final state, and report that state rather than the path to it. Where you cannot tell which version stuck, say so.

**Output.** An executive summary: what I'd want to know with thirty seconds and no memory of the work. Well under a page. Two parts, in this order.

*First, a time breakdown.* One block per day in scope, no heading above it, each line a strand of work with estimated hours and a few comma-separated subjects:

```
Monday Sep 7:
  2h: phase 0: narrowed scope, reviewed current implementation
  4h: phase 1: lucas feedback, form layout troubleshooting, 2% drift source re-check, copy summary for albert
  2h: dev env: _nando/bin/start overhaul, /n-work-summary creation
```

Follow that shape, not its content. Keep the lines coarse — a handful per day, never one per activity. Group by the strand I would name in conversation, and fold its detours into it: unblocking an environment, chasing a side bug, or answering a question in service of a strand belongs on that strand's line, named among its subjects. Only work I would call a thing of its own gets its own line. Estimate hours from elapsed time between the first and last message of a stretch, not from how much was accomplished or how much text a thread generated; don't bill long idle gaps. Round honestly — half hours are fine — and don't force a tidy total.

*Then the prose.* One short paragraph per substantial thread, a few sentences at most: the goal, what happened, where it ended. Order the paragraphs loosely chronologically, following how the work actually unfolded; where a thread spans sessions or is interrupted and resumed, keep it whole and place it where its centre of gravity sits. Note decisions and any process or preference changes briefly — they are the parts worth remembering. Close with a short list of one-liners for anything that genuinely stands alone and still matters tomorrow; it is fine for that list to be empty.

Attribute the small moments to the work they came from. A passing question — a word choice, a bit of syntax, which tool does X — is usually part of whatever I was in the middle of, and belongs in that thread's paragraph or, more often, nowhere at all. Ask what it was in service of before giving it a line of its own.

Be ruthless about what earns space. Name the specifics that identify a thing (branch, PR, ticket, file, the error itself) and cut the rest: no commit SHAs, no spec counts, no measurements, no recounting of how a conclusion was reached or what was tried first. A wrong turn is worth a clause only if it changed the outcome or is still open. Assume I was there — this is a reminder, not a report for someone who wasn't.

Report what the transcripts actually show. If a thread's outcome isn't recorded, say it's unclear rather than inferring a tidy ending.

Scope: $ARGUMENTS
