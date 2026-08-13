* ----------------------------------------------------------------------
* sjclean regression: a log line carrying Stata's compound quotes.
*
* THE BUG THIS PINS. Until 1.0.1 the chunk being written was lifted into a
* Stata local and written back out as
*
*     file write `wf' `"`prefix'`macval(chunk)'`suffix'"' _n
*
* -macval- stops macro EXPANSION; it does nothing about a quote. So a chunk
* carrying the two characters "' -- which every echoed command using compound
* quotes carries -- closed that compound quote early, and the rest of the line
* was parsed as further arguments. rc 198, and only on files whose sessions
* happened to use compound quotes.
*
* The command's own header had warned about exactly this class since 1.0.0.
* Reading was held in Mata; writing was not. This test exists so the next
* person to touch either half finds out immediately.
* ----------------------------------------------------------------------

clear all
version 14.0

* ---- SAY WHICH sjclean IS UNDER TEST -------------------------------------
* -clear all- drops any program a caller had just loaded, so without this the
* test silently exercises whatever copy is on the adopath -- which is how the
* first run of this very file reported PASS against the unpatched release.
* The build script carries the same announcement for the same reason.
* Relative to examples/, which is where this file lives. No path arithmetic:
* "\" inside a Stata string swallows the closing quote -- r(132), which is the
* very class of bug this file exists to pin.
capture confirm file "../src/s/sjclean.ado"
if !_rc {
    quietly do "../src/s/sjclean.ado"
    local src "../src/s/sjclean.ado"
}
else {
    capture findfile sjclean.ado
    if _rc {
        di as error "test_quotes: sjclean.ado not found -- run from examples/ or install it"
        exit 601
    }
    local src "`r(fn)'"
}
tempname vf
file open `vf' using "`src'", read text
file read `vf' vline
file close `vf'
di as text "test_quotes: exercising `src'"
di as text "             `vline'"

tempfile in
tempname fh

* Lines lifted from a real session -- the ones that actually failed.
file open `fh' using "`in'", write text replace
file write `fh' `". stqa_assert `"`macval(got)'"' == "alpha", msg(`"items:1 read back as "`macval(got)'", expected alpha"')"' _n
file write `fh' `". local got `"`macval(r(value))'"'"' _n
file write `fh' `". di `"a bare compound quote: `"inner"' and a trailing "'"' _n
file write `fh' `"an output line with an apostrophe' and a "quoted phrase" in it"' _n
file close `fh'

local fail 0

* ---- 1. it must not error ------------------------------------------------
capture sjclean using "`in'", width(96) rejoin replace quietly
if _rc {
    di as error "FAIL: sjclean returned rc " _rc " on a log containing compound quotes"
    local fail = `fail' + 1
}
else di as result "PASS: compound quotes do not error"

* ---- 2. and it must not have SILENTLY dropped the text -------------------
* A write that fails half way could leave a shorter file and still return 0
* under some future refactor, so the count is checked rather than assumed.
tempname r2
file open `r2' using "`in'", read text
local n 0
local sawassert 0
file read `r2' l
while r(eof) == 0 {
    local n = `n' + 1
    if strpos(`"`macval(l)'"', "stqa_assert") local sawassert 1
    file read `r2' l
}
file close `r2'

if `n' < 4 {
    di as error "FAIL: expected at least 4 lines out, found `n' -- content was lost"
    local fail = `fail' + 1
}
else di as result "PASS: `n' line(s) survived the round trip"

if !`sawassert' {
    di as error "FAIL: the stqa_assert line is gone from the output"
    local fail = `fail' + 1
}
else di as result "PASS: the compound-quoted command line survived intact"

* ---- 3. the same content, with the option that also writes ---------------
capture sjclean using "`in'", width(40) rejoin replace quietly continuation(marker)
if _rc {
    di as error "FAIL: rc " _rc " when the line must actually be BROKEN at 40"
    local fail = `fail' + 1
}
else di as result "PASS: breaking a compound-quoted line does not error"

di as text ""
if `fail' {
    di as error "test_quotes: `fail' check(s) failed"
    exit 9
}
di as result "test_quotes: all checks passed"
