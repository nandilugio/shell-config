---
description: Stabilize a change for production in rounds of the built-in code-review, fixing what it got wrong, until a round comes back clean
argument-hint: "[PR# | branch | last N commits] [effort] [further instructions]"
---
Let's run a review cycle on the target change referenced below: repeated rounds of the built-in code review (`/code-review`), each followed by verified fixes, until a round finds nothing worth fixing. The aim is to stabilize the change and make it ready for production: a set of changes that is correct and makes sense as a whole, not a pile of patches.

The cycle only corrects what the target got wrong. No new features, enhancements or refactors originate in it: anything beyond the target's intent becomes a follow-up.

Each round's fixes go into a temporary local round commit, so the next review can target them. When the rounds are done, the round commits are reset away and all the fixes stay as uncommitted changes, which you offer me with the report. Nothing is pushed, and nothing is committed for good until I've approved it.

**The target** is one of:
- a PR number or a branch: the whole change, from its merge-base with its base branch;
- the last N commits of a branch: those commits only;
- nothing: the branch I have checked out and its PR, if they're mine.

If it's ambiguous, or the branch isn't mine, ask me.

**Phase 1: Understand.** Resolve the target to something concrete: the branch and its PR if there is one, its base, its commits, any branches stacked on it. Record its starting point as a commit SHA, `<start>`: the merge-base with the base branch for a whole branch or PR, or the parent of the oldest commit for the last N commits. Broad reviews and the final rewrite use that SHA, so they don't drift as round commits pile up or the base branch moves. Also record the last original commit, `<last>`, so the fixes can be told apart from the change.

Then make sure you understand the change well enough to judge findings, verify them and, above all, fix them well: the part of the product it touches, who uses it and the flows it changes, and how it's built. When the cycle runs in the conversation where the change was developed, reviewed or explained, that context is usually already here; make sure you're up-to-date, then fill only the gaps, from the code, git history, project and dependency docs, your memories and the issue or PR tracker.

**Phase 2: Prepare.**
- Work on a checkout of the target's branch whose working tree holds nothing but the cycle's own work. If the target is the branch I have checked out and the working tree isn't clean, stop and ask me what the changes are before touching anything.
- If the target isn't the branch I have checked out, work without disturbing my checkout, for example in a separate worktree, if you can get its dependencies and environment working there so the tests run. If that becomes cumbersome, ask me how to proceed. Tell me up front where you're working: my checkout, or a worktree with its path and branch, so I know whether my checkout stays free for other work.
- Make the relevant tests runnable locally first. If some always fail for environment reasons (missing credentials, services), find out why: a harmless local setting may be enough, or a small test fix worth its own commit, which goes into the commit plan. Otherwise skip them for the duration of the cycle (marking them skipped in the test files is fine), keep that out of the round commits, and undo it before Phase 5. Then run the tests the change touches, to get a baseline.
- Keep a log on disk: each round's scope, findings, your verdict on each, the fixes and whether they were big or small, the decisions taken, and the list of decided items. It carries the state from round to round, including across a compaction of your context, and the outputs at the end come from it. Put it where it survives the session and can't end up in a commit: outside the repository, or ignored by it. If a ledger is already being kept for this work, use that.

**Phase 3: Rounds.** At most 10. Each round:
1. **Review.** Run `/code-review` with the round's target and the effort given in the arguments; if none was given, don't pass one, so it keeps the level last used. The effort stays the same for the whole cycle. Never pass `--comment` or `--fix`. It takes no brief: all focusing comes from its target and from the filter. It runs in the background, so wait for its findings, and check what it actually reviewed.
   - **Broad rounds** review the whole target with all its fixes: target `<start>..HEAD`.
   - **Narrow rounds** review only the last round's fixes: target `HEAD~1..HEAD`.
   - The first 3 rounds are broad. After that, rounds are narrow, except that a round whose fixes were big makes the following rounds broad again, until 2 rounds in a row bring only small fixes. Fixes are small when they're local and don't change behaviour or design beyond the issue they fix. Only the fixes actually made count: declined, deferred or already decided findings don't, however big.
2. **Filter.** The same rules every round:
   - Only issues the target or its fixes introduce are fixed. A pre-existing issue is fixed only if the target makes it significantly worse.
   - A finding meets the bar when it shows the target falls short on one of these: does it meet its objective, without scope creep; does it work for the people who use it (usability, operability, documentation for humans and agents); is it correct (bugs, edge cases, error handling, concurrency, ordering and failure modes, backward compatibility, migrations and data integrity, security: secrets, permissions, exposure of data or access); is the design right; is it well executed.
   - Decided items don't come back.
   - Broad rounds act on everything that meets the bar. Narrow rounds act only on correctness, regressions and anything **[worth fixing]** or above; nits, style, duplication, efficiency and convention findings go to the report instead, unless I ask for them.
3. **Verify every finding yourself, deeply, before acting.** Reviewers state wrong things with full confidence. Dig into the code and everything around it: trace the callers, read the history, check the data, run a probe if that settles it. Be thorough and validate everything. Ask me whenever verifying needs something outside your reach (a production query, infrastructure config, a private dashboard); don't substitute a guess. Then classify the finding:
   - **introduced by the target or a fix**: fix it;
   - **pre-existing**, not made significantly worse: follow-up;
   - **beyond the target's intent** (new behaviour, an enhancement, a refactor): follow-up, never fixed here;
   - **by design, or already decided**: decline, with the reason;
   - **a product or behaviour decision**: ask me, with the options and a recommendation, and leave the item unfixed until I answer; the rest of the round goes on;
   - **rare or of low value**: decline or follow-up, saying which and why.
4. **Fix** each issue as simply as is correct, within the target's intent. Decide how to prove each fix. Often a test that fails without it is best, when it's worth its cost; check that it does fail (put the original code back temporarily rather than assuming). Sometimes a probe, a manual check or reasoning is the better proof; say which you used. Run the affected tests and linters after each round.
5. **Commit and record.** Commit the round's fixes as one temporary local round commit (`cycle round N`), staging files explicitly: never the log or skipped tests. Don't push it. A round without fixes makes no commit. Record the round in the log, including whether its fixes were big or small, and update the decided items.

**Watch for patches on patches.** If a fix draws new findings round after round in the same area, stop patching. Step back, reconsider the approach (a simpler rule or a product decision often removes the problem), and bring me the options before going further.

**Stop** at the first round from the third on that finds nothing meeting the bar; the first 3 rounds always run, because two runs of the same review find different things. If round 10 still finds issues, stop anyway and report what's open. A small change after the clean round that doesn't alter behaviour (a log line, a report) doesn't need another round. Don't chase diminishing returns.

**Phase 4: Report and offer the fixes.** First reset the round commits away with `git reset <last>`, so all the fixes are uncommitted changes in the checkout you worked in. Then give me, briefly:
- **The cycle** in one line: how many rounds ran, broad or narrow, and why it stopped.
- **The issues**, as finally understood: one list, ranked most to least important, that merges what the rounds reported, since separate findings can turn out to be one issue and fixes can reshape them. Each tagged **[blocking]**, **[worth fixing]** or **[nit]**, with what it was and how it ended: fixed (how, how it's proven, and which original commit the fix belongs to), declined (why), deferred, or waiting on me. Leave out issues that only the cycle's own fixes introduced and then corrected, unless they tell me something.
- **Where the fixes are**: my checkout, or the worktree with its path.
- **Follow-ups**: the valuable changes the cycle deliberately left out (pre-existing issues, anything beyond the target's intent, rare cases, cleanups, findings narrow rounds didn't act on), each with its size, risk and value, so they can be prioritized.
- **A note for the PR**: a few lines on what was intentionally left untouched (pre-existing behaviour, decided trade-offs) and why, so reviewers don't rediscover it. Keep it short.
- Updated drafts of the PR description and of any review replies the fixes affect.
- **A commit plan** for what looks most plausible, with what it rests on (whether the commits are on a remote, whether there's a PR and whether it has reviews), precise enough that applying it is mechanical:
  - the route: fold the fixes into the commits they correct (as fixups, autosquashed from `<start>` with a non-interactive rebase, keeping authors and dates), or add them as new commits on top, grouped so each reads as one change with its reason;
  - per commit, which fixes go into it, and its message: new, or updated where the fixes changed its claims;
  - with stacked branches, which branch each fix goes to (the one where its code originates), and how the dependent branches are brought up to date;
  - any test fix from Phase 2, as its own commit;
  - if you worked in a worktree, removing it once everything is committed.

Then wait for my OK on the plan, or my correction, in which case restate the plan before acting. Only that OK starts Phase 5. An adjustment that changes behaviour gets its own verification, and another round if it was large.

**Phase 5: Commit.** Apply the approved plan, as corrected if I corrected it. Whatever the plan, these hold:
- **Before:** restore any tests skipped for the cycle, and note the approved tree: the fixes as I reviewed them, plus any agreed adjustment. Stage files explicitly; nothing else gets in, and the log stays out.
- **After:** check that the result ends in exactly the approved tree, with no stray files, and that the relevant suite passes at the tip. After a history rewrite, also check that the tests the cycle touched pass at every rewritten commit, and that stacked branches' own changes came through unchanged.
- Don't push, post or publish anything without my OK. When I give it for a rewritten branch, pin the force-push to the remote state you expect to replace.

Prioritize accuracy over speed. If something is ambiguous or can't be determined from the sources available, say so rather than guessing.

The target, the effort for the built-in code review, and any further instructions: $ARGUMENTS
