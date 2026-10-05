# mdheading — design notes

Why the plugin is built the way it is, and what was measured to decide. The
README is the user-facing half: what it does, how to install and configure it.
These are the working notes behind it — terse, dated, and appended to as things
change. Moved here 2026-09-16 from the config's docs/decisions.md, where the
rebuild log had been carrying them.

## A second local plugin, not one markdown plugin (2026-09-16)

Added 2026-09-16. User's observation: markdown encodes depth in character count, so
"######" looks heavier than "#" while meaning less — "I find ### more visually important
than #, so that looks backwards" — and headings are hard to spot in messy text.
Fix: a background colour per level, strongest at 1, fading to 4 (levels 5 and 6 share the
4th's shade — see the FINAL ROUND entry below). One extmark per heading line with
line_hl_group. Display only; the file is untouched.

COLOUR IS DERIVED, NOT CONFIGURED — and the derivation was MEASURED, not assumed:
  * All six @markup.heading.N.markdown groups are IDENTICAL in the default scheme
    (fg #e0e2ea, bold). There is no existing ordered scale to read, so a ramp must be
    computed. This settled the user's own doubt ("I doubt we can have 6 ordered levels").
  * That heading fg IS Normal's fg, so blending it would give six greys and depth would
    read as nothing. A genuinely coloured source is required: the list is
    @markup.heading.1, @markup.heading, Directory, Function, Special, Title, and the
    first NON-GREY one wins (grey = max channel - min channel < 24).
  * FINAL: blend range 0.50-0.92 toward Normal's bg, linear, over 4 distinct levels.
    The road there is below, kept because each step rejected something that looked
    obvious, and the last entry is the one that settled it.
    REVISED 2026-09-16 after the user tried it: first shipped 0.70-0.92, which worked but
    the user asked for "more difference between shades" — levels 2-5 were hard to separate
    at a 9-unit step. The fix was NOT simply a wider range, and the measurement is the
    point: a heading line still has TEXT on it, drawn in Normal's fg, so the tint may not
    get bright enough to swallow it. Contrast of #e0e2ea on each candidate h1:
      0.70 (shipped) 5.8:1    0.62  4.5:1 <- WCAG AA floor, CHOSEN
      0.45           2.7:1    0.35  2.1:1    0.30 1.8:1  <- all unreadable
    0.62 is the brightest blend that still clears AA, and it widens the step from 9 to 12
    units (+40% separation) at zero readability cost. That ceiling, not taste, is what
    sets the spacing — the other end is pinned by the background.
    Verified on all seven bundled schemes; worst level anywhere is 3.4:1 (catppuccin),
    above the 3:1 bold threshold, and heading text is bold. REGRESSION TEST ADDED, and
    checked that it has teeth: it fails at 0.40 (2.4:1) and passes at 0.62.
  * Rejected an eased curve (more separation at the top): it buys h1 three units and
    costs h2->h3 half their separation, and telling h2 from h3 is the commoner need.
    Linear is also less code.
  * Rejected a hue shift down the ramp (ROTATE the hue per level): measured at shifts of
    0.05-0.12 it moved the blended colours by 1-4 points per channel — invisible.
  * SECOND AXIS ADDED 2026-09-16, user's idea, after 0.62-0.92 still read as too similar:
    "maybe we can make it not only more dark but also more grey (less saturation)".
    Right call, and it works because it is ORTHOGONAL to the constraint: desaturating
    mixes toward the colour's OWN luminance-grey, which leaves brightness — and therefore
    contrast — untouched. So it buys separation the brightness axis cannot, that axis
    being pinned at the top by readability and at the bottom by the background.
    DESATURATE_LAST = 1.0, linear with the level, so h1 keeps the source colour and h6 is
    nearly neutral. Saturation now falls 45->6 instead of 45->15 in the default scheme;
    depth reads as colour draining away rather than as six samples of one colour.
    Per-scheme after: default 45->6, catppuccin 53->14, retrobox 56->0, sorbet 40->11,
    habamax 15->0, quiet 0->0 (monochrome, degrades correctly).
    Contrast is unchanged at 4.5:1 worst in default — verified, since that was the point.
    REGRESSION TEST: saturation must fall monotonically with the level.
    NOTE the distance-from-background invariant still holds, so the pre-existing
    "six distinct shades, fading in order" check passes unmodified.
  * FINAL ROUND 2026-09-16, same session, settled by A/B-ing on real files.
    Two axes still read as too similar in use, so we measured every remaining lever
    rather than guessing which would help:
      white mixed into the top levels   +0.4 units of separation for -0.3 contrast.
                                        REJECTED: white raises luminance, so it hits the
                                        SAME readability cap as brightness. Same axis
                                        wearing a different hat — which is exactly the
                                        trap the earlier "just widen the range" was.
      front-loaded curve (t^0.55)       steps 25,14,10,7,6 against a flat 12. REJECTED:
                                        moves separation to where it was already adequate
                                        and starves the deep levels.
      fewer distinct levels             THE ONLY LEVER THAT WORKED. A bounded range over
                                        fewer steps makes each step bigger. No contrast
                                        cost, no extra code — a smaller divisor.
    Smallest gap between adjacent shades, default scheme, all at 0.50:
      6 levels 16    5 levels 21    4 levels 27    (was 12 at 0.62/6)
    LANDED ON BLEND_FIRST=0.50 with DISTINCT_LEVELS=4.
    0.50 puts h1 at 3.1:1 — over WCAG's 3:1 for BOLD text, which heading text is, but
    under the 4.5:1 that 0.62 was chosen for. The user A/B'd 0.62 -> 0.55 -> 0.50 on real
    files and on three schemes before choosing; this is a judgment call made by looking,
    not a threshold met. Recorded as such.
    THE COST, stated plainly: #### ##### and ###### are ONE shade. #### is common enough
    to miss. Accepted because a distinction too fine to see is not a distinction.
    DISTINCT_LEVELS trades it back with no other change.
    TWO SCHEMES GO UNDER 3:1 at this setting: catppuccin 2.6, retrobox 2.7 — their accent
    is lighter against their background, so the same blend lands brighter. The user looked
    at both ("works less nicely but works") and accepted it.
    HOW THE TEST HANDLES THAT, because this is the part worth getting right: the two are
    named in a KNOWN_TOO_BRIGHT list with the measured value, not deleted from the check.
    Any scheme NOT on the list still fails under 3:1, and a listed one fails if it gets
    WORSE than what was accepted (0.15 tolerance). Verified it still has teeth: passes at
    0.50, fails at 0.42 (default 2.5) and 0.35 (default 2.1). An allowance for a known
    amount, not a blank cheque.
    THE PRINCIPLED FIX, not taken: derive the cap per scheme by searching for the
    brightest blend that clears the threshold against THAT scheme's own fg and bg. ~10
    lines, deletes BLEND_FIRST as a magic number and replaces it with a contrast TARGET,
    and every theme would land at its own maximum instead of the global minimum. Deferred
    because the hardcoded value is good on the scheme in use and the complexity is not yet
    earned. This is the first thing to reach for if a scheme ever looks wrong.
  * Verified across every bundled scheme: default teal, catppuccin blue, retrobox olive,
    sorbet green, unokai/habamax muted, quiet greys (correctly — it is monochrome).
    Recomputed on ColorScheme; the marks name groups, not colours, so that is enough.
  * Groups are set with default=true, so a user hl overrides them.
HARDCODED, no knob, per user: "the simplest hardcoded implementation to start and when
we're able to try it I can tell you if we need more knobs". Consistent with mdtable
exposing only `filetypes`.

CLEARS IN INSERT MODE, though nothing forces it. mdtable must clear (padding shifts the
columns under the cursor); a background colour shifts nothing. User chose to clear anyway:
"there's value on removing the plugin effect at all when typing, and making it consistent
to mdtable is a plus". One rule across both plugins beats two.

WIRING COPIED FROM mdtable, NOT SHARED. Two users is where a shared layer is premature —
the interface would be designed from one and a half examples. ~40 lines duplicated:
the b:*_on / b:*_ft override scheme, TextChanged/InsertLeave/BufWinEnter/WinEnter,
ModeChanged i*:* (<C-c> fires no InsertLeave), FileType on every filetype so leaving the
list disables, and the changedtick gate. Each of those was a bug found in mdtable.
NOT copied: OptionSet (no widths, so 'tabstop' is never read) and WinScrolled (marks cover
the whole buffer, not just visible lines). ADDED: ColorScheme.
Extract only if a third plugin arrives.

DETECTION: line scan, same call as mdtable. fence_at() copied verbatim, CommonMark 4.5
rules included — a closing fence carries only its marker, and a backtick fence's info
string may not contain a backtick. Without them a README quoting markdown (this config has
several) tints its code samples. Heading rule is CommonMark 4.2: one to six "#" then
whitespace or EOL, after optional indent/blockquote markers. "#nospace" and "#######" are
not headings; a bare "#" is.
SETEXT HEADINGS NOT SUPPORTED: they need lookahead and "---" collides with a table
separator and a thematic break. Stated in the README rather than half-supported.

TESTS: 47 checks, `nvim -l lua/mdheading/test.lua`. Marks are READ BACK, never recomputed —
mdtable's suite once passed 109 green while the feature drew nothing, and that lesson is
why. Same harness limits: no UI so nothing is painted, no main loop so insert mode is
reached by stubbing mode().
PERFORMANCE: 10k lines with 500 headings renders in 1.2ms (the scan is 0.6ms of it); a
no-op re-render is 1us. No debounce, for the same reason mdtable dropped its.

TERMGUICOLORS is required and is ON (user confirmed `:set termguicolors?` -> "termguicolors").
No ctermbg fallback: 256-colour approximations of six close shades are not six
distinguishable colours. Headless runs report it false because `nvim -l` attaches no UI —
that is the harness, not the config.
KEYMAP: <leader>uH (capital, since <leader>uh is inlay hints), alongside <leader>um.
||||||| Stash base
Added 2026-09-16. User's observation: markdown encodes depth in character count, so
"######" looks heavier than "#" while meaning less — "I find ### more visually important
than #, so that looks backwards" — and headings are hard to spot in messy text.
Fix: a background colour per level, strongest at 1, fading to 6. One extmark per heading
line with line_hl_group. Display only; the file is untouched.

COLOUR IS DERIVED, NOT CONFIGURED — and the derivation was MEASURED, not assumed:
  * All six @markup.heading.N.markdown groups are IDENTICAL in the default scheme
    (fg #e0e2ea, bold). There is no existing ordered scale to read, so a ramp must be
    computed. This settled the user's own doubt ("I doubt we can have 6 ordered levels").
  * That heading fg IS Normal's fg, so blending it would give six greys and depth would
    read as nothing. A genuinely coloured source is required: the list is
    @markup.heading.1, @markup.heading, Directory, Function, Special, Title, and the
    first NON-GREY one wins (grey = max channel - min channel < 24).
  * Blend range 0.62-0.92 toward Normal's bg, linear, six steps.
    REVISED 2026-09-16 after the user tried it: first shipped 0.70-0.92, which worked but
    the user asked for "more difference between shades" — levels 2-5 were hard to separate
    at a 9-unit step. The fix was NOT simply a wider range, and the measurement is the
    point: a heading line still has TEXT on it, drawn in Normal's fg, so the tint may not
    get bright enough to swallow it. Contrast of #e0e2ea on each candidate h1:
      0.70 (shipped) 5.8:1    0.62  4.5:1 <- WCAG AA floor, CHOSEN
      0.45           2.7:1    0.35  2.1:1    0.30 1.8:1  <- all unreadable
    0.62 is the brightest blend that still clears AA, and it widens the step from 9 to 12
    units (+40% separation) at zero readability cost. That ceiling, not taste, is what
    sets the spacing — the other end is pinned by the background.
    Verified on all seven bundled schemes; worst level anywhere is 3.4:1 (catppuccin),
    above the 3:1 bold threshold, and heading text is bold. REGRESSION TEST ADDED, and
    checked that it has teeth: it fails at 0.40 (2.4:1) and passes at 0.62.
  * Rejected an eased curve (more separation at the top): it buys h1 three units and
    costs h2->h3 half their separation, and telling h2 from h3 is the commoner need.
    Linear is also less code.
  * Rejected a hue shift down the ramp (ROTATE the hue per level): measured at shifts of
    0.05-0.12 it moved the blended colours by 1-4 points per channel — invisible.
  * SECOND AXIS ADDED 2026-09-16, user's idea, after 0.62-0.92 still read as too similar:
    "maybe we can make it not only more dark but also more grey (less saturation)".
    Right call, and it works because it is ORTHOGONAL to the constraint: desaturating
    mixes toward the colour's OWN luminance-grey, which leaves brightness — and therefore
    contrast — untouched. So it buys separation the brightness axis cannot, that axis
    being pinned at the top by readability and at the bottom by the background.
    DESATURATE_LAST = 1.0, linear with the level, so h1 keeps the source colour and h6 is
    nearly neutral. Saturation now falls 45->6 instead of 45->15 in the default scheme;
    depth reads as colour draining away rather than as six samples of one colour.
    Per-scheme after: default 45->6, catppuccin 53->14, retrobox 56->0, sorbet 40->11,
    habamax 15->0, quiet 0->0 (monochrome, degrades correctly).
    Contrast is unchanged at 4.5:1 worst in default — verified, since that was the point.
    REGRESSION TEST: saturation must fall monotonically with the level.
    NOTE the distance-from-background invariant still holds, so the pre-existing
    "six distinct shades, fading in order" check passes unmodified.
  * Verified across every bundled scheme: default teal, catppuccin blue, retrobox olive,
    sorbet green, unokai/habamax muted, quiet greys (correctly — it is monochrome).
    Recomputed on ColorScheme; the marks name groups, not colours, so that is enough.
  * Groups are set with default=true, so a user hl overrides them.
HARDCODED, no knob, per user: "the simplest hardcoded implementation to start and when
we're able to try it I can tell you if we need more knobs". Consistent with mdtable
exposing only `filetypes`.

CLEARS IN INSERT MODE, though nothing forces it. mdtable must clear (padding shifts the
columns under the cursor); a background colour shifts nothing. User chose to clear anyway:
"there's value on removing the plugin effect at all when typing, and making it consistent
to mdtable is a plus". One rule across both plugins beats two.

WIRING COPIED FROM mdtable, NOT SHARED. Two users is where a shared layer is premature —
the interface would be designed from one and a half examples. ~40 lines duplicated:
the b:*_on / b:*_ft override scheme, TextChanged/InsertLeave/BufWinEnter/WinEnter,
ModeChanged i*:* (<C-c> fires no InsertLeave), FileType on every filetype so leaving the
list disables, and the changedtick gate. Each of those was a bug found in mdtable.
NOT copied: OptionSet (no widths, so 'tabstop' is never read) and WinScrolled (marks cover
the whole buffer, not just visible lines). ADDED: ColorScheme.
Extract only if a third plugin arrives.

DETECTION: line scan, same call as mdtable. fence_at() copied verbatim, CommonMark 4.5
rules included — a closing fence carries only its marker, and a backtick fence's info
string may not contain a backtick. Without them a README quoting markdown (this config has
several) tints its code samples. Heading rule is CommonMark 4.2: one to six "#" then
whitespace or EOL, after optional indent/blockquote markers. "#nospace" and "#######" are
not headings; a bare "#" is.
SETEXT HEADINGS NOT SUPPORTED: they need lookahead and "---" collides with a table
separator and a thematic break. Stated in the README rather than half-supported.

TESTS: 47 checks, `nvim -l lua/mdheading/test.lua`. Marks are READ BACK, never recomputed —
mdtable's suite once passed 109 green while the feature drew nothing, and that lesson is
why. Same harness limits: no UI so nothing is painted, no main loop so insert mode is
reached by stubbing mode().
PERFORMANCE: 10k lines with 500 headings renders in 1.2ms (the scan is 0.6ms of it); a
no-op re-render is 1us. No debounce, for the same reason mdtable dropped its.

TERMGUICOLORS is required and is ON (user confirmed `:set termguicolors?` -> "termguicolors").
No ctermbg fallback: 256-colour approximations of six close shades are not six
distinguishable colours. Headless runs report it false because `nvim -l` attaches no UI —
that is the harness, not the config.
KEYMAP: <leader>uH (capital, since <leader>uh is inlay hints), alongside <leader>um.
