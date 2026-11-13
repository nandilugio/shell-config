---
description: Review a change in rounds, fixing what it got wrong, until a round comes back clean
---
Let's run a review cycle on the target change referenced below: repeated review rounds, each followed by verified fixes, until a round finds nothing worth fixing. The aim is a set of changes that is correct and makes sense as a whole, not a pile of patches. The fixes stay uncommitted for the whole cycle: at the end you offer them to me with the report, and they get committed only once I've approved them.

**Phase 1 — Understand.** Resolve the target to something concrete: the branch or PR, its base, its commits, any branches stacked on it. Read the change and its commit messages fully. Then build the context a reviewer needs: the features involved and where they sit in the product, how they're implemented, and the main code paths and data flows the change touches. Draw on every source available: git history, project and dependency docs, your memories, the issue or PR tracker.

**Phase 2 — Prepare.**
- The cycle's fixes must be the only uncommitted changes in the checkout you work in: they're what I review at the end and what gets committed. If the target is the branch I have checked out and the working tree isn't clean, stop and ask me what the changes are before touching anything.
- If the target isn't the branch I have checked out, work without disturbing my checkout, for example in a separate worktree, if you can get its dependencies and environment working there so the tests run. If that becomes cumbersome, ask me how to proceed.
- Make the relevant tests runnable locally first. If some always fail for environment reasons (missing credentials, services), find out why: a harmless local setting may be enough, or a small test fix worth its own commit. Otherwise skip them for the duration of the cycle (marking them skipped in the test files is fine), and undo that before anything is committed. Then run the tests the change touches, to get a baseline.
- Keep a log on disk: each round's findings, your verdict on each, the decisions taken, and the list of decided items. It carries the state from round to round, including across a compaction of your context, and the outputs at the end come from it. Put it where it survives the session and can't end up in a commit: outside the repository, or ignored by it. If a ledger is already being kept for this work, use that.

**Phase 3 — Rounds.** Each round:
1. **Review.** Get a review that isn't anchored on yours: the built-in code review, a reviewer agent, a different model, whatever is available. Brief it with the target (the uncommitted fixes included), the focus, the filter below, and the decided items, each with its reason, so they don't come back. When the reviewer is the built-in code review, give it the effort stated below; if none was stated, don't pass one, so it keeps the level last used.
   - Up to round 3, rounds look at the whole target. Round 1 uses these axes as a checklist: does it meet its objective, without scope creep; is it correct (bugs, edge cases, error handling, concurrency, ordering and failure modes, backward compatibility, migrations and data integrity); is the design right; is it well executed. Later broad rounds can use a different reviewer or model, and can point it at the riskiest paths.
   - From round 4, rounds get expensive and returns drop: point the reviewer at the last round's changes and what they touch, regressions first. If a round's fixes were large or changed the design, the next round goes broad again.
2. **Filter.** Every round, only issues the target (or its fixes) introduces are fixed. A pre-existing issue is fixed only if the target makes it significantly worse. As rounds go, tighten what's reported at all: drop nits first, then style, duplication, efficiency and convention findings, unless I ask for them.
3. **Verify every finding yourself, deeply, before acting.** Reviewers state wrong things with full confidence. Dig into the code and everything around it: trace the callers, read the history, check the data, run a probe if that settles it. Be thorough and validate everything. Ask me whenever verifying needs something outside your reach (a production query, infrastructure config, a private dashboard); don't substitute a guess. Then classify the finding:
   - **introduced by the target or a fix**: fix it;
   - **pre-existing**, not made significantly worse: follow-up;
   - **by design, or already decided**: decline, with the reason;
   - **a product or behaviour decision**: ask me, with the options and a recommendation, and leave the item unfixed until I answer; the rest of the round goes on;
   - **rare or of low value**: decline or follow-up, saying which and why.
4. **Fix** each issue as simply as is correct, in the working tree, without committing. Decide how to prove each fix. Often a test that fails without it is best, when it's worth its cost; check that it does fail (put the original code back temporarily rather than assuming). Sometimes a probe, a manual check or reasoning is the better proof; say which you used. Run the affected tests and linters after each round.
5. **Record** the round in the log, and update the decided items for the next brief.

**Watch for patches on patches.** If a fix draws new findings round after round in the same area, stop patching. Step back, reconsider the approach (a simpler rule or a product decision often removes the problem), and bring me the options before going further.

**Stop** when a round finds nothing that meets the bar. A small change after that clean round that doesn't alter behaviour (a log line, a report) doesn't need another round. Don't chase diminishing returns.

**Phase 4 — Report and offer the fixes.** Nothing is committed yet. Give me, briefly and ranked most to least important:
- What each round found, tagged **[blocking]**, **[worth fixing]** or **[nit]**, and what was fixed, declined (and why), or asked.
- The fixes themselves: the uncommitted diff, with a line per fix saying which commit it belongs to.
- **Follow-ups**: the valuable changes the cycle deliberately left out (pre-existing issues, rare cases, cleanups), each with its size, risk and value, so they can be prioritized.
- **A note for the PR**: a few lines on what was intentionally left untouched (pre-existing behaviour, decided trade-offs) and why, so reviewers don't rediscover it. Keep it short.
- Updated drafts of the PR description and of any review replies the fixes affect.
- **A commit plan** for what looks most plausible, with what it rests on (whether the commits are on a remote, whether there's a PR and whether it has reviews): which commits the fixes are folded into and the messages that change, or the new commits on top, grouped, with their messages.

Then wait for my OK on the plan, or my correction, in which case restate the plan before acting. Only that OK starts Phase 5. An adjustment that changes behaviour gets its own verification, and another round if it was large.

**Phase 5 — Commit**, carrying out the agreed plan:
- **Folding the fixes in.** Rewrite history once:
  - freeze the final state, staging files explicitly;
  - put each fix in the commit that introduced the code it fixes (fixup commits followed by a non-interactive autosquash rebase is usually the simplest route);
  - update any commit message whose claims the fixes changed;
  - keep authors and dates;
  - check that the rebuilt history ends in exactly the frozen state, with no stray files, that the tests the cycle touched pass at every rewritten commit, and that the relevant suite passes at the tip.
- **Adding them on top.** Add the fixes as new commits on top, grouped so each reads as one change with its reason, and leave existing commits alone.
- **Stacked branches.** Put each fix in the branch where its code originates, then bring the dependent branches up to date, and check their own changes came through unchanged.
- Don't push, post or publish anything without my OK. When I give it for a rewritten branch, pin the force-push to the remote state you expect to replace.

Prioritize accuracy over speed. If something is ambiguous or can't be determined from the sources available, say so rather than guessing.

The target, the effort for the built-in code review, the focus and any further instructions: $ARGUMENTS
