# shell-config

My dotfiles, deployable to different machines and users with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

```
config/                   everything deployable
├── modules/<group>/<m>   one Stow package per tool, mirroring $HOME
│   ├── common/           agents claude opencode git zsh nvim vim tmux ghostty ruff psql ruby lazygit
│   │                     bin (portable scripts)  bin-host (docker, tmux: needs the host)
│   ├── macos/            aerospace  bin (keychain, macOS apps)
│   └── linux/            i3
├── targets/              macos  linux  aiws: one <group>/<module> per line
└── install               install [-D] <target>
extras/macos/             app settings copied by hand (see below)
```

`install <target>` links the target's modules into `$HOME` (`-D` unlinks). It dry-runs first, so a conflict changes nothing, and keeps `~/bin`, `~/.config`, `~/.claude`, `~/.config/opencode` and `~/.config/lazygit` real directories: tools write state there that must stay out of the repo.

Targets:
- `macos`, `linux`: a full workstation.
- `aiws`: a [priviledge](https://github.com/nandilugio/priviledge) guest. No host tools, terminal or desktop config. The guest mounts `config/` read-only at the same path and runs `install aiws` once.

## Setup

```sh
git clone git@github.com:nandilugio/shell-config.git ~/.shell-config
~/.shell-config/config/install macos          # or linux; needs stow (brew/apt install stow)
cp ~/.shell-config/config/modules/common/git/.gitconfig_host.example ~/.gitconfig_host
$EDITOR ~/.gitconfig_host                     # name; git refuses to commit without it
echo 'source ~/.shell-start.zsh' >> ~/.zprofile
```

Not in the repo, installed per machine: zsh with [prezto](https://github.com/sorin-ionescu/prezto) (`~/.zshrc`), Homebrew, nvim, tmux, lazygit. `.shell-start.zsh` puts every tool that may be missing behind a check, so it also works where those aren't installed.

Host-local files, never committed: `~/.gitconfig_host` (identity; `g profile-pers` and `g profile-work` set a repo's email), `~/.zshrc`, `~/.zprofile`.

Third-party checkouts go in `~/Projects/thirds/`, optional and skipped if missing:

```sh
git clone https://github.com/tmux-plugins/tmux-resurrect ~/Projects/thirds/tmux-resurrect
git clone https://github.com/Morantron/tmux-fingers ~/Projects/thirds/tmux-fingers
# docker-vackup, for bin-host's vackup wrapper
```

## Notes

**tmux.** Config is `~/.config/tmux/tmux.conf`; don't also keep a `~/.tmux.conf` (tmux 3.1+ loads both). Resurrect saves with `prefix C-s`, restores with `prefix C-r`, and puts each pane's `claude --resume <id>` back (typed, not run; see `n.tmux-claude-sessions-*`). Saves include pane contents, so: `mkdir -p ~/.local/share/tmux/resurrect && chmod 700 ~/.local/share/tmux/resurrect`. Don't start session names with `%` (tmux's pane-id sigil): resurrect then restores only the first pane of each window.

**Ghostty** opens every window into the `main` tmux session (`n.tmux-new-terminal-window`).

**Claude Code.** `AGENTS.md` is shared by Claude (`~/.claude/CLAUDE.md`) and opencode. The statusline needs a `statusLine` entry in `~/.claude/settings.json` (see the script's header). Claude Code resolves `~/.claude/CLAUDE.md` and `commands` at session start and removes them if their targets move while a session runs: relink with no session open.

**lazygit** reads `~/.config/lazygit/config.yml` everywhere (`LG_CONFIG_FILE`, set in `.shell-start.zsh`), instead of macOS's `~/Library/Application Support`.

## macOS

```sh
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false   # key repeat instead of accents
defaults write com.apple.Finder AppleShowAllFiles true && killall Finder
```

- System Settings > Keyboard > Keyboard Shortcuts > Input Sources: unbind Ctrl+Space (nvim's completion docs).
- SSH keys in the keychain: [how](https://apple.stackexchange.com/questions/48502/how-can-i-permanently-add-my-ssh-private-key-to-keychain-so-it-is-automatically).
- Keys, with aerospace (or i3 on Linux): on PC keyboards swap Cmd and Opt, and remap Spotlight to the key now in Cmd's place. Intent: Meta for tmux, Meta+Cmd for the window manager, Ctrl and Cmd as usual. See [tmux modifier keys](https://github.com/tmux/tmux/wiki/Modifier-Keys).
- `extras/macos/app-exportable/`: settings imported from within each app. `extras/macos/plists/`: UserDefaults, imported with `defaults import` (see its README).

## Linux (GNOME)

```sh
gsettings set org.gnome.shell.app-switcher current-workspace-only true
```
