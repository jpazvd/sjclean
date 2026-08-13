*! version 0.1.0  13aug2026
*! sjclean -- tidy a Stata log for LaTeX inclusion, with the wrap width as a
*! stated choice rather than an accident of c(linesize)
*!
*! WHY THIS EXISTS
*!
*! Five papers in this workspace print Stata sessions and do it three
*! different ways: -sjlog- (StataQA, datalib, wbopendata), a direct log
*! written straight to .log.tex (unicefData's generate_sjlogs_v2.do), and a
*! post-hoc cleaner (data360's clean_logs.py, the only one in production that
*! handles continuations). One of the three was built and never adopted. This
*! command is the one implementation those five should share.
*!
*! THE PROBLEM IT SOLVES
*!
*! Stata breaks a log line at c(linesize) and marks the continuation with ">".
*! The break is therefore an artifact of a terminal width, chosen before
*! anybody knew what column the line would be typeset in. Three consequences:
*! the ">" is clutter, the break lands mid-token, and the width has no
*! relation to the page.
*!
*! sjclean rejoins the logical line and re-breaks it at a width you state.
*!
*! WHAT WIDTH? Measured, not guessed. Rulers of known length typeset inside
*! the article's own class (see _width_probe.tex, kept beside this file with
*! its LaTeX log as evidence):
*!
*!     stlog[beamer]   96 fits; 104 overflows by 7.2pt   -> width(96)
*!     stlog           80 fits; 88 overflows by 19.4pt   -> width(80)
*!
*! The two differ by sixteen characters, which is why the width is an option
*! and not a constant.
*!
*! WHAT IT WILL NOT DO
*!
*! It does not touch a log that anything counts. stqa_scanlog matches a
*! verdict token at column 1 after trimming, so rewriting a continuation
*! marker in a file a scanner reads can manufacture a verdict out of line
*! width -- a wrapped line whose continuation begins "PASS: " would be counted
*! as a real one. Run this on the .log.tex, which only LaTeX reads.

program define sjclean, rclass
    version 14.0

    syntax using/ [,                    ///
        WIDth(integer 96)               ///
        CONTinuation(string)            ///
        INDent(integer 4)               ///
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
                sjc_emit `wf' `width' `"`continuation'"' `"`pad'"'
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
            sjc_emit `wf' `width' `"`continuation'"' `"`pad'"'
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
* Emit the held line, broken at `width', with continuations styled.
*
* Breaks at the width and not at a word boundary, deliberately. This is code
* and output, not prose: a break inside a token is what Stata itself does,
* and moving the break to the previous space would silently change the column
* a reader counts to. Where the content is a long quoted string the difference
* is invisible; where it is a table, it matters.
* ---------------------------------------------------------------------
program define sjc_emit, rclass
    args wf width style pad

    local pieces 0
    mata: st_local("n", strofreal(strlen(sjc_pending)))

    if `n' == 0 {
        return scalar pieces = 0
        exit 0
    }

    local pos 1
    while `pos' <= `n' {
        mata: st_local("chunk", substr(sjc_pending, strtoreal(st_local("pos")), strtoreal(st_local("width"))))
        local pieces = `pieces' + 1

        if `pieces' == 1 {
            file write `wf' `"`macval(chunk)'"' _n
        }
        else {
            if `"`style'"' == "indent" {
                file write `wf' `"`pad'`macval(chunk)'"' _n
            }
            else if `"`style'"' == "marker" {
                file write `wf' `"> `macval(chunk)'"' _n
            }
            else {
                file write `wf' `"`macval(chunk)'"' _n
            }
        }

        local pos = `pos' + `width'
    }

    mata: sjc_pending = ""
    return scalar pieces = `pieces'
end
