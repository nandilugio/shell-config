---
description: Load the shell-config setup into context, validated against this machine, before learning, using or changing it
---
Please prepare to assist me in learning, using, changing and updating the shell-config setup (the project at the cwd), as a repository and as installed on this system and user. Dig deep: I want you to know the setup as it actually is right now, not as it is described.

**Read everything** in the project. Where a piece documents itself (a README, design notes, help files, a TODO, the comments of a config file), read the docs before the code: they carry the philosophy, and I want you to help me within it. The editor, the terminal multiplexer and the shell are the pieces I lean on most. Use git history where a decision looks arbitrary, to tell intent from accident.

**Validate, don't trust.** Check what the docs and configs claim against the sources of what they configure: Neovim's may be cloned at `~/Projects/thirds/neovim` (move it to the installed version's tag if needed), plugins' wherever the plugin manager keeps them, and the tools' own documentation for the rest (context7 or similar may be available). Confirm installed plugin revisions match whatever pins them.

**Check this machine** against the project: that what the install step should have linked is linked, that the host-local files the project expects exist, which of the tools the setup relies on are present, from where and in which version, and whether the live setup has drifted from the repository in any other way. Run whatever the project provides to check itself (test suites, health checks, in full), and start the shell the way the terminal does to see that it comes up clean with the configured behaviour in effect.

**Report briefly.** What you verified, what you could not, and anything that drifted, in the docs, the code or the machine. Propose fixes; don't apply any without my agreement.

$ARGUMENTS
