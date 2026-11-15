#!/usr/bin/env bash

# Tests for claude-statusline.sh — run directly:
#   ~/.shell-config/config/modules/common/claude/.claude/claude-statusline.test.sh
# The statusline is invoked with STATUSLINE_BASH (default /bin/bash, i.e.
# macOS system bash 3.2 — the oldest supported target).
#
# Determinism: the statusline runs with HOME pointing into a temp dir, so
# tilde collapse and width arithmetic don't depend on the real machine.
# Git fixtures live under that fake home too, keeping their display paths
# short and stable. Requires: bash 3.2+, jq, git (same as the script).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SL="$SCRIPT_DIR/claude-statusline.sh"
SL_BASH="${STATUSLINE_BASH:-/bin/bash}"

# The … and ⇡⇣ glyphs must count as 1 char in ${#}; force a UTF-8 locale.
export LC_ALL=en_US.UTF-8

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
H="$TMP/h"   # fake HOME
mkdir -p "$H"

# Fake tmux, put first on PATH by the pane-width cases: answers pane %1's
# width with $FAKE_PANE_WIDTH, fails for anything else.
mkdir -p "$TMP/bin"
cat >"$TMP/bin/tmux" <<'EOF'
#!/bin/sh
[ "$*" = "display -p -t %1 #{pane_width}" ] && [ -n "${FAKE_PANE_WIDTH:-}" ] || exit 1
echo "$FAKE_PANE_WIDTH"
EOF
chmod +x "$TMP/bin/tmux"

pass=0 fail=0
ESC=$(printf '\033')
DARK_GRAY="${ESC}[90m"
CYAN="${ESC}[36m"
YELLOW="${ESC}[33m"
PURE_GIT_DIRTY="${ESC}[38;5;218m"
HEAT_GRAY="${ESC}[38;5;242m"
HEAT_YELLOW="${ESC}[38;5;178m"
HEAT_ORANGE="${ESC}[38;5;208m"
HEAT_RED="${ESC}[38;5;160m"
RESET_ESC="${ESC}[0m"

# render <json> [env VAR=VAL ...] -> sets RAW, PLAIN, WIDTH
# Width is pinned to 80 so the ladder assertions are stable regardless of the
# script's own default; a case can still override it via a trailing env arg.
render() {
    local json="$1"; shift
    RAW=$(printf '%s' "$json" | env HOME="$H" CLAUDE_MAX_STATUSLINE_WIDTH=80 "$@" "$SL_BASH" "$SL")
    PLAIN=$(printf '%s' "$RAW" | sed "s/${ESC}\[[0-9;]*m//g")
    WIDTH=${#PLAIN}
}

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL: %s\n  plain: %s (width %s)\n' "$1" "$PLAIN" "$WIDTH"; }

has()      { case "$PLAIN" in *"$1"*) ok ;; *) ko "expected '$1' — $2" ;; esac; }
hasnt()    { case "$PLAIN" in *"$1"*) ko "unexpected '$1' — $2" ;; *) ok ;; esac; }
raw_has()  { case "$RAW" in *"$1"*) ok ;; *) ko "raw color/text missing — $2" ;; esac; }
plain_is() { if [ "$PLAIN" = "$1" ]; then ok; else ko "$2 (expected: $1)"; fi; }
width_le() { if [ "$WIDTH" -le "$1" ]; then ok; else ko "width ${WIDTH} > $1 — $2"; fi; }
width_gt() { if [ "$WIDTH" -gt "$1" ]; then ok; else ko "width ${WIDTH} <= $1 — $2"; fi; }

# mk <dir> <model|-> <effort|-> <c|-> <h|-> <w|-> [vim]
mk() {
    local json="{\"workspace\":{\"current_dir\":\"$1\"}"
    [ "$2" != "-" ] && json="$json,\"model\":{\"display_name\":\"$2\"}"
    [ "$3" != "-" ] && json="$json,\"effort\":{\"level\":\"$3\"}"
    [ "$4" != "-" ] && json="$json,\"context_window\":{\"used_percentage\":$4}"
    if [ "$5" != "-" ] || [ "$6" != "-" ]; then
        local rl=""
        [ "$5" != "-" ] && rl="\"five_hour\":{\"used_percentage\":$5}"
        [ "$6" != "-" ] && rl="$rl${rl:+,}\"seven_day\":{\"used_percentage\":$6}"
        json="$json,\"rate_limits\":{$rl}"
    fi
    [ "${7:-}" ] && json="$json,\"vim\":{\"mode\":\"$7\"}"
    printf '%s}' "$json"
}

OPUS="Opus 4.8 (1M context)"
X33=$(printf 'x%.0s' {1..33})   # padding elements of exact lengths
X55=$(printf 'x%.0s' {1..55})
X60=$(printf 'x%.0s' {1..60})
X90=$(printf 'x%.0s' {1..90})

### Basics: parsing, tilde collapse, roomy line, vim ################

render "$(mk "$H/dev" "$OPUS" high 34 62 91)"
plain_is '[~/dev|Opus 4.8 (1M context)|hi|c34%|h62%|w91%]' "roomy line, everything shown"
raw_has "${CYAN}Opus" "model cyan"
raw_has "${HEAT_YELLOW}hi" "effort high yellow, 2 chars"
raw_has "${HEAT_RED}w91%" "w91 red"
raw_has "${HEAT_GRAY}c34%" "c34 gray"
raw_has "${HEAT_YELLOW}h62%" "h62 yellow"

render "$(mk "$H" "Fable 5" - - - -)"
plain_is '[~|Fable 5]' "HOME itself collapses to ~; absent fields omitted"

render "$(mk "/tmp/zz" - - - - -)"
plain_is '[/tmp/zz|Claude]' "non-home path literal; model falls back to Claude"

render "$(mk "$H/zz" "Fable 5" high 0 0 0)"
plain_is '[~/zz|Fable 5|hi|c0%|h0%|w0%]' "zeros are values, not absences"

render "$(mk "$H/dev" "$OPUS" high 34 62 91 INSERT)"
plain_is 'INSERT  [~/dev|Opus 4.8 (1M context)|hi|c34%|h62%|w91%]' "vim prefix outside brackets"
raw_has "${ESC}[1m${DARK_GRAY}INSERT" "vim mode bold, in the bracket gray"

### Percentages: bands, truncation, guards ##########################

render "$(mk "$H/dev" "Fable 5" - 49 50 69)"
raw_has "${HEAT_GRAY}c49%" "49 gray"
raw_has "${HEAT_YELLOW}h50%" "50 yellow"
raw_has "${HEAT_YELLOW}w69%" "69 yellow"

render "$(mk "$H/dev" "Fable 5" - 70 89 90)"
raw_has "${HEAT_ORANGE}c70%" "70 orange"
raw_has "${HEAT_ORANGE}h89%" "89 orange"
raw_has "${HEAT_RED}w90%" "90 red"

render "$(mk "$H/dev" "Fable 5" - 6.7 - -)"
has "c6%" "decimals truncated"

render "$(mk "$H/dev" "Fable 5" - '"abc"' - -)"
plain_is '[~/dev|Fable 5]' "non-numeric percentage skipped"

### Reset times on hot h/w windows ##################################
# Epoch 1700000000 under TZ=UTC is 22:13 on a Tuesday; pinning TZ keeps the
# formatted time/weekday deterministic across machines.
RL_RESET='"five_hour":{"used_percentage":%s,"resets_at":1700000000},"seven_day":{"used_percentage":%s,"resets_at":1700000000}'
reset_json() { # <h_pct> <w_pct>
    printf '{"workspace":{"current_dir":"%s/dev"},"model":{"display_name":"Fable 5"},"rate_limits":{'"$RL_RESET"'}}' \
        "$H" "$1" "$2"
}

render "$(reset_json 77 80)" TZ=UTC
has "h77%(22:13)" "hot h: reset time appended, no space"
has "w80%(Tue)" "hot w: reset weekday appended"
raw_has "${HEAT_ORANGE}h77%(22:13)${RESET_ESC}" "reset time shares the segment color"

render "$(reset_json 69 69)" TZ=UTC
plain_is '[~/dev|Fable 5|h69%|w69%]' "below HOT_PCT: no reset shown"

render "$(reset_json 70 90)" TZ=UTC
has "h70%(22:13)" "at HOT_PCT threshold: shown"
has "w90%(Tue)" "red window: shown"

# Missing resets_at on a hot window: percentage still renders, no parens.
render "$(printf '{"workspace":{"current_dir":"%s/dev"},"model":{"display_name":"Fable 5"},"rate_limits":{"five_hour":{"used_percentage":80}}}' "$H")"
plain_is '[~/dev|Fable 5|h80%]' "hot but no resets_at: bare percentage"

### Effort levels ####################################################

for lvl_color in "low:lo:$HEAT_GRAY" "medium:me:$HEAT_GRAY" "high:hi:$HEAT_YELLOW" "xhigh:xh:$HEAT_ORANGE" "max:ma:$HEAT_RED"; do
    lvl="${lvl_color%%:*}"; rest="${lvl_color#*:}"
    short="${rest%%:*}"; color="${rest#*:}"
    render "$(mk "$H/dev" "Fable 5" "$lvl" - - -)"
    plain_is "[~/dev|Fable 5|$short]" "effort $lvl shows as $short"
    raw_has "${color}${short}" "effort $lvl color"
done

### Git states (Pure style) ##########################################

gq() { git -C "$1" -c user.name=t -c user.email=t@t "${@:2}"; }
new_repo() { # <dir> <branch>
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" checkout -q -b "$2"
}

new_repo "$H/g1" main
gq "$H/g1" commit -q --allow-empty -m one
render "$(mk "$H/g1" "Fable 5" - - - -)"
plain_is '[~/g1|main|Fable 5]' "clean repo: branch, no markers"
touch "$H/g1/f"
render "$(mk "$H/g1" "Fable 5" - - - -)"
plain_is '[~/g1|main*|Fable 5]' "dirty repo: star"
raw_has "${PURE_GIT_DIRTY}*" "dirty star pink"
gq "$H/g1" checkout -q --detach
render "$(mk "$H/g1" "Fable 5" - - - -)"
has "|HEAD*|" "detached shows HEAD"

git clone -q "$H/g1" "$H/g2" 2>/dev/null
gq "$H/g2" checkout -q main
gq "$H/g2" commit -q --allow-empty -m local
gq "$H/g1" checkout -q main
gq "$H/g1" commit -q --allow-empty -m remote
gq "$H/g2" fetch -q
render "$(mk "$H/g2" "Fable 5" - - - -)"
has "main ⇡⇣" "diverged: both arrows"

new_repo "$H/g3" main
printf 'a\n' >"$H/g3/f"; gq "$H/g3" add f; gq "$H/g3" commit -q -m base
gq "$H/g3" checkout -q -b side
printf 'b\n' >"$H/g3/f"; gq "$H/g3" commit -q -am side
gq "$H/g3" checkout -q main
printf 'c\n' >"$H/g3/f"; gq "$H/g3" commit -q -am main
gq "$H/g3" merge -q side >/dev/null 2>&1
render "$(mk "$H/g3" "Fable 5" - - - -)"
has "main* merge" "merge in progress: action shown"
raw_has "${YELLOW} merge" "action theme yellow, as in Pure"

### Ladder: rung order ###############################################

# fish-2 fires before fish-1 and before model-short; dot keeps width+1
render "$(mk "$H/.config/appdir/element-of-thirty-chars-xxxxxx" "$OPUS" high 6 8 1)"
has "~/.co/ap/" "fish-2 with dot dir keeping 3 chars"
has "(1M context)" "model still full at fish-2"
width_le 80 "fish-2 case fits"

render "$(mk "$H/.config/appdir/$X33" "$OPUS" high 6 8 1)"
has "~/.c/a/" "fish-1 with dot dir keeping 2 chars"
has "(1M context)" "model still full at fish-1"
width_le 80 "fish-1 case fits"

# the vim prefix counts toward the width: 78 wide fits alone, not with "INSERT  "
X58=$(printf 'x%.0s' {1..58})
render "$(mk "$H/aaa/bbb/$X58" "Fable 5" - - - -)"
plain_is "[~/aaa/bbb/$X58|Fable 5]" "without vim prefix: fits untouched"
render "$(mk "$H/aaa/bbb/$X58" "Fable 5" - - - - INSERT)"
plain_is "INSERT  [~/a/b/$X58|Fa5]" "with vim prefix: ladder walks until the whole line fits"

# Width source: tmux pane less 4, unless overridden; 90 without tmux.
# The X58 line is 78 wide: fits a limit of 78, shortens at 77.
in_pane() { # <pane_width|-> -> PANE_ENV, render's env args: tmux pane %1, no override
    PANE_ENV=(PATH="$TMP/bin:$PATH" TMUX_PANE=%1 CLAUDE_MAX_STATUSLINE_WIDTH= FAKE_PANE_WIDTH="${1#-}")
}
in_pane 82; render "$(mk "$H/aaa/bbb/$X58" "Fable 5" - - - -)" "${PANE_ENV[@]}"
plain_is "[~/aaa/bbb/$X58|Fable 5]" "82-column pane: limit 78, fits"
in_pane 81; render "$(mk "$H/aaa/bbb/$X58" "Fable 5" - - - -)" "${PANE_ENV[@]}"
has "~/aa/bb/" "81-column pane: limit 77, path shortened"
in_pane 81; render "$(mk "$H/aaa/bbb/$X58" "Fable 5" - - - -)" "${PANE_ENV[@]}" CLAUDE_MAX_STATUSLINE_WIDTH=80
plain_is "[~/aaa/bbb/$X58|Fable 5]" "explicit width wins over the pane"
X65=$(printf 'x%.0s' {1..65})
in_pane -; render "$(mk "$H/aaa/bbb/$X65" "Fable 5" - - - -)" "${PANE_ENV[@]}"
plain_is "[~/aaa/bbb/$X65|Fable 5]" "tmux failing: default 90, 85 wide fits"
render "$(mk "$H/aaa/bbb/$X65" "Fable 5" - - - -)" TMUX_PANE= CLAUDE_MAX_STATUSLINE_WIDTH=
plain_is "[~/aaa/bbb/$X65|Fable 5]" "outside tmux: default 90"

# model-short fires before git-short and before effort/model drops
render "$(mk "$H/a/b/c/this-final-element-is-forty-chars-long-" "$OPUS" high 6 8 1)"
plain_is '[~/a/b/c/this-final-element-is-forty-chars-long-|Op4.8|hi|c6%|h8%|w1%]' \
    "model shortened to Op4.8, effort kept"

render "$(mk "$H/a/b/c/this-final-element-is-forty-chars-long-" "Claude 3.5 Sonnet" high 6 8 1)"
has "|Cl3.5|" "mid-string version found"

render "$(mk "$H/a/b/c/$X55" "Claude" high 6 8 1)"
has "|Cl|" "versionless model abbreviates to 2 chars"

new_repo "$H/my-project-repository-dirname" quite-long-branch-name-for-the-tests-x
render "$(mk "$H/my-project-repository-dirname" "Fable 5" high 6 8 1)"
has "quite-lo…-tests-x" "branch elided first8…last8"
has "|Fa5|" "model already short when branch elides"
has "|hi|" "effort survives when git-short suffices"
width_le 80 "git-short case fits"

new_repo "$H/g4" short-branch
render "$(mk "$H/g4" "Fable 5" - - - -)"
has "|short-branch|" "17-char-or-less branch never elided"

### Ladder: danger-ordered percentages ###############################

render "$(mk "$H/a/b/c/$X60" "Fable 5" high 6 2 80)"
has "c6%" "danger: c6 survives"
has "w80%" "danger: orange w80 survives over cooler values"
hasnt "h2%" "danger: coolest h2 dropped first"
width_le 80 "danger case fits"

render "$(mk "$H/a/b/c/$X60" "Fable 5" high 6 6 6)"
has "c6%" "tie: c most precious"
has "h6%" "tie: h second"
hasnt "w6%" "tie: w dropped first"

render "$(mk "$H/a/b/c/$X60" "Fable 5" high 95 92 88)"
has "c95%" "pinned: hot c stays"
has "h92%" "pinned: hot h stays"
has "w88%" "pinned: hot w stays"
width_gt 80 "pinning accepts overflow"

render "$(mk "$H/a/b/c/$X90" "Fable 5" high 6 8 1)"
plain_is "[~/a/b/c/$X90]" "floor: only path left, overflow accepted"

### Summary ##########################################################

printf '%d passed, %d failed (statusline bash: %s)\n' "$pass" "$fail" "$SL_BASH"
[ "$fail" -eq 0 ]
