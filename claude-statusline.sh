#!/usr/bin/env bash

# Pure-inspired status line for Claude Code
# Minimalist design matching the Pure zsh theme
#
# Install (new machine):
#   ln -s ~/.shell-config/claude-statusline.sh ~/.claude/claude-statusline.sh
#   Add to ~/.claude/settings.json:
#     "statusLine": {
#       "type": "command",
#       "command": "~/.claude/claude-statusline.sh",
#       "hideVimModeIndicator": true,
#       "refreshInterval": 60
#     }
# Requires: bash 3.2+, jq, git >= 2.15

# No globbing anywhere; keeps unquoted expansions (path splitting) literal.
set -f

# The bracketed line (brackets included, vim prefix excluded) is kept within
# max_width visible chars by walking the reduction ladder near the bottom.
max_width=${CLAUDE_MAX_STATUSLINE_WIDTH:-120}

# Percentages at or above this never drop from the ladder (orange and red
# bands): a hot value is worth showing even over shorter segments.
HOT_PCT=75

# Colors
DARK_GRAY=$'\033[90m'
GRAY=$'\033[38;5;245m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
ORANGE=$'\033[38;5;208m'
RED=$'\033[31m'
PINK=$'\033[38;5;218m'
RESET=$'\033[0m'

# Single jq call: extract all needed fields at once, one per line.
# (Not @tsv: it backslash-escapes embedded tabs/newlines instead of raw output.)
{
    IFS= read -r cwd
    IFS= read -r model
    IFS= read -r effort
    IFS= read -r context_used
    IFS= read -r five_hour
    IFS= read -r seven_day
    IFS= read -r cost
    IFS= read -r vim_mode
} <<<"$(
    jq -r '
        (.workspace.current_dir // .cwd),
        (.model.display_name // "Claude"),
        (.effort.level // ""),
        (.context_window.used_percentage // ""),
        (.rate_limits.five_hour.used_percentage // ""),
        (.rate_limits.seven_day.used_percentage // ""),
        (.cost.total_cost_usd // ""),
        (.vim.mode // "")
    '
)"

# $HOME prefix collapsed to ~ (e.g. /Users/nandosq/dev -> ~/dev)
collapse_home() {
    local path="$1" home="${HOME:-}"
    if [ -n "$home" ]; then
        if [ "$path" = "$home" ]; then
            path="~"
        elif [ "${path#"$home"/}" != "$path" ]; then
            path="~/${path#"$home"/}"
        fi
    fi
    echo "$path"
}

# Fish-style abbreviation: every ancestor element shortened to its first
# $2 characters, last element kept in full (e.g. ~/dev/foo/bar -> ~/de/fo/bar).
# As in fish, a leading dot doesn't count (.claude -> .c at width 1).
abbreviate_path() {
    local path="$1" width="$2"

    local last="${path##*/}"
    local dir="${path%/*}"

    if [ "$dir" = "$path" ] || [ -z "$dir" ]; then
        echo "$path"
        return
    fi

    local abbreviated=""
    local IFS='/'
    local part
    for part in $dir; do
        if [ -z "$part" ]; then
            abbreviated="$abbreviated/"
        else
            case "$part" in
                .*) abbreviated="$abbreviated${part:0:width+1}/" ;;
                *)  abbreviated="$abbreviated${part:0:width}/" ;;
            esac
        fi
    done

    echo "${abbreviated}${last}"
}

# Single git call: `status --porcelain=v2 --branch` reports branch/detached
# state, ahead/behind counts, and dirty status all in one subprocess.
# Sets GIT_TEXT/GIT_LEN (full branch) and GIT_TEXT_SHORT/GIT_LEN_SHORT
# (branch as first8…last8; same as full when the branch is 17 chars or less).
# All empty/0 when not in a git repository.
read_git_segment() {
    local cwd="$1"
    GIT_TEXT="" GIT_LEN=0 GIT_TEXT_SHORT="" GIT_LEN_SHORT=0

    local status
    status=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null) || return
    [ -n "$status" ] || return

    local branch="" ahead=0 behind=0 dirty=""
    while IFS= read -r line; do
        case "$line" in
            "# branch.head "*)
                branch="${line#"# branch.head "}"
                [ "$branch" = "(detached)" ] && branch="HEAD"
                ;;
            "# branch.ab "*)
                # format: # branch.ab +<ahead> -<behind>
                local ab="${line#"# branch.ab "}"
                ahead="${ab#+}"; ahead="${ahead%% *}"
                behind="${ab##* -}"
                ;;
            "#"*) ;;
            *) dirty="*" ;;
        esac
    done <<<"$status"

    [ -n "$branch" ] || return

    local arrows=""
    [ "$ahead" -gt 0 ] 2>/dev/null && arrows="${arrows}⇡"
    [ "$behind" -gt 0 ] 2>/dev/null && arrows="${arrows}⇣"

    local gitdir
    gitdir=$(git -C "$cwd" --no-optional-locks rev-parse --absolute-git-dir 2>/dev/null)
    local action=""
    if [ -n "$gitdir" ]; then
        if [ -d "$gitdir/rebase-merge" ]; then
            action="rebase"
        elif [ -f "$gitdir/rebase-apply/applying" ]; then
            action="am"
        elif [ -d "$gitdir/rebase-apply" ]; then
            action="rebase"
        elif [ -f "$gitdir/MERGE_HEAD" ]; then
            action="merge"
        elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then
            action="cherry-pick"
        elif [ -f "$gitdir/REVERT_HEAD" ]; then
            action="revert"
        elif [ -f "$gitdir/BISECT_LOG" ]; then
            action="bisect"
        fi
    fi

    local suffix="" suffix_len=0
    [ -n "$dirty" ] && { suffix+="${PINK}${dirty}${RESET}"; suffix_len=$((suffix_len + 1)); }
    [ -n "$action" ] && { suffix+="${GRAY} ${action}${RESET}"; suffix_len=$((suffix_len + 1 + ${#action})); }
    [ -n "$arrows" ] && { suffix+="${CYAN} ${arrows}${RESET}"; suffix_len=$((suffix_len + 1 + ${#arrows})); }

    GIT_TEXT="${GRAY}${branch}${RESET}${suffix}"
    GIT_LEN=$(( ${#branch} + suffix_len ))
    if [ "${#branch}" -gt 17 ]; then
        GIT_TEXT_SHORT="${GRAY}${branch:0:8}${DARK_GRAY}…${GRAY}${branch: -8}${RESET}${suffix}"
        GIT_LEN_SHORT=$(( 17 + suffix_len ))
    else
        GIT_TEXT_SHORT="$GIT_TEXT"
        GIT_LEN_SHORT=$GIT_LEN
    fi
}

# Usage color gradient: gray (low) -> yellow -> orange -> red (near full)
usage_color() {
    local used="$1"
    if [ "$used" -lt 50 ]; then
        echo "$GRAY"
    elif [ "$used" -lt 75 ]; then
        echo "$YELLOW"
    elif [ "$used" -lt 90 ]; then
        echo "$ORANGE"
    else
        echo "$RED"
    fi
}

# Effort color: gray below high, yellow at high, orange at xhigh, red at max.
effort_color() {
    case "$1" in
        high)  echo "$YELLOW" ;;
        xhigh) echo "$ORANGE" ;;
        max)   echo "$RED" ;;
        *)     echo "$GRAY" ;;
    esac
}

# Compact model name into MODEL_SHORT: first two chars of the name plus the
# first version-looking token (contains a digit), parenthetical suffix
# dropped (e.g. "Opus 4.8 (1M context)" -> "Op4.8", "Fable 5" -> "Fa5").
abbrev_model() {
    local name="${model%% (*}" rest tok
    MODEL_SHORT="${name:0:2}"
    rest="${name#* }"
    [ "$rest" = "$name" ] && return
    for tok in $rest; do
        case "$tok" in
            *[0-9]*) MODEL_SHORT="${MODEL_SHORT}${tok}"; return ;;
        esac
    done
}

# Segments as parallel arrays: colored text, visible length, active flag.
seg_texts=()
seg_lens=()
seg_on=()

# Percentage segments, for danger-ordered dropping: segment index and value.
pct_idxs=()
pct_vals=()

add_seg() { # <visible_len> <colored_text>; leaves the new index in LAST_IDX
    seg_lens+=("$1")
    seg_texts+=("$2")
    seg_on+=(1)
    LAST_IDX=$(( ${#seg_texts[@]} - 1 ))
}

# Colored "<prefix><pct>%" usage segment, skipped (LAST_IDX=-1) if not numeric.
# Truncates any fractional part (values arrive as integers in practice).
add_usage_seg() {
    local prefix="$1" value="$2"
    LAST_IDX=-1
    local pct="${value%%[.,]*}"
    case "$pct" in
        ''|*[!0-9]*) return ;;
    esac
    add_seg $(( ${#prefix} + ${#pct} + 1 )) "$(usage_color "$pct")${prefix}${pct}%${RESET}"
    pct_idxs+=("$LAST_IDX")
    pct_vals+=("$pct")
}

drop_seg() { # deactivate segment by index (-1 = absent) and its separator
    local i="$1"
    { [ "$i" -ge 0 ] && [ "${seg_on[$i]}" = 1 ]; } || return
    seg_on[$i]=0
    total=$(( total - seg_lens[i] - 1 ))
}

swap_path() { # re-abbreviate the path segment (always index 0) to width $1
    local new_path
    new_path=$(abbreviate_path "$path_display" "$1")
    total=$(( total - seg_lens[0] + ${#new_path} ))
    seg_lens[0]=${#new_path}
    seg_texts[0]="${CYAN}${new_path}${RESET}"
}

# Drop the coolest active percentage segment; values at or above HOT_PCT are
# pinned. Ties resolve toward the later-scanned one, so w drops before h
# before c. No-op when everything left is hot (the floor accepts overflow).
drop_coolest_pct() {
    local i si drop_at=-1 drop_val=999
    for (( i = 0; i < ${#pct_idxs[@]}; i++ )); do
        si=${pct_idxs[$i]}
        [ "${seg_on[$si]}" = 1 ] || continue
        [ "${pct_vals[$i]}" -lt "$HOT_PCT" ] || continue
        [ "${pct_vals[$i]}" -le "$drop_val" ] || continue
        drop_val=${pct_vals[$i]}
        drop_at=$si
    done
    drop_seg "$drop_at"
}

path_display=$(collapse_home "$cwd")
add_seg "${#path_display}" "${CYAN}${path_display}${RESET}"

read_git_segment "$cwd"
idx_git=-1
if [ -n "$GIT_TEXT" ]; then
    add_seg "$GIT_LEN" "$GIT_TEXT"
    idx_git=$LAST_IDX
fi

add_seg "${#model}" "${YELLOW}${model}${RESET}"
idx_model=$LAST_IDX

# Effort always truncated to 2 chars (lo/me/hi/xh/ma); the color carries it.
idx_effort=-1
if [ -n "$effort" ]; then
    effort_short="${effort:0:2}"
    add_seg "${#effort_short}" "$(effort_color "$effort")${effort_short}${RESET}"
    idx_effort=$LAST_IDX
fi

# Usage (c = context, h = 5-hour limit, w = 7-day limit). Null/absent until
# the first API response, and h/w only for subscribers — skipped then.
add_usage_seg "c" "$context_used"
add_usage_seg "h" "$five_hour"
add_usage_seg "w" "$seven_day"

# Session cost, truncated to cents. String math instead of printf %.2f:
# float printf mis-parses dot decimals under comma-decimal locales.
idx_cost=-1
case "$cost" in
    # scientific notation passes through jq (e.g. 1.23E-7) and would mis-split;
    # it only appears below one micro-dollar, so it truncates to zero anyway.
    *[eE]*) cost="0" ;;
esac
cost_int="${cost%%[.,]*}"
case "$cost_int" in
    ''|*[!0-9]*) ;;
    *)
        cost_frac="${cost#"$cost_int"}"
        cost_frac="${cost_frac#[.,]}00"
        add_seg $(( ${#cost_int} + 4 )) "${GRAY}\$${cost_int}.${cost_frac:0:2}${RESET}"
        idx_cost=$LAST_IDX
        ;;
esac

# Visible width: brackets + segments + one pipe between each pair.
total=$(( 2 + ${#seg_texts[@]} - 1 ))
for len in "${seg_lens[@]}"; do
    total=$(( total + len ))
done

# Reduction ladder, applied in order until the line fits max_width:
# drop cost -> path fish-2 -> fish-1 -> short model -> short branch ->
# drop effort -> model -> percentages coolest-first (hot ones pinned, see
# HOT_PCT). Overflow is accepted if the floor still doesn't fit.
step=0
while [ "$total" -gt "$max_width" ] && [ "$step" -lt 10 ]; do
    case "$step" in
        0) drop_seg "$idx_cost" ;;
        1) swap_path 2 ;;
        2) swap_path 1 ;;
        3)
            abbrev_model
            if [ "${#MODEL_SHORT}" -lt "${seg_lens[idx_model]}" ]; then
                total=$(( total - seg_lens[idx_model] + ${#MODEL_SHORT} ))
                seg_lens[$idx_model]=${#MODEL_SHORT}
                seg_texts[$idx_model]="${YELLOW}${MODEL_SHORT}${RESET}"
            fi
            ;;
        4)
            if [ "$idx_git" -ge 0 ] && [ "$GIT_LEN_SHORT" -lt "$GIT_LEN" ]; then
                total=$(( total - seg_lens[idx_git] + GIT_LEN_SHORT ))
                seg_lens[$idx_git]=$GIT_LEN_SHORT
                seg_texts[$idx_git]="$GIT_TEXT_SHORT"
            fi
            ;;
        5) drop_seg "$idx_effort" ;;
        6) drop_seg "$idx_model" ;;
        7|8|9) drop_coolest_pct ;;
    esac
    step=$(( step + 1 ))
done

sep="${DARK_GRAY}|${RESET}"
line=""
for i in "${!seg_texts[@]}"; do
    [ "${seg_on[$i]}" = 1 ] || continue
    if [ -z "$line" ]; then
        line="${seg_texts[$i]}"
    else
        line+="${sep}${seg_texts[$i]}"
    fi
done

bracketed="${DARK_GRAY}[${RESET}${line}${DARK_GRAY}]${RESET}"

# Payload sends the mode already uppercase ("INSERT", "NORMAL", ...).
if [ -n "$vim_mode" ]; then
    printf "%s-- %s --%s  %s" "$DARK_GRAY" "$vim_mode" "$RESET" "$bracketed"
else
    printf "%s" "$bracketed"
fi
