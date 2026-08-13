*! version 2.1.1  13aug2026
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
*! PATHS ARE STRIPPED BY DEFAULT. A log written on a real machine carries
*! real machine paths -- a temp directory under a username, a UNC share, a
*! cloud-sync folder -- and this command exists to prepare a log for
*! PUBLICATION. So the directory part of every ABSOLUTE path is replaced with
*! <path>/ and only the filename is kept; relative paths, which are safe and
*! informative, are untouched. -noanonymize- turns it off.
*!
*! The default is the safe one on purpose: an author who forgets an option
*! should get a safe artifact and slightly less information, never an unsafe
*! one. Detection is STRUCTURAL -- rooted, plus at least one more separator --
*! not a list of known roots, so it does not depend on anybody having guessed
*! the right drive letters, usernames or cloud providers in advance.
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
        NOANONymize                     ///
        PLACEholder(string)             ///
        REJoin                          ///
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

    * ---- anonymisation is ON unless the caller turns it off ---------------
    * The default is the safe one, and deliberately so. This command exists to
    * prepare a log for PUBLICATION -- into a paper, a supplement, a package
    * archive, a repository. A Stata log routinely carries
    *
    *     C:\Users\jsmith\AppData\Local\Temp\stata_worker_.../ST_73b0.tmp
    *     \\10.0.4.21\share\project\data.dta
    *     /Users/someone/Library/CloudStorage/OneDrive-ORG/team/secret.dta
    *
    * which leaks, in ascending order of seriousness, a username, a machine
    * layout, and the topology of an internal network. An author who forgets
    * an option should end up with a SAFE artifact and a slightly less
    * informative one, not an unsafe artifact -- the failure mode of a default
    * has to be the harmless direction.
    *
    * Only the DIRECTORY goes; the filename stays, because that is the part a
    * reader needs and the part that leaks nothing. Relative paths are left
    * entirely alone: they are safe and informative.
    local anon = ("`noanonymize'" == "")

    if `"`placeholder'"' == "" local placeholder "<path>"
    if !`anon' & `"`placeholder'"' != "<path>" {
        di as error "sjclean: placeholder() and noanonymize contradict each other"
        di as error "  placeholder() names the replacement text; noanonymize"
        di as error "  means nothing is replaced. Drop one."
        exit 198
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
    tempname rf

    local nread 0
    local njoin 0
    local nbreak 0

    file open `rf' using `"`using'"', read text

    * ---- the OUTPUT handle belongs to Mata, and this is not a preference --
    *
    * A chunk of arbitrary session text cannot be written through
    *
    *     file write `wf' `"`macval(chunk)'"' _n
    *
    * because -macval- stops macro EXPANSION and does nothing about a quote.
    * A chunk carrying the two characters "' -- which any echoed command using
    * Stata's own compound quotes carries, e.g.
    *
    *     stqa_assert `"`got'"' == "alpha", msg(...)
    *
    * -- closes the compound quote early, and everything after it is parsed as
    * further arguments to -file write-. rc 198, on that line only.
    *
    * Mata's fput() takes the string by value and has no parsing surface at
    * all, so the hazard is removed rather than escaped. Reading was already
    * held in Mata for this reason (see the note above); writing was not, which
    * is how the same bug reached a third release.
    * Mata's fopen(...,"w") REFUSES an existing file -- r(602) -- where Stata's
    * -file open ... write replace- overwrites, so the tempfile is removed
    * first. _unlink() rather than unlink(): there is normally nothing there,
    * and that is not an error.
    capture mata: fclose(sjc_wfh)
    mata: (void) _unlink(st_local("work"))
    mata: sjc_wfh = fopen(st_local("work"), "w")

    * ---- pass one: rejoin, then re-break -------------------------------
    *
    * Held in Mata throughout, in BOTH directions. A log line carries
    * arbitrary session text including the quotation marks in assertion
    * diagnostics, and a local holding one is re-parsed as macro syntax on
    * every reference -- r(132) reading, r(198) writing. That bug has now
    * shipped three times in this workspace, each time because one half of the
    * round trip was moved to Mata and the other half was left behind.

    mata: sjc_pending = ""

    local nanon 0

    file read `rf' line
    while r(eof) == 0 {
        local nread = `nread' + 1

        * Anonymise FIRST, before any rejoining or measuring. A path that is
        * about to be shortened should be shortened before the width is
        * computed, or the line is broken around text that will not be there.
        if `anon' {
            mata: sjc_hits = 0
            mata: st_local("line", sjc_anon(st_local("line"), st_local("placeholder")))
            mata: st_local("hits", strofreal(sjc_hits))
            local nanon = `nanon' + `hits'
        }

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
                sjc_emit `width' `"`continuation'"' `"`pad'"' ///
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
            mata: fput(sjc_wfh, st_local("line"))
        }

        file read `rf' line
    }

    * flush the last held line
    if "`rejoin'" != "" {
        mata: st_local("has", strofreal(strlen(sjc_pending) > 0))
        if `has' {
            sjc_emit `width' `"`continuation'"' `"`pad'"' ///
                    "`breakanywhere'" "`nostatasyntax'"
            local nbreak = `nbreak' + r(pieces) - 1
        }
    }

    file close `rf'
    mata: fclose(sjc_wfh)

    copy "`work'" `"`out'"', replace

    if "`quietly'" == "" {
        di as text "sjclean: `using'"
        di as text "  read      : `nread' line(s)"
        if "`rejoin'" != "" {
            di as text "  rejoined  : `njoin' continuation(s)"
            di as text "  re-broken : `nbreak' at width `width'"
        }
        if `anon' {
            di as text "  anonymised: `nanon' absolute path(s) -> `placeholder'"
        }
        di as text "  style     : `continuation' (indent `indent')"
        di as text "  written to: `out'"
    }

    return scalar read   = `nread'
    return scalar joined = `njoin'
    return scalar broken = `nbreak'
    return scalar anon   = `nanon'
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
    args width style pad anywhere nostata

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

        * The chunk is never lifted into a Stata local -- it is sliced out of
        * sjc_pending at the point of writing. Only the two offsets travel.
        local pos0 = `pos'
        local pos  = `pos' + `take'

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

        * prefix and suffix are the command's own strings -- spaces, "> " or
        * " ///" -- so they are safe to pass through locals. The chunk is not,
        * and does not.
        mata: fput(sjc_wfh, st_local("prefix") +                            ///
            substr(sjc_pending, strtoreal(st_local("pos0")),               ///
                   strtoreal(st_local("take"))) + st_local("suffix"))
    }

    mata: sjc_pending = ""
    return scalar pieces = `pieces'
    return scalar split  = cond("`nsplit'" == "", 0, 1)
end


* ----------------------------------------------------------------------
* sjc_anon -- replace the DIRECTORY part of every absolute path in a line.
*
* Written in Mata for the usual reason: a log line carries arbitrary text and
* holding one in a Stata local re-parses it as macro syntax the first time it
* contains an unbalanced quote.
*
* Deliberately conservative. It fires only on the four rooted forms below, so
* a relative path -- which is safe and informative -- survives untouched, and
* so does ordinary prose containing a colon or a slash.
* ----------------------------------------------------------------------
* Drop first, so re-running this file in a live session -- which is what
* -net install, replace- and any -run- during development both do -- does not
* fail with "sjc_isroot() already exists". Mata functions outlive the ado.
capture mata: mata drop sjc_isroot()
capture mata: mata drop sjc_isfname()
capture mata: mata drop sjc_anon()

version 14.0
mata:
mata set matastrict off

real scalar sjc_issep(string scalar c)
{
    return(c == "/" | c == char(92))
}

// Does this last segment look like a FILENAME rather than a directory?
//
// The command keeps the last segment of a stripped path because, for a path
// naming a file, that is the part a reader needs and the part that leaks
// nothing. For a path naming a DIRECTORY the same rule keeps precisely the
// wrong thing: "/home/jsmith" became "<path>/jsmith" and published the
// username the stripping existed to remove.
//
// So the segment is kept only when it carries an extension: a dot that is not
// the last character, with at least one LETTER after it. The letter matters --
// it is what stops "10.0.4.21" from reading as a file called "21" and putting
// an internal IP address back into the output.
//
// Anything else is treated as a directory and goes with the rest. The cost is
// losing "stata" from "/usr/local/bin/stata"; the alternative cost is a
// username in a published paper.
real scalar sjc_isfname(string scalar s)
{
    real scalar d, k, n
    string scalar ext, c

    d = strrpos(s, ".")
    n = strlen(s)
    if (d == 0 | d == n) return(0)

    ext = substr(s, d + 1, n - d)
    for (k = 1; k <= strlen(ext); k++) {
        c = substr(ext, k, 1)
        if (strpos("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", c) > 0) {
            return(1)
        }
    }
    return(0)
}

// Is the token starting at i an absolute path? Structural, not a list of
// known roots: rooted, and carrying at least one more separator so that
// there is a directory to remove. See the header note.
real scalar sjc_isabs(string scalar s, real scalar i, real scalar jout)
{
    real scalar j, k, n, seps, rooted
    string scalar c

    n = strlen(s)
    rooted = 0

    // rooted is a KIND, not a flag: 1 = drive letter, 2 = bare separator.
    // The two need different evidence before the token counts as a path, and
    // conflating them is what left "Z:/datalib" and "C:/Windows" untouched.

    // form 1: a drive letter, then a separator -- any letter, not a list
    if (i + 2 <= n) {
        c = substr(s, i, 1)
        if (strpos("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", c) > 0) {
            if (substr(s, i + 1, 1) == ":" & sjc_issep(substr(s, i + 2, 1))) rooted = 1
        }
    }
    // form 2: a LEADING separator -- covers POSIX absolute and UNC alike.
    //
    // "Leading" means at the start of a token, and the first version omitted
    // that check: it fired on the "/" inside "qa/logs/x.log" and turned a
    // RELATIVE path -- safe, informative, and none of this command's business
    // -- into "qa<path>/x.log". A separator is a root only where a token
    // begins.
    if (!rooted & sjc_issep(substr(s, i, 1))) {
        if (i == 1) rooted = 2
        else {
            c = substr(s, i - 1, 1)
            if (c == " " | c == char(9) | c == char(34) | c == "'" | ///
                c == "(" | c == "[" | c == ",") rooted = 2
        }
    }

    if (!rooted) return(0)

    // ---- a BARE separator root must be followed by a real segment --------
    //
    // Counting separators is not enough on its own, and this is where 2.1.0
    // broke a build. sjlog escapes "%%" to "\%\%", which carries TWO
    // backslashes -- so "\%\%EXCERPT-BEGIN sample", the marker the paper's
    // build slices excerpts on, satisfied the two-separator test, was read as
    // a path, and came out as "<path> sample". Every excerpt then failed to
    // find its own markers.
    //
    // A real path segment starts with a LETTER or a DIGIT: /home, /Users,
    // \server, Z:/datalib. A LaTeX escape does not: "\%", "\_", "\&". So
    // consecutive separators are skipped -- that is the UNC "\server" form --
    // and the first character of the first segment must be alphanumeric.
    //
    // Deliberately narrow: "." and "_" are NOT accepted as segment starts,
    // because "\_\_000000" is how a Stata tempvar reaches a typeset log and
    // it is not a path either.
    if (rooted == 2) {
        k = i
        while (k <= n & sjc_issep(substr(s, k, 1))) k++
        if (k > n) return(0)
        c = substr(s, k, 1)
        if (strpos("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", c) == 0) {
            return(0)
        }
    }

    // The token runs to the next delimiter. Count separators inside it.
    j = i
    seps = 0
    while (j <= n) {
        c = substr(s, j, 1)
        if (c == " " | c == char(9) | c == char(34) | c == "'" | ///
            c == ")" | c == "(" | c == "]" | c == "[" | c == ",") break
        if (sjc_issep(c)) seps++
        j++
    }

    // How much evidence is needed depends on the ROOT KIND.
    //
    // A drive letter is unambiguous -- nothing but a path is spelled "Z:/" --
    // so one separator is enough and "Z:/datalib" is a path. Requiring two
    // left every root-plus-one-segment path untouched, which is how a share
    // root reached a typeset artifact.
    //
    // A BARE separator is ambiguous, and this is where the second separator
    // earns its place: "egin{stlog}" and "\smallskip" are rooted-looking by
    // that test and are not paths. Two separators keeps LaTeX intact.
    //
    // Either way a run of separators ("///", Stata's own continuation) has no
    // segments at all and is never a path.
    if (seps < (rooted == 1 ? 1 : 2)) return(0)
    if (j - i == seps) return(0)

    st_numscalar("__sjc_end", j)
    return(1)
}

string scalar sjc_anon(string scalar raw, string scalar ph)
{
    real scalar i, j, k, lastsep, n
    string scalar out, tail

    // sjc_hits is set by the caller and read back afterwards. A Mata function
    // does not see a global unless it says so, and the first version did not
    // -- r(3200), conformability error, on the first line carrying a path.
    external real scalar sjc_hits

    out = ""
    i = 1
    n = strlen(raw)

    while (i <= n) {
        if (!sjc_isabs(raw, i, 0)) {
            out = out + substr(raw, i, 1)
            i++
            continue
        }

        j = st_numscalar("__sjc_end")

        // Keep whatever follows the LAST separator -- the filename, which is
        // the part a reader needs and the part that leaks nothing.
        lastsep = 0
        for (k = i; k < j; k++) {
            if (sjc_issep(substr(raw, k, 1))) lastsep = k
        }

        // The last segment is kept only when it IS a filename. See
        // sjc_isfname: for a directory path the last segment is a directory
        // name, and directory names are the thing that leaks.
        tail = ""
        if (lastsep > 0 & lastsep < j - 1) tail = substr(raw, lastsep + 1, j - lastsep - 1)

        if (tail != "" & sjc_isfname(tail)) {
            out = out + ph + "/" + tail
        }
        else {
            out = out + ph
        }

        sjc_hits = sjc_hits + 1
        i = j
    }

    return(out)
}
end
