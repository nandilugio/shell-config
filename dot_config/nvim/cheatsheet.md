# Normal Mode

## Motions

{maybe-count}{motion}
Can be used in Visual Mode.

h,j,k,l         arrow-like movement

w,e,b           (w)ord motions, also (e)nd and (b)ack
W,E,B           same but with WORDS (chars separated by space)

f,F {char}      find next (f) or prev (F) {char} in line
t,T {char}      find next (f) or prev (F) {char} in line, place cursor before it
; and ,         go next and previous occurrence of {char}

0,$             start and end of line
_ or ^          first non-blank of line
Enter           first non-blank of next line

{,}             previous and next paragraph

%               find matching "bracket" ([{<...

H,M,L           move in the screen to a (H)igh, (M)id or (L)ow position

gg              (g)o start of file
{line} G or gg  (G)o to {line}
G               (G)o end of file

/,? {regex}     search forwards and backwards for {regex}
/,?             repeat last search forwards and backwards
n,N             (n)ext and previous match

## Operators

{operator}{maybe-count}{motion}
{operator}{maybe-count}{same-operator} to apply to line

d,dd,D          (d)elete motion, line(s) and to end of line
c,cc,C          (c)hange motion, line(s) and to end of line
y,yy or Y       (y)ank motion and line(s)
g~,g~~          switch case of motion and line(s)
\ >,>>          indent line(s)
<,<<            dedent line(s)
=,==            format motion and line(s)

## Char Operators

{count}{cchar-operator}

x,X             delete char(s) under and before cursor
s               (s)ubstitute char(s) under cursor
~               switch case of char(s) under cursor

## Cut, Copy and Paste

del operators   deleting operators "cut"
y               (y)ank operator "copies"

p,P             (p)ut or paste after and before cursor

## Scrolling

Ctrl-U,-D       (U)p and (D)own half page
