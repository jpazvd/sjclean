* demo_before_after.do -- what sjclean does, shown rather than described.
*
* Builds a small log at a deliberately narrow linesize so that Stata breaks
* lines the way it does in practice, then prints the same content three ways:
* raw, restyled, and rejoined-and-re-broken. Run it and read the output; the
* difference is the whole documentation.
*
*     do demo_before_after.do
*
* Nothing here needs a network or a dataset beyond what ships with Stata.

version 14.0

* -clear-, NOT -clear all-. The latter drops every program in memory, which
* includes sjclean itself when it has been loaded with -run- from a clone
* rather than installed. A demonstration that erased the command it exists to
* demonstrate is a poor advertisement, and it is the same trap Stata Journal
* build harnesses document about sjlog.
clear
set more off

* Is sjclean available? -which- only searches the adopath, so it says no for a
* command loaded with -run- straight from a clone -- which is exactly how
* somebody reads this repository for the first time. Ask Stata whether the
* command exists instead: rc 199 is "unrecognized", anything else means it
* parsed and objected to the empty syntax, which is a yes.
capture sjclean
if _rc == 199 {
    display as error "sjclean is not available. Either install it:"
    display as error `"    net install sjclean, from("https://raw.githubusercontent.com/jpazvd/sjclean/main/src") replace"'
    display as error "or load it from a clone:"
    display as error `"    run src/s/sjclean.ado"'
    exit 199
}

tempfile raw restyled rejoined

* ---------------------------------------------------------------------
* A log with lines long enough to wrap. linesize 60 is narrow on purpose:
* it makes the effect visible in a demonstration without needing a 200-
* character command to trigger it.
* ---------------------------------------------------------------------

set linesize 60

quietly log using "`raw'", text replace name(demo)
display as text "A short line."
display as text "A considerably longer line that Stata will break because it exceeds the current linesize setting."
sysuse auto, clear
summarize price mpg
display as text "Another long one, this time containing a quoted fragment: the value was ""3291"" and not something else."
quietly log close demo

* ---------------------------------------------------------------------
* Three treatments of the same file.
* ---------------------------------------------------------------------

quietly copy "`raw'" "`restyled'", replace
quietly copy "`raw'" "`rejoined'", replace

* Wide again BEFORE printing anything. The log above was written at 60 to
* make Stata wrap it; leaving the terminal at 60 while displaying the result
* would have Stata re-wrap the cleaned lines on their way to the screen, and
* the demonstration would show its own display wrapping rather than sjclean's
* work. A before/after that cannot be read is not a demonstration.
set linesize 120

sjclean using "`restyled'", continuation(indent) indent(4) replace
sjclean using "`rejoined'", width(96) rejoin continuation(indent) indent(4) replace

* ---------------------------------------------------------------------
* Print all three, so the reader compares rather than takes it on trust.
* ---------------------------------------------------------------------

capture program drop _show
program define _show
    args f label
    display as text ""
    display as result "{hline 70}"
    display as result "`label'"
    display as result "{hline 70}"
    tempname h
    file open `h' using "`f'", read text
    file read `h' line
    while r(eof) == 0 {
        * Mata: a log line carries arbitrary text, and re-parsing one as macro
        * syntax is r(132) the first time it contains an unbalanced quote.
        mata: st_local("shown", st_local("line"))
        display as text `"`macval(shown)'"'
        file read `h' line
    }
    file close `h'
end

_show "`raw'"      "BEFORE -- as Stata wrote it (linesize 60, '>' continuations)"
_show "`restyled'" "RESTYLED -- continuation(indent): marker replaced, breaks unchanged"
_show "`rejoined'" "AFTER -- rejoin + width(96): lines reassembled, re-broken at 96"

display as text ""
display as text "Note the difference between the second and third."
display as text "Restyling only changes how a break LOOKS. Rejoining changes"
display as text "WHERE it falls -- at the width you asked for, rather than at"
display as text "whatever c(linesize) happened to be when the log was written."
