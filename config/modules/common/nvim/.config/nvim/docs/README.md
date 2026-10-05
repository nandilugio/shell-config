# Notes

Why the config is the way it is, kept because the reasoning is harder to
reconstruct than the code. The config's own README is the summary; these are the
evidence behind it.

Live documents. A decision can be revisited at any time; when it is, the change
and its reason are recorded here and referenced from then on. Some sections are
openly moving — the plugin list is an inventory, not a verdict.

    decisions.md             what was chosen, and what was done implementing it
    keymaps.md               the binding scheme, key by key
    language-servers.md      Python, Ruby and Lua, including the Ruby 2.7 problem

    research-keybindings.md  what the ecosystem does — Neovim core, the distros,
                             Helix, Zed, IdeaVim, tpope, Spacemacs; and the git
                             history bindings, where nothing is standard
    research-plugins.md      churn and size measurements, built-ins that
                             displaced plugins, the netrw security finding

The local plugins keep their design notes beside their code, since they are
still being worked on and would travel with the plugin if extracted:
`lua/mdtable/DESIGN.md` and `lua/mdheading/DESIGN.md`. `decisions.md` summarises
each and points there.

Notes, not prose: terse, occasionally shouty, dated where it matters. Anything
version-specific was true of Neovim 0.12.5 when written.
