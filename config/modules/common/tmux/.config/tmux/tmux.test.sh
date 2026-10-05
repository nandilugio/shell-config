#!/usr/bin/env bash

# Tests for the Pref Z column maximize in tmux.conf — run directly:
#   ~/.config/tmux/tmux.test.sh [generic|setup]    (default: both)
#
# generic: layout and state cases in plain sh panes, plus the history case with
#   a clean `zsh -f`, which redraws its prompt on resize -- what loses the view
#   of a collapsed pane unless it is held in copy mode.
# setup: the history case with your own shell and config (tmux's default-shell),
#   e.g. a multi-line prompt like Pure.
#
# The real tmux.conf is driven by keypresses from a client attached inside a
# second tmux server, so the key bindings run as they do for you. Both servers
# are throwaway (-L), never the default one. Timing-based: the naps wait for
# tmux and the shells, so a busy machine can make a case flaky. Requires: tmux,
# zsh (generic), bash 3.2+.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONF="$SCRIPT_DIR/tmux.conf"
SUITES="${1:-generic setup}"

export LC_ALL=en_US.UTF-8

IN="vmaxtest-in-$$"    # server under test, running tmux.conf
OUT="vmaxtest-out-$$"  # server whose pane holds the client we type into
t() { tmux -L "$IN" -f "$CONF" "$@"; }
o() { tmux -L "$OUT" -f /dev/null "$@"; }

cleanup() {
    o kill-server 2>/dev/null; t kill-server 2>/dev/null
    rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$IN" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$OUT"
}
trap cleanup EXIT

pass=0 fail=0
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL: %s\n  panes: %s\n' "$1" "$(snap)"; }
eq() { if [ "$1" = "$2" ]; then ok; else ko "$3 (expected: '$2', got: '$1')"; fi; }

nap() { sleep "${1:-0.8}"; }

### Driving tmux #####################################################

# Shell command for new panes; empty means tmux's default-shell.
CMD=""

pane() { # <cmd args...>: run a pane-creating tmux command with $CMD
    if [ -n "$CMD" ]; then t "$@" -c / "$CMD"; else t "$@" -c /; fi
}

# start: fresh server with one pane in window 1, and a 120x40 client on it
start() {
    cleanup
    pane new-session -d -s t
    o new-session -d -x 120 -y 40 -s o "env -u TMUX TERM=xterm-256color tmux -L $IN attach -t t:1"
    local i=0
    until [ -n "$(t list-clients 2>/dev/null)" ] || [ $i -ge 50 ]; do nap 0.1; i=$((i + 1)); done
    PREFIX=$(t show -gv prefix)
}

# press <key> [pane]: select the pane, then type prefix + key into the client
press() {
    [ -n "${2:-}" ] && t select-pane -t "t:1.$2"
    nap 0.3
    o send-keys -t o "$PREFIX" "$1"
    nap 1.2
}

fill() { # <pane...>: numbered output, so a pane's view can be checked later
    local p
    for p in "$@"; do t send-keys -t "t:1.$p" "clear; seq 1 60 | sed 's/^/line /'" Enter; done
    nap 1.5
}

# [p1 | p2/p3/p4], right column with uneven heights so restoring is visible
cols() {
    pane split-window -h -t t:1.1
    pane split-window -v -t t:1.2
    pane split-window -v -t t:1.3
    t resize-pane -t t:1.2 -y 22
    t resize-pane -t t:1.3 -y 5
    nap 1.5
}

### Inspecting tmux ##################################################

paneid() { t display -p -t "t:1.$1" '#{pane_id}'; }
snap() { t list-panes -t t:1 -F '#{pane_id}:#{pane_left},#{pane_top}:#{pane_width}x#{pane_height}' 2>/dev/null | tr '\n' ' '; }
lefts() { t list-panes -t t:1 -F '#{pane_id}:#{pane_left}' | tr '\n' ' '; }
in_mode() { t list-panes -t t:1 -F '#{?pane_in_mode,#{pane_id},}' | grep . | tr '\n' ' '; }
height() { t display -p -t "t:1.$1" '#{pane_height}'; }
top_line() { t capture-pane -p -t "t:1.$1" | head -1; }

state_cleared() { eq "$(t show -w -t t:1 2>/dev/null | grep -c '^@vmax')" 0 "$1: state cleared"; }
no_modes() { eq "$(in_mode)" "" "$1: no pane left in a mode"; }

# columns_kept <lefts before> <label>: no surviving pane changed its left edge
columns_kept() {
    local before="$1" now pair
    now=" $(lefts)"
    for pair in $before; do
        case "$now" in
            *" ${pair%%:*}:"*) case "$now" in *" $pair "*) ;; *) ko "$2: ${pair%%:*} moved column"; return ;; esac ;;
        esac
    done
    ok
}

# evened <label> <pane...>: heights differ by at most 1
evened() {
    local label="$1" p h min=999 max=0; shift
    for p in "$@"; do h=$(height "$p"); [ "$h" -lt $min ] && min=$h; [ "$h" -gt $max ] && max=$h; done
    if [ $((max - min)) -le 1 ]; then ok; else ko "$label: column not evened"; fi
}

# history_visible <label> <pane...>: the view still shows output, not the prompt
history_visible() {
    local label="$1" p; shift
    for p in "$@"; do
        case "$(top_line "$p")" in line\ *) ok ;; *) ko "$label: pane $p lost its view (top: '$(top_line "$p")')" ;; esac
    done
}

### Generic: layout and state ########################################

generic_layout() {
    CMD="sh"

    echo "· toggle, restoring from the maximized pane, a collapsed one, another column"
    local from
    for from in 3 2 1; do
        start; cols
        local before; before=$(snap)
        press Z 3
        eq "$(height 2) $(height 4)" "1 1" "maximize: column collapsed"
        eq "$(in_mode)" "$(paneid 2) $(paneid 4) " "maximize: only the collapsed panes in copy mode"
        eq "$(t show -wv -t t:1 @vmax_pane)" "$(paneid 3)" "maximize: maximized pane recorded"
        press Z "$from"
        eq "$(snap)" "$before" "restore from p$from: layout back"
        no_modes "restore from p$from"; state_cleared "restore from p$from"
    done

    echo "· copy mode entered by hand is left alone"
    start; cols
    press Z 3
    t copy-mode -t t:1.3; t copy-mode -t t:1.1
    press Z 2
    eq "$(in_mode)" "$(paneid 1) $(paneid 3) " "own copy mode kept"

    echo "· Pref Z on a zoomed pane unzooms first"
    start; cols
    before=$(snap)
    t resize-pane -Z -t t:1.3
    press Z 3
    eq "$(t display -p -t t:1 '#{window_zoomed_flag}')" 0 "zoomed: unzoomed"
    eq "$(in_mode)" "$(paneid 2) $(paneid 4) " "zoomed: other column not in copy mode"
    press Z
    eq "$(snap)" "$before" "zoomed: layout back"

    echo "· rows first: [p1 | p2] over a full-width p3"
    start
    pane split-window -v -t t:1.1; pane split-window -h -t t:1.1; nap 1.5
    before=$(snap)
    press Z 2
    eq "$(in_mode)" "$(paneid 3) " "rows: full-width pane below in copy mode"
    press Z
    eq "$(snap)" "$before" "rows: layout back"; no_modes "rows"

    echo "· side-by-side split in the column: p2 over [p3 | p4]"
    start
    pane split-window -h -t t:1.1; pane split-window -v -t t:1.2; pane split-window -h -t t:1.3; nap 1.5
    before=$(snap)
    press Z 2
    eq "$(in_mode)" "$(paneid 3) $(paneid 4) " "side-by-side: both in copy mode"
    press Z
    eq "$(snap)" "$before" "side-by-side: layout back"; no_modes "side-by-side"

    echo "· three columns: [p1 | p2/p3 | p4/p5/p6]"
    start
    pane split-window -h -t t:1.1; pane split-window -h -t t:1.2; t select-layout -t t:1 even-horizontal
    pane split-window -v -t t:1.2; pane split-window -v -t t:1.4; pane split-window -v -t t:1.5; nap 1.5
    before=$(snap)
    press Z 5
    eq "$(in_mode)" "$(paneid 4) $(paneid 6) " "three columns: only its column in copy mode"
    press Z
    eq "$(snap)" "$before" "three columns: layout back"; no_modes "three columns"
}

### Generic: changes while maximized #################################

generic_changes() {
    CMD="sh"
    local before

    echo "· split in another column, restore from it"
    start; cols; before=$(lefts)
    press Z 3
    pane split-window -v -t t:1.1; nap
    press Z 1
    columns_kept "$before" "split other"; evened "split other" 3 4 5; no_modes "split other"; state_cleared "split other"

    echo "· split one column and kill in another (same pane count)"
    start; cols; pane split-window -v -t t:1.1; nap; before=$(lefts)
    press Z 4
    pane split-window -v -t t:1.4; t kill-pane -t t:1.2; nap
    press Z
    columns_kept "$before" "split+kill"; no_modes "split+kill"; state_cleared "split+kill"

    echo "· kill in another column"
    start; cols; pane split-window -v -t t:1.1; nap; before=$(lefts)
    press Z 4
    t kill-pane -t t:1.2; nap
    press Z
    columns_kept "$before" "kill other"; evened "kill other" 2 3 4; no_modes "kill other"; state_cleared "kill other"

    echo "· swap the maximized pane"
    start; cols; before=$(lefts)
    press Z 3
    t swap-pane -s t:1.3 -t t:1.2; nap
    press Z
    no_modes "swap"; state_cleared "swap"; evened "swap" 2 3 4

    echo "· kill the maximized pane, press from another column"
    start; cols
    press Z 3
    t kill-pane -t t:1.3; nap
    press Z 1
    no_modes "kill maximized (no error shown)"; state_cleared "kill maximized"

    echo "· terminal resized while maximized"
    start; cols
    press Z 3
    o resize-window -t o -x 100 -y 30; nap 1.5
    press Z
    no_modes "terminal resize"; state_cleared "terminal resize"
    [ "$(height 3)" -gt 1 ] && [ "$(height 4)" -gt 1 ] && ok || ko "terminal resize: column still collapsed"
}

### History of collapsed panes #######################################

# history <label>: p2 and p4 collapse around p3, and must come back showing
# their output. The first check does the same collapse without Pref Z, to see
# whether the shell loses the view at all: if it doesn't (say a future tmux
# keeps it), the copy mode workaround may no longer be needed.
history() {
    local label="$1"
    start; cols; fill 2 4
    local h; h=$(height 4)
    t resize-pane -t t:1.4 -y 1; nap; t resize-pane -t t:1.4 -y "$h"; nap
    case "$(top_line 4)" in
        line\ *) echo "  NOTE: $label keeps its view even without copy mode" ;;
    esac

    start; cols; fill 2 4
    press Z 3
    press Z
    history_visible "$label" 2 4
}

generic_history() {
    echo "· history with a clean zsh"
    CMD="env PS1='> ' zsh -f"
    history "zsh -f"
}

setup_history() {
    echo "· history with your shell ($SHELL)"
    CMD=""
    history "your shell"
}

### Run ##############################################################

for suite in $SUITES; do
    case "$suite" in
        generic) echo "## generic"; generic_layout; generic_changes; generic_history ;;
        setup)   echo "## setup";   setup_history ;;
        *) echo "unknown suite: $suite (generic|setup)" >&2; exit 2 ;;
    esac
done

printf '%d passed, %d failed (%s, suites: %s)\n' "$pass" "$fail" "$(tmux -V)" "$SUITES"
[ "$fail" -eq 0 ]
