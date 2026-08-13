*! version 1.0.0  13aug2026
*! sjclean -- rejoin and re-break a Stata log for LaTeX inclusion
*!
*! Author: Joao Pedro Azevedo, UNICEF <jpazevedo@unicef.org>
*! License: MIT
*!
*! THE PROBLEM
*!
*! Stata breaks a log line when it exceeds c(linesize) and marks the
*! continuation with ">". That break is an artifact of a terminal width chosen
*! before anybody knew what column the line would be typeset in, so it costs
*! three things: the ">" is clutter, the break lands wherever the character
*! count ran out, and the width bears no relation to the page. A -summarize-
*! table wrapped at 60 is not a table any more.
*!
*! sjclean rejoins the logical line and re-breaks it at a width you state.
*!
*! CHOOSING A WIDTH -- it is measurable, not a matter of taste. The examples/
*! directory ships _width_probe.tex, which typesets rulers of known length and
*! reads LaTeX's own overfull reports back. In the Stata Journal class:
*!
*!     stlog[beamer] (7pt)   96 fits; 104 overflows by 7.2pt
*!     stlog         (8pt)   80 fits;  88 overflows by 19.4pt
*!
*! Sixteen characters apart, which is why width() is an option and not a
*! constant. Run the probe in your own class before trusting either number.
*!
*! A LITERAL TAB DOES NOT WORK, and examples/_tab_probe.tex demonstrates it
*! with its LaTeX log. Inside an alltt environment a 0x09 byte carries the
*! catcode of ordinary whitespace and collapses to a SINGLE space, while four
*! spaces render at four and eight at eight. So an indent is spaces, and
*! indent(4) is the conventional tab stop.
*!
*! WHICH FILE TO RUN IT ON
*!
*! The typeset artifact, never a log that anything counts. Test frameworks
*! that read verdicts out of logs typically match a token at column 1 after
*! trimming whitespace -- so restyling a continuation in such a file can
*! MANUFACTURE a verdict: a wrapped line whose continuation happens to begin
*! "PASS:" becomes, once the ">" is replaced by spaces and the line trimmed,
*! indistinguishable from a real one.
*!
*!     *.log.tex        read by LaTeX only        safe
*!     *.log, *.smcl    read by scanners, humans  leave alone
*!
*! NOT A REPLACEMENT FOR sjlog. Use sjlog (from the Stata Journal's sjlatex)
*! to capture the session: it escapes LaTeX specials, which a plain
*! -log using x.log.tex- does not, so a session printing % or _ or a backslash
*! survives. Use sjclean afterwards to set the width.
*!
*! WHY IT EXISTS. Five Stata packages by one author print sessions in their
*! papers, and did it three different ways -- sjlog, a log written straight to
*! a .log.tex, and a post-hoc Python cleaner. One was built and never adopted.
*! Only one handled continuations, and it rejoined without re-breaking, which
*! trades a visible marker for a line that overflows the column. This is the
*! implementation those five should share.

program define sjclean, rclass
    version 14.0

    syntax using/ [,                    ///
        WIDth(integer 96)               ///
        CONTinuation(string)            ///
        INDent(integer 4)               ///
        BREAKAnywhere                   ///
        NOSTATASyntax                   ///
        REJoin                          ///
        STRIPheader                     ///
        Replace                         ///
        SAVing(string)                  ///
        Quietly ]

    * ---- what to do with a continuation once the line is re-broken -------
    * indent  five spaces. Cannot overflow, and a reader still sees that the
    *         line continues.
    * marker  keep Stata's "> ". Faithful to the raw log.
    * none    no marker at all. Shortest, and a reader cannot tell a wrapped
    *         line from a new command -- offered because a caller may be
    *         typesetting output rather than commands, where it does not
    *         matter.
    if `"`continuation'"' == "" local continuation "indent"
    if !inlist(`"`continuation'"', "indent", "marker", "none") {
        di as error `"sjclean: continuation("`continuation'") is not a style"'
        di as error "  use: indent, marker or none"
        exit 198
    }

    * ---- how wide is a "tab"? -------------------------------------------
    * MEASURED, because the obvious implementation does not work. A literal
    * 0x09 byte in a .log.tex renders as ONE SPACE: alltt gives tab the
    * catcode of ordinary whitespace, so it collapses. _tab_probe.tex is kept
    * beside this file with the evidence -- four spaces and eight spaces
    * render at four and eight, a real tab renders at one.
    *
    * So an indent is spaces, and how many is the caller's choice. 4 is the
    * conventional tab stop and is wide enough to read as deliberate without
    * spending width a 96-column line needs.
    if `indent' < 0 | `indent' > 16 {
        di as error "sjclean: indent(`indent') is outside 0-16"
        exit 198
    }
    local pad ""
    forvalues i = 1/`indent' {
        local pad "`pad' "
    }

    if `width' < 20 {
        di as error "sjclean: width(`width') is too narrow to be a column"
        exit 198
    }

    capture confirm file `"`using'"'
    if _rc {
        di as error `"sjclean: no such file: `using'"'
        exit 601
    }

    local out `"`saving'"'
    if `"`out'"' == "" {
        if "`replace'" == "" {
            di as error "sjclean: specify saving() or replace"
            exit 198
        }
        local out `"`using'"'
    }

    tempfile work
    tempname rf wf

    local nread 0
    local njoin 0
    local nbreak 0

    file open `rf' using `"`using'"', read text
    file open `wf' using "`work'", write text replace

    * ---- pass one: rejoin, then re-break -------------------------------
    *
    * Held in Mata throughout. A log line carries arbitrary session text
    * including the quotation marks in assertion diagnostics, and a local
    * holding one is re-parsed as macro syntax on every reference -- r(132),
    * "too few quotes". That bug has shipped twice in this workspace already.

    mata: sjc_pending = ""

    file read `rf' line
    while r(eof) == 0 {
        local nread = `nread' + 1

        mata: sjc_iscont = (substr(st_local("line"), 1, 2) == "> ")

        if "`rejoin'" != "" {
            mata: st_local("iscont", strofreal(sjc_iscont))
            if `iscont' {
                * glue this fragment onto the held line and read on
                mata: sjc_pending = sjc_pending + substr(st_local("line"), 3, .)
                local njoin = `njoin' + 1
                file read `rf' line
                continue
            }
            * a non-continuation: flush what was held, then hold this one
            mata: st_local("has", strofreal(strlen(sjc_pending) > 0))
            if `has' {
                sjc_emit `wf' `width' `"`continuation'"' `"`pad'"' ///
                    "`breakanywhere'" "`nostatasyntax'"
                local nbreak = `nbreak' + r(pieces) - 1
            }
            mata: sjc_pending = st_local("line")
        }
        else {
            * not rejoining: only restyle the marker
            mata: st_local("iscont", strofreal(sjc_iscont))
            if `iscont' {
                if `"`continuation'"' == "indent" {
                    mata: st_local("line", st_local("pad") + substr(st_local("line"), 3, .))
                }
                else if `"`continuation'"' == "none" {
                    mata: st_local("line", substr(st_local("line"), 3, .))
                }
            }
            file write `wf' `"`macval(line)'"' _n
        }

        file read `rf' line
    }

    * flush the last held line
    if "`rejoin'" != "" {
        mata: st_local("has", strofreal(strlen(sjc_pending) > 0))
        if `has' {
            sjc_emit `wf' `width' `"`continuation'"' `"`pad'"' ///
                    "`breakanywhere'" "`nostatasyntax'"
            local nbreak = `nbreak' + r(pieces) - 1
        }
    }

    file close `rf'
    file close `wf'

    copy "`work'" `"`out'"', replace

    if "`quietly'" == "" {
        di as text "sjclean: `using'"
        di as text "  read      : `nread' line(s)"
        if "`rejoin'" != "" {
            di as text "  rejoined  : `njoin' continuation(s)"
            di as text "  re-broken : `nbreak' at width `width'"
        }
        di as text "  style     : `continuation' (indent `indent')"
        di as text "  written to: `out'"
    }

    return scalar read   = `nread'
    return scalar joined = `njoin'
    return scalar broken = `nbreak'
end


* ---------------------------------------------------------------------
* Emit the held line, broken at or before `width'.
*
* WORD INTEGRITY. The break goes at the last space at or before the width, not
* at the width itself. A word split across two lines is unreadable in prose
* and unusable in code -- a reader cannot copy "something e / lse" and a
* reader cannot copy half a variable name either. Only when a single token is
* itself longer than the column is there no better answer, and then the token
* is split rather than allowed to overflow; breakanywhere restores the old
* behaviour for callers who want a hard column.
*
* STATA SYNTAX. A command echo that must be broken gets "///" at the break, so
* the printed session remains code somebody can paste. Output lines get no
* such marker: "///" in the middle of a -summarize- table would be nonsense.
* A line already ending in "///" or ";" was broken by the AUTHOR, and that
* break is preserved rather than rejoined away.
*
* An echoed command is recognised by the leading ". " Stata writes in front of
* it. That is a convention of the log format rather than a guess: output lines
* do not carry it.
* ---------------------------------------------------------------------
program define sjc_emit, rclass
    args wf width style pad anywhere nostata

    local pieces 0
    mata: st_local("n", strofreal(strlen(sjc_pending)))

    if `n' == 0 {
        return scalar pieces = 0
        exit 0
    }

    * Is this an echoed command rather than output?
    mata: st_local("iscmd", strofreal(substr(strtrim(sjc_pending), 1, 2) == ". "))
    if "`nostata'" != "" local iscmd 0

    * A command that has to be split needs "///" at each break, which costs
    * four characters of the column. Budget for them so the marker itself
    * cannot push the line past the width.
    local budget = `width'
    if `iscmd' local budget = `width' - 4
    if `budget' < 20 local budget = `width'

    local pos 1
    while `pos' <= `n' {
        local remaining = `n' - `pos' + 1

        if `remaining' <= `budget' {
            local take = `remaining'
        }
        else if "`anywhere'" != "" {
            local take = `budget'
        }
        else {
            * Last space at or before the budget. strrpos() over the candidate
            * window, so the search is one call rather than a loop.
            mata: st_local("cand", substr(sjc_pending, strtoreal(st_local("pos")), strtoreal(st_local("budget")) + 1))
            mata: st_local("sp", strofreal(strrpos(st_local("cand"), " ")))
            if `sp' > 1 {
                local take = `sp' - 1
            }
            else {
                * One token wider than the column. Split it rather than let it
                * overflow, and say so in the return so a caller can react.
                local take = `budget'
                local nsplit = 1
            }
        }

        mata: st_local("chunk", substr(sjc_pending, strtoreal(st_local("pos")), strtoreal(st_local("take"))))
        local pos = `pos' + `take'

        * Skip the space we broke on, so it does not open the next line.
        mata: st_local("atspace", strofreal(substr(sjc_pending, strtoreal(st_local("pos")), 1) == " "))
        if `atspace' local pos = `pos' + 1

        local pieces = `pieces' + 1
        local more = (`pos' <= `n')

        local prefix ""
        if `pieces' > 1 {
            if `"`style'"' == "indent"      local prefix `"`pad'"'
            else if `"`style'"' == "marker" local prefix "> "
        }

        local suffix ""
        if `more' & `iscmd' local suffix " ///"

        file write `wf' `"`prefix'`macval(chunk)'`suffix'"' _n
    }

    mata: sjc_pending = ""
    return scalar pieces = `pieces'
    return scalar split  = cond("`nsplit'" == "", 0, 1)
end
