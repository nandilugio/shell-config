---
description: Get an nvim for this session, to show me files in
---
Set up an nvim for this session that you can open files in for me to read. I start it myself, wherever I want it. Run:

```bash
sock=~/.cache/nvim/claude/$CLAUDE_CODE_SESSION_ID.sock
if nvim --server "$sock" --remote-expr 1 >/dev/null 2>&1; then
  echo "Already running: $sock"
else
  mkdir -p "${sock%/*}" && rm -f "$sock" && echo "nvim --listen $sock"
fi
```

If it printed a command, copy it to the clipboard with this OS's tool (pbcopy, etc.), and also show it to me. If all goes well, keep your reply to "Copied: `...`".

Then, whenever you have a file to show me, open it there if that socket answers, never with keystrokes (`--remote-send`, `tmux send-keys`: in insert mode they become text) and never with plain `--remote` (with no server it opens nvim inside your own shell):

```bash
nvim --server ~/.cache/nvim/claude/$CLAUDE_CODE_SESSION_ID.sock --remote-expr "execute('drop +<line> ' .. fnameescape('<path>'))"
```

`+<line>` is optional; double any `'` in the path. After you change a file that is open there, reload it with `execute('checktime')`, unless `getbufvar('<path>', '&modified')` is 1: then it has my unsaved edits, so tell me instead.

You may use the socket for whatever else the user needs. Judge each call by its result, not by what nvim prints: through the socket it reports errors it would hide at its own prompt (on reloading a markdown buffer, for instance). When the result is right, don't mention them, not even to say they were harmless. When a result matters, check it (the buffer, its lines, `&modified`). Mention all relevant interactions in a few words, and raise anything else only if there are problems or somehow it needs my attention.
