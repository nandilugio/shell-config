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

# Fish-style path abbreviation: every ancestor element shortened to its
# first two characters, last element kept in full (e.g. /Users/nandosq/empty -> /Us/na/empty)
# Paths under $HOME are first collapsed to a ~ prefix (e.g. ~/empty, ~/de/fo/bar)
abbreviate_path() {
    local path="$1"
    local home="${HOME:-}"

    if [ -n "$home" ] && [ "$path" = "$home" ]; then
        echo "~"
        return
    fi

    if [ -n "$home" ] && [ "${path#"$home"/}" != "$path" ]; then
        path="~/${path#"$home"/}"
    fi

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
            abbreviated="$abbreviated${part:0:2}/"
        fi
    done

    echo "${abbreviated}${last}"
}

# Single git call: `status --porcelain=v2 --branch` reports branch/detached
# state, ahead/behind counts, and dirty status all in one subprocess.
read_git_segment() {
    local cwd="$1"
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

    local segment="${GRAY}${branch}${RESET}"
    [ -n "$dirty" ] && segment="${segment}${PINK}${dirty}${RESET}"
    [ -n "$action" ] && segment="${segment}${GRAY} ${action}${RESET}"
    [ -n "$arrows" ] && segment="${segment}${CYAN} ${arrows}${RESET}"
    echo "$segment"
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

# Colored "prefix<pct>%" segment for a usage value, or nothing if not numeric.
# Truncates any fractional part (values arrive as integers in practice).
usage_segment() {
    local prefix="$1" value="$2"
    local pct="${value%%[.,]*}"
    case "$pct" in
        ''|*[!0-9]*) return ;;
    esac
    local color
    color=$(usage_color "$pct")
    echo "${color}${prefix}${pct}%${RESET}"
}

dir_display=$(abbreviate_path "$cwd")
git_segment=$(read_git_segment "$cwd")

parts=("${CYAN}${dir_display}${RESET}")

[ -n "$git_segment" ] && parts+=("$git_segment")

parts+=("${YELLOW}${model}${RESET}")

[ -n "$effort" ] && parts+=("$(effort_color "$effort")${effort}${RESET}")

# Context usage (c). Null until the first API response — omit the segment then.
c_segment=$(usage_segment "c" "$context_used")
[ -n "$c_segment" ] && parts+=("$c_segment")

# Subscription usage (h = 5-hour, w = 7-day). Absent until the first API
# response of a session, and for non-subscribers — omit the segment then.
h_segment=$(usage_segment "h" "$five_hour")
[ -n "$h_segment" ] && parts+=("$h_segment")

w_segment=$(usage_segment "w" "$seven_day")
[ -n "$w_segment" ] && parts+=("$w_segment")

# Session cost, truncated to cents. String math instead of printf %.2f:
# float printf mis-parses dot decimals under comma-decimal locales.
cost_int="${cost%%[.,]*}"
case "$cost_int" in
    ''|*[!0-9]*) ;;
    *)
        cost_frac="${cost#"$cost_int"}"
        cost_frac="${cost_frac#[.,]}00"
        parts+=("${GRAY}\$${cost_int}.${cost_frac:0:2}${RESET}")
        ;;
esac

sep="${DARK_GRAY}|${RESET}"
line="${parts[0]}"
for part in "${parts[@]:1}"; do
    line+="${sep}${part}"
done

bracketed="${DARK_GRAY}[${RESET}${line}${DARK_GRAY}]${RESET}"

# Payload sends the mode already uppercase ("INSERT", "NORMAL", ...).
if [ -n "$vim_mode" ]; then
    printf "%s-- %s --%s  %s" "$DARK_GRAY" "$vim_mode" "$RESET" "$bracketed"
else
    printf "%s" "$bracketed"
fi
