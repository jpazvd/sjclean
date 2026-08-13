* ----------------------------------------------------------------------
* Every option sjclean documents, exercised for EFFECT rather than parsing.
*
* A test that only confirms an option is accepted proves that -syntax- parsed
* it, which is a claim about Stata rather than about this command. It would
* pass just as happily against an option that is read and then ignored -- and
* this package shipped exactly that: -stripheader- sat in the syntax line
* through two releases without a single reference in the body.
*
* So each check below runs the command BOTH ways and requires the results to
* differ.
*
* Everything is measured in Mata. A log line is arbitrary session text and
* lifting one into a Stata local re-parses it as macro syntax -- the bug that
* accounted for every defect found in this package on 13aug2026.
* ----------------------------------------------------------------------

clear all
version 14.0

capture confirm file "../src/s/sjclean.ado"
if !_rc {
    quietly do "../src/s/sjclean.ado"
    local src "../src/s/sjclean.ado"
}
else {
    quietly findfile sjclean.ado
    local src "`r(fn)'"
}
tempname vf
file open `vf' using "`src'", read text
file read `vf' vline
file close `vf'
di as text "test_options: exercising `src'"
di as text "              `vline'"

capture mata: mata drop sjo_max()
capture mata: mata drop sjo_pre()
capture mata: mata drop sjo_exact()
capture mata: mata drop sjo_has()
mata:
real scalar sjo_max(string scalar fn)
{
    real scalar i, m
    string colvector v
    if (!fileexists(fn)) return(-1)
    v = cat(fn)
    m = 0
    for (i = 1; i <= rows(v); i++) m = max((m, strlen(v[i])))
    return(m)
}
real scalar sjo_pre(string scalar fn, string scalar tok)
{
    real scalar i, n
    string colvector v
    if (!fileexists(fn)) return(-1)
    v = cat(fn)
    n = 0
    for (i = 1; i <= rows(v); i++) if (substr(v[i], 1, strlen(tok)) == tok) n++
    return(n)
}
real scalar sjo_exact(string scalar fn, real scalar w)
{
    real scalar i, n
    string colvector v
    if (!fileexists(fn)) return(-1)
    v = cat(fn)
    n = 0
    for (i = 1; i <= rows(v); i++) if (strlen(v[i]) == w) n++
    return(n)
}
real scalar sjo_has(string scalar fn, string scalar tok)
{
    real scalar i
    string colvector v
    if (!fileexists(fn)) return(-1)
    v = cat(fn)
    for (i = 1; i <= rows(v); i++) if (strpos(v[i], tok) > 0) return(1)
    return(0)
}
end

* -clear all- does NOT drop global macros. Without this line $sjo_fail
* survives from a previous failing run in the same Stata session and the file
* exits 9 while every check on screen says PASS -- a false RED, which is the
* same class of lie as a false green and just as confusing to whoever reads
* only the tail of the log.
global sjo_fail 0

* -args- splits its argument list on whitespace, so it cannot take an
* expression or a label containing spaces -- the first draft of this helper
* did both and the file would not parse. -gettoken- respects quoting.
program define sjo_check
    gettoken ok rest : 0
    gettoken lbl rest : rest
    if `ok' {
        di as result `"PASS: `lbl'"'
    }
    else {
        di as error `"FAIL: `lbl'"'
        global sjo_fail = 1
    }
end

* ---- the fixture ------------------------------------------------------
* One long command echo (so ///-insertion is exercised), one long output
* line, and one machine path (so anonymize is exercised).
tempfile src0
tempname fh
file open `fh' using "`src0'", write text replace
file write `fh' `". summarize price mpg weight length turn displacement gear_ratio foreign rep78 headroom trunk"' _n
file write `fh' "an output line that is quite deliberately much longer than any sensible column width so that it must be broken somewhere by the command" _n
file write `fh' "reading data from C:\Users\someone\AppData\Local\Temp\worker_9f3a\ST_0001.tmp now" _n
file close `fh'

* =====================================================================
* width() -- the column actually changes
* =====================================================================
tempfile o1 o2
capture sjclean using "`src0'", width(40) rejoin saving("`o1'") quietly
local rc1 = _rc
capture sjclean using "`src0'", width(90) rejoin saving("`o2'") quietly
local rc2 = _rc
mata: st_local("m1", strofreal(sjo_max(st_local("o1"))))
mata: st_local("m2", strofreal(sjo_max(st_local("o2"))))
local ok = (`rc1'==0 & `rc2'==0 & `m1' < `m2' & `m2' <= 94)
sjo_check `ok' "width() sets the column (`m1' vs `m2')"
* =====================================================================
* rejoin -- without it, the original breaks survive
* =====================================================================
* Feed a file that ALREADY carries Stata's ">" continuations.
tempfile wrapped
file open `fh' using "`wrapped'", write text replace
file write `fh' "a line that stata already broke once because it exceeded the linesize in force" _n
file write `fh' "> and here is the remainder of that same logical line" _n
file close `fh'
tempfile o3 o4
capture sjclean using "`wrapped'", width(200) rejoin saving("`o3'") quietly
capture sjclean using "`wrapped'", width(200) saving("`o4'") quietly
mata: st_local("n3", strofreal(rows(cat(st_local("o3")))))
mata: st_local("n4", strofreal(rows(cat(st_local("o4")))))
local ok = (`n3' == 1 & `n4' == 2)
sjo_check `ok' "rejoin reassembles the logical line (`n3' vs `n4' lines)"
* =====================================================================
* continuation() and indent()
* =====================================================================
tempfile oi om onn oi8
capture sjclean using "`src0'", width(40) rejoin continuation(indent) indent(4) saving("`oi'") quietly
capture sjclean using "`src0'", width(40) rejoin continuation(marker)             saving("`om'") quietly
capture sjclean using "`src0'", width(40) rejoin continuation(none)               saving("`onn'") quietly
capture sjclean using "`src0'", width(40) rejoin continuation(indent) indent(8) saving("`oi8'") quietly
mata: st_local("cm", strofreal(sjo_pre(st_local("om"), "> ")))
mata: st_local("ci", strofreal(sjo_pre(st_local("oi"), "    ")))
mata: st_local("cn", strofreal(sjo_pre(st_local("onn"), " ")))
mata: st_local("c8", strofreal(sjo_pre(st_local("oi8"), "        ")))
local ok = (`cm' > 0)
sjo_check `ok' "continuation(marker) keeps the > marker (`cm')"
local ok = (`ci' > 0 & `cn' == 0)
sjo_check `ok' "continuation(indent) indents, none does not (`ci'/`cn')"
local ok = (`c8' > 0)
sjo_check `ok' "indent(8) widens the indent (`c8')"
* =====================================================================
* breakanywhere -- words split only when asked
* =====================================================================
tempfile ow ob
capture sjclean using "`src0'", width(40) rejoin continuation(none) saving("`ow'") quietly
capture sjclean using "`src0'", width(40) rejoin continuation(none) breakanywhere saving("`ob'") quietly
* Counted, not measured by maximum. The first draft compared the LONGEST line
* under each setting and failed: both came to 40, because a different line in
* the fixture happened to break at a space exactly on the column. The longest
* line is a property of the fixture; what the option actually changes is how
* MANY lines are filled right to the column, since the default backs up to the
* last space and so usually stops short.
mata: st_local("mw", strofreal(sjo_max(st_local("ow"))))
mata: st_local("mb", strofreal(sjo_max(st_local("ob"))))
mata: st_local("ew", strofreal(sjo_exact(st_local("ow"), 40)))
mata: st_local("eb", strofreal(sjo_exact(st_local("ob"), 40)))
local ok = (`mw' <= 40 & `mb' == 40 & `eb' > `ew')
sjo_check `ok' "breakanywhere fills the column (`eb' full lines) where the default backs up to a space (`ew')"
* =====================================================================
* nostatasyntax -- /// on a broken command echo, and not otherwise
* =====================================================================
tempfile os ons
capture sjclean using "`src0'", width(40) rejoin saving("`os'")  quietly
capture sjclean using "`src0'", width(40) rejoin nostatasyntax saving("`ons'") quietly
mata: st_local("hs",  strofreal(sjo_has(st_local("os"),  "///")))
mata: st_local("hns", strofreal(sjo_has(st_local("ons"), "///")))
local ok = (`hs' == 1 & `hns' == 0)
sjo_check `ok' "/// is added to a broken command echo, and nostatasyntax removes it"
* =====================================================================
* anonymisation is the DEFAULT, and noanonymize turns it off
* =====================================================================
tempfile oa op onone
capture sjclean using "`src0'", width(200) rejoin noanonymize saving("`onone'") quietly
capture sjclean using "`src0'", width(200) rejoin            saving("`oa'")    quietly
local rca = _rc
local nanon = r(anon)
capture sjclean using "`src0'", width(200) rejoin placeholder("<REDACTED>") saving("`op'") quietly
mata: st_local("k0", strofreal(sjo_has(st_local("onone"), "AppData")))
mata: st_local("k1", strofreal(sjo_has(st_local("oa"),    "AppData")))
mata: st_local("k2", strofreal(sjo_has(st_local("oa"),    "<path>")))
mata: st_local("k3", strofreal(sjo_has(st_local("oa"),    "ST_0001.tmp")))
mata: st_local("k4", strofreal(sjo_has(st_local("op"),    "<REDACTED>")))
local ok = (`k1' == 0)
sjo_check `ok' "DEFAULT strips the machine path with no option given"
local ok = (`k0' == 1)
sjo_check `ok' "noanonymize keeps it -- so the default is doing the work"
local ok = (`k2' == 1)
sjo_check `ok' "the placeholder is left in its place"
local ok = (`k3' == 1)
sjo_check `ok' "the filename survives, which leaks nothing"
local ok = (`k4' == 1)
sjo_check `ok' "placeholder() changes the replacement text"
local ok = (`rca' == 0 & `nanon' == 1)
sjo_check `ok' "r(anon) counts the paths stripped (`nanon')"
* a relative path must SURVIVE -- it is safe and informative
tempfile rel orel
file open `fh' using "`rel'", write text replace
file write `fh' "written to qa/logs/test_data_stqa.log and read back" _n
file close `fh'
capture sjclean using "`rel'", width(200) rejoin saving("`orel'") quietly
mata: st_local("k5", strofreal(sjo_has(st_local("orel"), "qa/logs/test_data_stqa.log")))
local ok = (`k5' == 1)
sjo_check `ok' "a RELATIVE path is left alone even under the default"
* ---- what the default does to a real -log using- banner ---------------
* Documented by TEST rather than by claim, because it is exactly half a job:
* the banner path goes, the TIMESTAMP stays. Stripping a timestamp is a
* determinism concern rather than a disclosure one, and sjclean does not do
* it. In the sjlog workflow the question is moot -- -quietly log using-
* suppresses the banner before sjclean ever sees the file.
tempfile hdr ohdr
file open `fh' using "`hdr'", write text replace
file write `fh' "       name:  <unnamed>" _n
file write `fh' `"        log:  C:\Users\jsmith\project\run.log"' _n
file write `fh' "   log type:  text" _n
file write `fh' "  opened on:  13 Aug 2026, 10:44:06" _n
file close `fh'
capture sjclean using "`hdr'", width(200) rejoin saving("`ohdr'") quietly
mata: st_local("h1", strofreal(sjo_has(st_local("ohdr"), "jsmith")))
mata: st_local("h2", strofreal(sjo_has(st_local("ohdr"), "run.log")))
mata: st_local("h3", strofreal(sjo_has(st_local("ohdr"), "opened on")))
local ok = (`h1' == 0 & `h2' == 1)
sjo_check `ok' "a log banner's path is stripped to its filename"
local ok = (`h3' == 1)
sjo_check `ok' "the banner TIMESTAMP survives -- sjclean does not strip headers"
* =====================================================================
* quietly -- the summary is the observable behaviour
* =====================================================================
tempfile lq ll oq ol
quietly log using "`ll'", text replace name(sjoq)
sjclean using "`src0'", width(90) rejoin saving("`ol'")
quietly log close sjoq
quietly log using "`lq'", text replace name(sjoq)
sjclean using "`src0'", width(90) rejoin saving("`oq'") quietly
quietly log close sjoq
mata: st_local("sl", strofreal(sjo_has(st_local("ll"), "sjclean:")))
mata: st_local("sq", strofreal(sjo_has(st_local("lq"), "sjclean:")))
local ok = (`sl' == 1 & `sq' == 0)
sjo_check `ok' "quietly suppresses the summary, and without it the summary prints"
* =====================================================================
* replace vs saving() -- and the refusal to guess
* =====================================================================
tempfile rp
copy "`src0'" "`rp'", replace
mata: st_local("b4", strofreal(sjo_max(st_local("rp"))))
capture sjclean using "`rp'", width(40) rejoin replace quietly
mata: st_local("af", strofreal(sjo_max(st_local("rp"))))
local ok = (`b4' > `af' & `af' <= 44)
sjo_check `ok' "replace rewrites the input in place (`b4' -> `af')"
tempfile keep okeep
copy "`src0'" "`keep'", replace
capture sjclean using "`keep'", width(40) rejoin saving("`okeep'") quietly
mata: st_local("kp", strofreal(sjo_max(st_local("keep"))))
local ok = (`kp' == `b4')
sjo_check `ok' "saving() leaves the input untouched"
* =====================================================================
* the error paths -- each must be REFUSED, not quietly tolerated
* =====================================================================
capture sjclean using "`src0'", width(40) rejoin
local ok = (_rc == 198)
sjo_check `ok' "neither replace nor saving() is refused (rc `=_rc')"
capture sjclean using "`src0'", width(5) rejoin replace
local ok = (_rc == 198)
sjo_check `ok' "width() below 20 is refused (rc `=_rc')"
capture sjclean using "`src0'", width(40) indent(99) rejoin replace
local ok = (_rc == 198)
sjo_check `ok' "indent() outside 0-16 is refused (rc `=_rc')"
capture sjclean using "`src0'", width(40) continuation(sideways) rejoin replace
local ok = (_rc == 198)
sjo_check `ok' "an unknown continuation() style is refused (rc `=_rc')"
capture sjclean using "no_such_file_xyz.log.tex", width(40) rejoin replace
local ok = (_rc == 601)
sjo_check `ok' "a missing input is refused with 601 (rc `=_rc')"
capture sjclean using "`src0'", width(40) placeholder("<x>") noanonymize rejoin saving("`o1'")
local ok = (_rc == 198)
sjo_check `ok' "placeholder() with noanonymize is refused as contradictory (rc `=_rc')"

* =====================================================================
* The path table -- every shape, and what must happen to each.
*
* Written as a table because the rule has three interacting parts and each
* was got wrong once: what counts as a root, how much evidence a root needs
* before the token is a path, and whether the last segment is kept.
*
* 2.0.0 shipped two defects this table would have caught on day one:
*   /home/jsmith  ->  <path>/jsmith   the USERNAME survived as a pseudo-file
*   Z:/datalib    ->  untouched       a share root was left in an artifact
* =====================================================================
tempfile pin pout
file open `fh' using "`pin'", write text replace
file write `fh' `"A C:\Users\jsmith\AppData\Local\Temp\w\ST_1.tmp"' _n
file write `fh' `"B /Users/jsmith/Library/CloudStorage/OneDrive-ORG/x.dta"' _n
file write `fh' `"C Z:/datalib"' _n
file write `fh' `"D /home/jsmith"' _n
file write `fh' `"E C:/Windows"' _n
file write `fh' `"F qa/logs/test_data_stqa.log"' _n
file write `fh' `"G the /// continuation and a bare / slash"' _n
file write `fh' `"H \begin{stlog} and \smallskip"' _n
file write `fh' `"I C:\projects\study2024\analysis\master.do"' _n
* LaTeX escapes, which sjlog writes and which are NOT paths. "%%" becomes
* "\%\%" -- two backslashes, enough to pass a naive separator count -- and
* 2.1.0 turned the paper build's own excerpt markers into "<path>".
file write `fh' `"J \%\%EXCERPT-BEGIN sample"' _n
file write `fh' `"K a tempvar \_\_000000 and an escaped \& ampersand"' _n
file close `fh'
capture sjclean using "`pin'", width(400) rejoin saving("`pout'") quietly

* A path naming a FILE keeps its filename.
mata: st_local("p1", strofreal(sjo_has(st_local("pout"), "<path>/ST_1.tmp")))
mata: st_local("p2", strofreal(sjo_has(st_local("pout"), "<path>/x.dta")))
mata: st_local("p3", strofreal(sjo_has(st_local("pout"), "<path>/master.do")))
local ok = (`p1' & `p2' & `p3')
sjo_check `ok' "a path naming a file keeps the filename and loses the directory"

* A path naming a DIRECTORY keeps nothing -- the last segment is a directory
* name, and directory names are what leak.
mata: st_local("q1", strofreal(sjo_has(st_local("pout"), "jsmith")))
mata: st_local("q2", strofreal(sjo_has(st_local("pout"), "datalib")))
mata: st_local("q3", strofreal(sjo_has(st_local("pout"), "Windows")))
local ok = (`q1' == 0 & `q2' == 0 & `q3' == 0)
sjo_check `ok' "a directory path is removed whole -- no username, share root or folder survives"

* Relative paths and Stata/LaTeX syntax must come through untouched.
mata: st_local("r1", strofreal(sjo_has(st_local("pout"), "qa/logs/test_data_stqa.log")))
mata: st_local("r2", strofreal(sjo_has(st_local("pout"), "///")))
mata: st_local("r3", strofreal(sjo_has(st_local("pout"), "\begin{stlog}")))
mata: st_local("r4", strofreal(sjo_has(st_local("pout"), "\smallskip")))
local ok = (`r1' & `r2' & `r3' & `r4')
sjo_check `ok' "relative paths, ///, and LaTeX control sequences are left alone"

* The escapes sjlog actually emits. A real path segment starts with a letter
* or a digit; "\%" and "\_" do not, however many backslashes precede them.
mata: st_local("s1", strofreal(sjo_has(st_local("pout"), "EXCERPT-BEGIN sample")))
mata: st_local("s2", strofreal(sjo_has(st_local("pout"), "000000")))
local ok = (`s1' & `s2')
sjo_check `ok' "LaTeX escapes (\%\%, \_\_) survive -- two backslashes do not make a path"


* =====================================================================
* A source "///" must not survive into the middle of a joined command.
*
* Stata marks the continuation of a "///" command with ">", exactly as it
* marks a linesize wrap. Until 2.2.0 rejoin glued the two and left the
* author's "///" mid-line -- and everything after "///" is a COMMENT, so the
* printed command silently lost its tail. The session on the page and the
* session that ran were different programs.
* =====================================================================
tempfile cin cout
file open `fh' using "`cin'", write text replace
file write `fh' `". capture noisily stqa_assert `nunion' == 2225, ///"' _n
file write `fh' `">         msg("union is missing for 368 respondents")"' _n
file close `fh'
capture sjclean using "`cin'", width(400) rejoin saving("`cout'") quietly

* Joined onto one line, and the msg() must still be part of the COMMAND --
* which means no "///" may stand between the comma and it.
mata: st_local("nrow", strofreal(rows(cat(st_local("cout")))))
mata: st_local("cline", cat(st_local("cout"))[1])
mata: st_local("mid", strofreal(strpos(st_local("cline"), "///") > 0))
mata: st_local("hasmsg", strofreal(strpos(st_local("cline"), "msg(") > 0))
local ok = (`nrow' == 1 & `mid' == 0 & `hasmsg' == 1)
sjo_check `ok' "a source /// is dropped when its two lines are joined, keeping msg() in the command"

* At a width that forces a break, the /// comes back -- because now there IS
* a break for it to mark, and the command must stay runnable.
tempfile cout2
capture sjclean using "`cin'", width(48) rejoin saving("`cout2'") quietly
mata: st_local("n2", strofreal(rows(cat(st_local("cout2")))))
mata: st_local("c2", cat(st_local("cout2"))[1])
mata: st_local("end2", strofreal(substr(strrtrim(st_local("c2")), strlen(strrtrim(st_local("c2"))) - 2, 3) == "///"))
local ok = (`n2' > 1 & `end2' == 1)
sjo_check `ok' "and a /// is re-added at a break sjclean introduces, at the END of the line"

di as text ""
if "$sjo_fail" == "1" {
    di as error "test_options: FAILURES ABOVE"
    exit 9
}
di as result "test_options: every option changed behaviour as documented"
