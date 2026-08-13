{smcl}
{* *! version 1.0.0  13aug2026}{...}
{vieweralsosee "[R] log" "help log"}{...}
{vieweralsosee "[R] translate" "help translate"}{...}
{viewerjumpto "Syntax" "sjclean##syntax"}{...}
{viewerjumpto "Description" "sjclean##description"}{...}
{viewerjumpto "Options" "sjclean##options"}{...}
{viewerjumpto "Choosing a width" "sjclean##width"}{...}
{viewerjumpto "Which file to run it on" "sjclean##target"}{...}
{viewerjumpto "Before and after" "sjclean##example"}{...}
{viewerjumpto "Stored results" "sjclean##results"}{...}
{viewerjumpto "Author" "sjclean##author"}{...}
{title:Title}

{phang}
{bf:sjclean} {hline 2} Rejoin and re-break a Stata log for LaTeX inclusion


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:sjclean} {cmd:using} {it:filename}{cmd:,}
{c -(}{opt r:eplace}{c |}{opt sav:ing(newfile)}{c )-}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Width}
{synopt:{opt wid:th(#)}}re-break at {it:#} characters; default {cmd:width(96)}{p_end}
{synopt:{opt rej:oin}}rejoin Stata's broken lines before re-breaking{p_end}

{syntab:Continuation style}
{synopt:{opt cont:inuation(style)}}{cmd:indent}, {cmd:marker} or {cmd:none}; default {cmd:indent}{p_end}
{synopt:{opt ind:ent(#)}}spaces of indent under {cmd:continuation(indent)}; default {cmd:indent(4)}{p_end}

{syntab:Output}
{synopt:{opt r:eplace}}overwrite {it:filename} in place{p_end}
{synopt:{opt sav:ing(newfile)}}write to {it:newfile} instead{p_end}
{synopt:{opt q:uietly}}suppress the summary{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sjclean} tidies a Stata log that is about to be typeset.

{pstd}
Stata breaks a log line when it exceeds {help set linesize:c(linesize)} and
marks the continuation with {cmd:>}.  That break is an artifact of a terminal
width chosen before anybody knew what column the line would be printed in, so
it has three costs: the {cmd:>} is clutter, the break lands wherever the
character count happened to run out, and the width bears no relation to the
page.

{pstd}
{cmd:sjclean} rejoins the logical line and re-breaks it at a width you state.


{marker options}{...}
{title:Options}

{dlgtab:Width}

{phang}
{opt width(#)} sets the column at which lines are re-broken.  The default,
{cmd:96}, is the measured capacity of an {cmd:stlog[beamer]} environment in the
Stata Journal class; see {help sjclean##width:Choosing a width}.

{phang}
{opt rejoin} reassembles each logical line before re-breaking it.  Without it
{cmd:sjclean} only restyles the existing continuation markers and leaves
Stata's breaks where they fell.

{pmore}
{bf:With} {cmd:rejoin} the output is broken at {it:your} width.  {bf:Without}
it, the output is still broken at {cmd:c(linesize)} from the original run and
only looks different.

{dlgtab:Continuation style}

{phang}
{opt continuation(indent)} writes {opt indent(#)} spaces at the start of each
continued line.  The default.  It cannot overflow the column, and a reader can
still see that the line continues.

{phang}
{opt continuation(marker)} keeps Stata's {cmd:>}.  Faithful to the raw log,
and the right choice when a reader may want to compare the two.

{phang}
{opt continuation(none)} writes nothing.  Shortest, but a reader cannot
distinguish a continued line from a new command, so it suits output rather
than echoed commands.

{phang}
{opt indent(#)} sets how many spaces {cmd:continuation(indent)} writes, from 0
to 16.  Default {cmd:4}.

{pmore}
{bf:A literal tab does not work, and this is measured rather than assumed.}
A {cmd:0x09} byte inside an {cmd:alltt} environment carries the catcode of
ordinary whitespace and collapses to a {it:single space}.  Rulers typeset in
the Stata Journal class render four spaces at four, eight at eight, and a real
tab at one; {cmd:examples/_tab_probe.tex} ships with its LaTeX log as the
evidence.  So an indent is spaces, and {cmd:indent(4)} is the conventional tab
stop.

{dlgtab:Output}

{phang}
{opt replace} overwrites the input file.  {opt saving(newfile)} writes
elsewhere and leaves the input untouched.  One of the two is required: a
command that silently chose would eventually choose wrong.

{phang}
{opt quietly} suppresses the summary line.


{marker width}{...}
{title:Choosing a width}

{pstd}
The right width is a property of the environment the log will be typeset in,
and it is measurable.  {cmd:examples/_width_probe.tex} typesets rulers of known
length and asks LaTeX to report overfull boxes; the largest ruler with no
report is the capacity.  In the Stata Journal class:

{synoptset 26 tabbed}{...}
{synopt:{it:environment}}{it:capacity}{p_end}
{synoptline}
{synopt:{cmd:stlog[beamer]} (7pt)}96 fits; 104 overflows by 7.2pt{p_end}
{synopt:{cmd:stlog} (8pt)}80 fits; 88 overflows by 19.4pt{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
The two differ by sixteen characters, which is why the width is an option and
not a constant.  Run the probe in your own class before trusting either
number.

{pstd}
Note that {opt continuation(indent)} adds {opt indent(#)} characters to every
continued line, so {cmd:width(96) indent(4)} produces lines of up to 100.
Leave headroom accordingly.


{marker target}{...}
{title:Which file to run it on}

{pstd}
{bf:Run it on the typeset artifact, not on a log that anything counts.}

{pstd}
Test frameworks that read verdicts out of logs typically match a token at
column 1 after trimming whitespace.  Restyling a continuation marker in such a
file can {it:manufacture} a verdict: a wrapped line whose continuation happens
to begin {cmd:PASS:} becomes, after the {cmd:>} is replaced by spaces and the
line is trimmed, indistinguishable from a real one.

{pstd}
So:

{p2colset 9 34 36 2}{...}
{p2col :{it:file}}{it:read by}{p_end}
{p2line}
{p2col :{cmd:*.log.tex}}LaTeX only {hline 2} safe{p_end}
{p2col :{cmd:*.log}, {cmd:*.smcl}}scanners, humans {hline 2} leave alone{p_end}
{p2line}
{p2colreset}{...}


{marker example}{...}
{title:Before and after}

{pstd}
A log written at {cmd:set linesize 80}, where a long assertion message ran off
the end:

{p 8 8 2}{it:before}{p_end}
{p 8 8 2}{res}. stqa_assert `leaked' == 1, msg("noisily no longer overrides set out{p_end}
{p 8 8 2}{res}> put error; the runner limitation may be liftable"){p_end}

{pstd}
The break is at column 80 because the terminal was 80 wide, and it lands in
the middle of {cmd:output}.  After:

{p 8 8 2}{cmd:. sjclean using ex.log.tex, width(96) rejoin replace}{p_end}

{p 8 8 2}{it:after}{p_end}
{p 8 8 2}{res}. stqa_assert `leaked' == 1, msg("noisily no longer overrides set output error; t{p_end}
{p 8 8 2}{res}    he runner limitation may be liftable"){p_end}

{pstd}
The line is now broken at 96 because that is what the column holds, and the
continuation is indented rather than marked.  Nothing was added or removed:
{cmd:sjclean} rejoined what Stata had split and split it again somewhere more
useful.

{pstd}
On one real document this took a set of typeset sessions from 200 continuation
markers to none, with the longest resulting line at 100 characters against a
measured ceiling of about 102.

{pstd}
Restyle only, leaving Stata's breaks alone:

{p 8 8 2}{cmd:. sjclean using ex.log.tex, continuation(indent) indent(8) replace}{p_end}

{pstd}
Re-break for a narrower environment, keeping the familiar marker:

{p 8 8 2}{cmd:. sjclean using ex.log.tex, width(80) rejoin continuation(marker) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:sjclean} stores the following in {cmd:r()}:

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(read)}}lines read from the input{p_end}
{synopt:{cmd:r(joined)}}continuation lines rejoined{p_end}
{synopt:{cmd:r(broken)}}new breaks introduced at {opt width()}{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Jo{c a~}o Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
