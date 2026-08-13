{smcl}
{* *! version 2.0.0  13aug2026}{...}
{vieweralsosee "[R] log" "help log"}{...}
{vieweralsosee "[R] translate" "help translate"}{...}
{viewerjumpto "Syntax" "sjclean##syntax"}{...}
{viewerjumpto "Description" "sjclean##description"}{...}
{viewerjumpto "Options" "sjclean##options"}{...}
{viewerjumpto "Choosing a width" "sjclean##width"}{...}
{viewerjumpto "Machine paths" "sjclean##anon"}{...}
{viewerjumpto "Which file to run it on" "sjclean##target"}{...}
{viewerjumpto "Before and after" "sjclean##example"}{...}
{viewerjumpto "Stored results" "sjclean##results"}{...}
{viewerjumpto "Requirements" "sjclean##deps"}{...}
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

{syntab:Machine paths}
{synopt:{opt noanon:ymize}}{bf:keep} absolute paths; they are stripped by default{p_end}
{synopt:{opt place:holder(string)}}text put in place of a stripped directory; default {cmd:<path>}{p_end}

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

{dlgtab:Machine paths}

{phang}
{opt noanonymize} keeps absolute paths.  They are {bf:stripped by default} --
see {help sjclean##anon:Machine paths} for what is removed and why the default
runs that way.

{phang}
{opt placeholder(string)} sets the text written in place of a stripped
directory.  Default {cmd:<path>}.  Specifying it together with
{opt noanonymize} is an error rather than a silent no-op: the two options
contradict each other.

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



{marker anon}{...}
{title:Machine paths}

{pstd}
{bf:The directory part of every absolute path is replaced by default.}  A log
written on a real machine carries real machine paths:

{p 8 8 2}{res}. use "C:\Users\jsmith\AppData\Local\Temp\stata_worker_7505d\ST_73b0.tmp"{p_end}
{p 8 8 2}{res}. merge 1:1 iso3 using "\10.0.4.21\research\admin\salaries.dta"{p_end}

{pstd}
which leaks, in ascending order of seriousness, a {it:username}, a {it:machine
layout}, and the {it:topology of an internal network} -- server names, share
names, IP addresses.  The last is a security matter rather than a tidiness one,
and it is at its worst precisely when the log is stored somewhere shared.

{pstd}
The {bf:filename is kept}, because it is the part a reader needs and the part
that leaks nothing:

{p 8 8 2}{res}. use "<path>/ST_73b0.tmp"{p_end}
{p 8 8 2}{res}. merge 1:1 iso3 using "<path>/salaries.dta"{p_end}

{pstd}
{bf:Relative paths are left alone.}  {cmd:qa/logs/test_data_stqa.log} tells a
reader where to look in the repository and tells an attacker nothing.

{pstd}
{bf:Why it is the default.}  The failure mode of a default has to point in the
harmless direction.  An author who forgets an option should end up with a safe
artifact and slightly less information, never an unsafe one.  {opt noanonymize}
keeps the paths when that is what you want.

{pstd}
{bf:Detection is structural, not a list of known roots.}  A token is an
absolute path when it is {it:rooted} -- a drive letter followed by a separator,
or a leading separator -- {it:and} carries at least one further separator, so
that there is a directory to remove.  No usernames, hostnames, cloud providers
or drive letters appear anywhere in the logic, so it cannot depend on anyone
having guessed the right ones in advance.  The second condition is what keeps
{cmd:///}, a bare {cmd:/} and control sequences from being mistaken for paths.

{pstd}
{bf:It is not a header stripper.}  Given Stata's log banner it removes the path
and {it:leaves the timestamp}, which is a determinism concern rather than a
disclosure one.  In the {cmd:sjlog} workflow the question does not arise:
{cmd:quietly log using} suppresses the banner before {cmd:sjclean} sees the
file.


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
{p 8 8 2}{res}. stqa_assert `leaked' == 1, msg("noisily no longer overrides set output ///{p_end}
{p 8 8 2}{res}    error; the runner limitation may be liftable"){p_end}

{pstd}
The line is now broken at 96 because that is what the column holds; the break
falls at a {it:space} rather than mid-word; and because this is an echoed
command rather than output, {cmd:///} was added so the printed session is still
code a reader can paste.

{pstd}
{synoptset 20 tabbed}{...}
{synopt:{opt breaka:nywhere}}break at exactly {opt width()}, splitting words{p_end}
{synopt:{opt nostatas:yntax}}never add {cmd:///}, even to a command echo{p_end}
{p2colreset}{...}

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
{synopt:{cmd:r(anon)}}absolute paths whose directory was stripped{p_end}
{p2colreset}{...}


{marker deps}{...}
{title:Requirements and dependencies}

{pstd}
{cmd:sjclean} itself needs nothing but Stata 14.  It reads a text file and
writes a text file.

{pstd}
{bf:The workflow it belongs to needs the Stata Journal's editorial ados}, and
that is where the dependency sits.  {cmd:sjlog} captures a session into a
{cmd:.log.tex}; {cmd:statapress.cls}, {cmd:sj.sty}, {cmd:stata.sty} and
{cmd:pagedims.sty} typeset it and are what the shipped width probes compile
against.  All come from {cmd:sjlatex}:

{p 8 8 2}
{cmd:. net install sjlatex, from("http://www.stata-journal.com/production")}

{pstd}
The editorial package, its documentation and the author guidelines are at
{browse "https://www.stata-journal.com/production/":www.stata-journal.com/production}.

{pstd}
{cmd:sjclean} is downstream of {cmd:sjlog} and not a replacement for it.  Use
{cmd:sjlog} to capture --- it escapes LaTeX specials, which a plain
{cmd:log using x.log.tex} does not, so a session printing {cmd:%} or {cmd:_} or
a backslash survives --- then {cmd:sjclean} to set the width:

{p 8 8 2}{cmd:. sjlog do myexample, replace}{p_end}
{p 8 8 2}{cmd:. sjclean using myexample.log.tex, width(96) rejoin replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Jo{c a~}o Pedro Azevedo{break}
UNICEF{break}
jpazevedo@unicef.org
