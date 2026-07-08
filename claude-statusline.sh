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
# Requires: bash, jq, git >= 2.13

# Colors
DIM=$'\033[90m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
ORANGE=$'\033[38;5;208m'
RED=$'\033[31m'
DIRTY=$'\033[38;5;218m'
RESET=$'\033[0m'

# Single jq call: extract all needed fields at once, one per line.
# (Not @tsv: it backslash-escapes embedded tabs/newlines instead of raw output.)
{
    IFS= read -r cwd
    IFS= read -r model
    IFS= read -r remaining
    IFS= read -r vim_mode
} <<<"$(
    jq -r '
        (.workspace.current_dir // .cwd),
        (.model.display_name // "Claude"),
        (.context_window.remaining_percentage // ""),
        (.vim.mode // "")
    '
)"

# Fish-style path abbreviation: every ancestor element shortened to its
# first character, last element kept in full (e.g. /Users/nandosq/empty -> /U/n/empty)
# Paths under $HOME are first collapsed to a ~ prefix (e.g. ~/empty, ~/d/f/bar)
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
            abbreviated="$abbreviated${part:0:1}/"
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

    local segment="${DIM}${branch}${RESET}"
    [ -n "$dirty" ] && segment="${segment}${DIRTY}${dirty}${RESET}"
    [ -n "$action" ] && segment="${segment}${DIM} ${action}${RESET}"
    [ -n "$arrows" ] && segment="${segment}${CYAN} ${arrows}${RESET}"
    echo "$segment"
}

# Context color gradient: green (low usage) -> yellow -> orange -> red (near full)
context_color() {
    local used="$1"
    if [ "$used" -lt 50 ]; then
        echo "$GREEN"
    elif [ "$used" -lt 75 ]; then
        echo "$YELLOW"
    elif [ "$used" -lt 90 ]; then
        echo "$ORANGE"
    else
        echo "$RED"
    fi
}

dir_display=$(abbreviate_path "$cwd")
git_segment=$(read_git_segment "$cwd")

parts=("${CYAN}${dir_display}${RESET}")

[ -n "$git_segment" ] && parts+=("$git_segment")

parts+=("${GREEN}${model}${RESET}")

if [ -n "$remaining" ]; then
    # Locale-safe rounding without a subprocess: printf "%.0f" mis-parses
    # comma-decimal locales (e.g. LC_NUMERIC=de_DE), tolerate either separator.
    remaining_int="${remaining%%[.,]*}"
    frac="${remaining#"$remaining_int"}"
    frac="${frac#[.,]}"
    case "$remaining_int" in
        ''|*[!0-9]*) remaining_int="" ;;
        *)
            case "$frac" in
                [5-9]*) remaining_int=$((remaining_int + 1)) ;;
            esac
            ;;
    esac

    if [ -n "$remaining_int" ]; then
        used_int=$((100 - remaining_int))
        color=$(context_color "$used_int")
        parts+=("${color}${used_int}%${RESET}")
    fi
fi

sep="${DIM}|${RESET}"
line=""
for i in "${!parts[@]}"; do
    if [ "$i" -eq 0 ]; then
        line="${parts[$i]}"
    else
        line="${line}${sep}${parts[$i]}"
    fi
done

bracketed="${DIM}[${RESET}${line}${DIM}]${RESET}"

if [ -n "$vim_mode" ]; then
    vim_mode_upper=$(echo "$vim_mode" | tr '[:lower:]' '[:upper:]')
    printf "%s-- %s --%s  %s" "$DIM" "$vim_mode_upper" "$RESET" "$bracketed"
else
    printf "%s" "$bracketed"
fi
