# Notes

Working notes from the rebuild, kept because the reasoning is harder to
reconstruct than the code. The config's own README is the summary; these are
the evidence behind it.

Live documents, not a snapshot. A decision can be revisited at any time; when it
is, the change and its reason are recorded here and referenced from then on.
Some sections are openly moving — the plugin list is an inventory, not a verdict.

decisions.md            what was chosen, and what was done during implementation
keymaps.md              the binding scheme, key by key, with the rationale
plugins.md              why each plugin is in or out
language-servers.md     Python, Ruby and Lua setup, including the Ruby 2.7 problem

research-keybindings.md what the ecosystem actually does — Neovim core, the
                        distros, Helix, Zed, IdeaVim, tpope, Spacemacs
research-plugins.md     churn and size measurements, built-ins that displaced
                        plugins, the netrw security finding

The two local plugins keep their own design notes beside their code, since they
are still being worked on and would travel with the plugin if it were ever
extracted: lua/mdtable/DESIGN.md and lua/mdheading/DESIGN.md. decisions.md keeps
a short summary of each and points there.

Written as notes, not prose: terse, occasionally shouty, and dated where it
matters. Anything version-specific was true of Neovim 0.12.5 when written.
