---
description: Keep this session's prompt cache warm with periodic wakeups while the user is away
---
This is a command being executed by the user. The idea is to keep this conversation's prompt cache warm by scheduling periodic wakeups, so that returning to this session after working elsewhere does not pay a full re-prefill of the conversation.

The requested duration was '$ARGUMENTS'. If empty default to **6h** and cap to **12h max**.

## Why this exists

Prompt caching is a prefix match with a sliding TTL (60min): every cache *read* refreshes the clock. A turn that reads this conversation's prefix therefore keeps it warm. While the user works in a different session, no turns land here and the cache expires — so the next real turn re-prefills the whole conversation at full price. Each wakeup fires a cheap turn purely to slide the TTL.

Once the user is back and sending messages, **their own turns are the refresh mechanism** and the chain must stop. The loop only bridges the gap.

Caveat: Each wakeup is a real billed turn reading the full conversation (roughly 0.1× its input tokens), plus a small cache write. It is far cheaper than a re-prefill, but it is not free.

## Regarding communication

**Emit no text from this command's actions beyond the brief message each section specifies.** Run the tools silently: no narration of what you are about to do, no stating the readings you get, no explaining the deadline comparison or that you are rescheduling. Every word is appended to the conversation permanently and re-read on every later turn — commentary between steps is pure waste, and doubly so on wakeups.

## On first invocation

1. Run `date` via shell to get the current wall-clock time. Do not guess or rely on the context date — you cannot observe elapsed time, so every time check must be a fresh reading.
2. Parse the requested duration (`6h`, `90m`, `2h30m`, …; default `6h`) and compute an absolute deadline. Cap it at **12h** — beyond that, a forgotten loop costs more than the prefills it avoids.
3. This command could have been used before in this session. Call `ScheduleWakeup` with `stop: true` to ensure we override any prior call.
4. Schedule the first wakeup with `ScheduleWakeup`:
   - `delaySeconds`: **60** (1 minute — TEMPORARY TEST VALUE, revert to 3000 / 50 minutes — see *About timing* below)
   - `reason`: something like `"checking the time before the deadline at <DEADLINE>"`, with the deadline filled in
   - `prompt`: exactly the sentinel described below, with the deadline filled in
5. Tell the user in one line: the deadline, the interval, and that any message from them ends the chain. Then add a second line with the break-even session count for this duration, computed as described in *About the break-even count* below.

## The wakeup prompt (sentinel)

Every wakeup must fire this exact text, with `<DEADLINE>` replaced by the absolute deadline (the format returned by `date` is good):

```
[Deadline check: <DEADLINE>]
```

The literal `[Deadline check: …]` format is how you recognize your own wakeup rather than a message from the user. Keep it verbatim and carry the deadline forward unchanged on every reschedule so it's easy to remember.

## On each wakeup

1. Run `date` via shell for a fresh reading.
2. If now is at or past the deadline, or the deadline cannot be determined: call `ScheduleWakeup` with `stop: true`, state in one line that the keep-alive expired, and do nothing else.
3. Otherwise, schedule the next wakeup with `ScheduleWakeup`:
   - `delaySeconds`: **60** (1 minute — TEMPORARY TEST VALUE, revert to 3000 / 50 minutes — see *About timing* below)
   - `reason`: same as before, something like `"checking the time before the deadline at <DEADLINE>"`, with the deadline filled in
   - `prompt`: exactly the sentinel described above, with the deadline filled in
4. Then reply with **exactly: `warming at <CURRENT_TIME>`** with the time you've just got from the `date` command filled-in. Nothing else — no summary, no restatement of the deadline, no commentary.

## Standing instruction: the user's next message ends the chain

**The moment the user sends any message of their own, the keep-alive is over.** Before answering that message, call `ScheduleWakeup` with `stop: true` to cancel any pending wakeup, and mention in one short line that the keep-alive stopped. Then answer normally.

This needs no dedicated stop command: the user is back, their own turns now keep the cache warm, and a chain that outlived their return would only disrupt the session and burn money.

**IMPORTANT:** If it is ever unclear whether a turn came from the user or from a wakeup, treat it as the user and stop — a wrongly-stopped chain costs one re-prefill the user can re-arm against, while a wrongly-continued one silently keeps spending.

## About the break-even count

How many *other* idle sessions are worth keeping warm at this duration, assuming the user returns to only one of them. Derive it from the cache multipliers rather than hardcoding a number, so the figure stays correct for any duration:

- A wakeup reads the whole conversation at the **cache-read multiplier (0.1×)** → `0.1` conversation-units each.
- Wakeups per arm ≈ `hours × 1.2` (one per 50 minutes).
- So one armed session costs ≈ `0.12 × hours` units.
- A re-prefill costs ≈ **3 units** — `1×` for the whole conversation as fresh input, plus the **1-hour-TTL cache-write multiplier (2×)** on the part that gets cached.

Break-even is `N × 0.12 × hours = 3`, i.e. **`N ≈ 25 / hours`**. Round down to a sensible whole number and present it as approximate — the `3 units` figure depends on how much of the conversation the harness marks cacheable, which is not observable.

Note that conversation size cancels out: both sides scale linearly with token count, so the same count applies to a small session and a huge one. Only the stakes differ.

Report it as one line, for example:

```
Worth keeping ~4 other sessions warm at this duration if you return to one of them — scales linearly with the number you return to (~8 for two, ~12 for three).
```

## About timing

Use a **50-minute** interval against the 1-hour TTL. Delay does not accumulate across the chain: a wakeup refreshes the TTL at the moment it fires and schedules the next one 50 minutes from that same moment, so both clocks are anchored to the same event. Every interval is independently ~50 minutes against a fresh 60-minute window.

A *single* wakeup firing more than ~10 minutes late would be an unlikely failure — a constant per-interval risk, not a growing one. The 10-minute margin covers it.
