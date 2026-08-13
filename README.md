# sjclean

**Rejoin and re-break a Stata log for LaTeX inclusion, at a width you choose.**

Stata breaks a log line when it exceeds `c(linesize)` and marks the
continuation with `>`. That break is an artifact of a terminal width chosen
before anybody knew what column the line would be typeset in. It costs three
things: the `>` is clutter, the break lands wherever the character count ran
out, and the width bears no relation to the page.

`sjclean` rejoins the logical line and re-breaks it where you want it.

```stata
net install sjclean, from("https://raw.githubusercontent.com/jpazvd/sjclean/main/src") replace
sjclean using session.log.tex, width(96) rejoin replace
```

---

## Before and after

A log written at `linesize 60`, so Stata wrapped it:

```
A considerably longer line that Stata will break because it
> exceeds the current linesize setting.

    Variable |        Obs        Mean    Std. dev.       Min
            Max
-------------+----------------------------------------------
    -----------
       price |         74    6165.257    2949.496       3291
          15906
```

The break in the prose line falls mid-word. Worse, the `summarize` table is
broken in half: its `Max` column and part of its rule are on separate lines,
which is not a table any more.

After `sjclean using ... , width(96) rejoin`:

```
A considerably longer line that Stata will break because it exceeds the current linesize
    setting.

    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
       price |         74    6165.257    2949.496       3291      15906
         mpg |         74     21.2973    5.785503         12         41
```

The table is whole, because at width 96 it fits on one line. The prose line
breaks **at a space**, leaving `setting.` intact. Nothing was added or removed
— the logical lines were reassembled and split again somewhere more useful.

Run `examples/demo_before_after.do` to reproduce this, including a third
variant that restyles the marker without moving the break.

---

## Options

| option | default | what it does |
|---|---|---|
| `width(#)` | `96` | re-break at `#` characters |
| `rejoin` | off | reassemble logical lines **before** re-breaking |
| `continuation(indent)` | default | continued lines start with `indent()` spaces |
| `continuation(marker)` | | keep Stata's `>` |
| `continuation(none)` | | no marker at all |
| `indent(#)` | `4` | spaces under `continuation(indent)`, 0–16 |
| `replace` | | overwrite the input |
| `saving(f)` | | write elsewhere, leave the input alone |
| `quietly` | | suppress the summary |
| `breakanywhere` | off | break at exactly `width()`, splitting words |
| `nostatasyntax` | off | never add `///`, even to a command echo |
| `noanonymize` | off | **keep** machine paths - anonymisation is on by default |
| `placeholder(s)` | `<path>` | text that replaces a stripped directory |

`replace` or `saving()` is required. A command that silently picked one would
eventually pick wrong.

**`rejoin` is the option that matters.** Without it, `sjclean` only restyles
the existing markers and the text is still broken at whatever `c(linesize)`
was when the log was written — it just looks different. With it, the break is
at *your* width.

### Words are not split

By default the break goes at the **last space at or before** the width, never
at the width itself. A word cut in half is unreadable in prose and unusable in
code — you cannot copy `something e` / `lse`, and you cannot copy half a
variable name either. Only when a single token is itself wider than the column
is there no better answer, and then it is split rather than allowed to
overflow. `breakanywhere` restores a hard column for callers who want one.

### Commands stay runnable

A **command echo** that has to be broken gets `///` at the break, so the
printed session is still code somebody can paste:

```
. stqa_assert (`vp' == `bp') & (`bp' == `op'), msg("a display mode changed ///
    the number of PASS: tokens in the log")
```

Output lines get no such marker — `///` inside a `summarize` table would be
nonsense. An echoed command is recognised by the leading `. ` that Stata writes
in front of it, which is a property of the log format rather than a guess. The
four characters are budgeted out of the width so the marker cannot itself push
the line over. `nostatasyntax` turns this off.

### A `///` in the source is removed when its lines are joined

**Stata marks the continuation of a `///` command with `>`, exactly as it marks
a linesize wrap.** (Earlier versions of this README claimed otherwise, and
`sjclean` behaved accordingly — see below.) So `rejoin` does cross a source
`///`, and it must, or the logical line could never be reassembled.

What it must *not* do is carry the `///` into the middle of the joined command.
Everything after `///` on a line is a comment, so this:

```
. capture noisily stqa_assert `nunion' == 2225, ///        msg("union is ...
```

is an assertion with **no `msg()`** — the printed session and the session that
actually ran are different programs, and nothing errors to tell you.

Since 2.2.0 the `///` is dropped at the join (it marked a break that no longer
exists) and re-added at whatever break `sjclean` itself introduces, so the
printed command stays runnable either way.

`r(read)`, `r(joined)`, `r(broken)` and `r(anon)` are returned.

---

## Machine paths are stripped by default

A log written on a real machine carries real machine paths. This is what a
session routinely leaves in a file you are about to publish:

```
. use "C:\Users\jsmith\AppData\Local\Temp\stata_worker_7505d64a54\ST_73b0.tmp"
. merge 1:1 iso3 using "\10.0.4.21\research\admin\staff_salaries.dta"
. save "/Users/jsmith/Library/CloudStorage/OneDrive-ORG/team/draft.dta"
```

That leaks, in ascending order of seriousness: a **username**, a **machine
layout**, and the **topology of an internal network** - server names, share
names, IP addresses. The last is a security matter rather than a tidiness one,
and it is at its worst precisely when the log is stored somewhere shared.

`sjclean` replaces the **directory** and keeps the **filename**:

```
. use "<path>/ST_73b0.tmp"
. merge 1:1 iso3 using "<path>/staff_salaries.dta"
. save "<path>/draft.dta"
```

The filename is the part a reader needs and the part that leaks nothing.

**A path naming a *directory* loses everything**, because there the last
segment is a directory name — and directory names are exactly what leaks:

```
/home/jsmith        ->  <path>          not <path>/jsmith
Z:/datalib          ->  <path>
C:/Windows          ->  <path>
```

A segment counts as a filename only if it carries an extension: a dot that is
not the last character, with at least one **letter** after it. The letter is
what stops `10.0.4.21` from reading as a file called `21` and putting an
internal address back into the output.

**Relative paths are left alone**, because they are safe *and* informative.
`qa/logs/test_data_stqa.log` tells a reader where to look in the repository and
tells an attacker nothing, so it survives untouched.

### Why it is the default

The failure mode of a default has to point in the harmless direction. An author
who forgets an option should end up with a **safe artifact and slightly less
information**, never an unsafe one. Use `noanonymize` when you deliberately want
the paths kept - a private debugging log, say:

```stata
sjclean using session.log.tex, width(96) rejoin replace noanonymize
```

`placeholder()` changes the replacement text (`placeholder("<REDACTED>")`), and
`r(anon)` reports how many paths were stripped, so a build can assert on it.

### Detection is structural, not a list

There is no table of known roots. A token is treated as an absolute path when it
is **rooted** - a drive letter followed by a separator, or a leading separator -
**and** contains at least one further separator, so there is a directory to
remove. No usernames, hostnames, cloud providers or drive letters appear
anywhere in the logic, so it cannot depend on anyone having guessed the right
ones in advance. The second condition is what keeps `///`, a bare `/`, and LaTeX
control sequences like `\begin{stlog}` from being mistaken for paths.

### What it does *not* do

It is not a header stripper. Given Stata's log banner it removes the path and
**leaves the timestamp**:

```
        log:  <path>/run.log
  opened on:  13 Aug 2026, 10:44:06        <- survives
```

A timestamp is a *determinism* concern, not a disclosure one. In the `sjlog`
workflow the question does not arise: `quietly log using` suppresses the banner
before `sjclean` ever sees the file.

---

## Choosing a width

The right width is a property of the environment the log will be typeset in,
and it is **measurable**. `examples/_width_probe.tex` typesets rulers of known
length and asks LaTeX to report overfull boxes; the largest ruler with no
report is the capacity. In the Stata Journal class:

| environment | capacity |
|---|---|
| `stlog[beamer]` (7pt) | **96** fits; 104 overflows by 7.2pt |
| `stlog` (8pt) | **80** fits; 88 overflows by 19.4pt |

Sixteen characters apart, which is why the width is an option and not a
constant. Run the probe in your own class before trusting either number.

`continuation(indent)` adds `indent()` characters to every continued line, so
`width(96) indent(4)` produces lines of up to 100. Leave headroom.

---

## A literal tab does not work

The obvious way to indent a continuation is a tab character. It does not
survive: inside an `alltt` environment a `0x09` byte carries the catcode of
ordinary whitespace and **collapses to a single space**.
`examples/_tab_probe.tex` demonstrates it, and ships with its LaTeX log:

```
X0 no indent at all -- baseline
 A literal tab character precedes this line          <- one space
      B four literal spaces precede this line
            C eight literal spaces precede this line
```

So an indent is spaces, and `indent(4)` is the conventional tab stop.

---

## Which file to run it on

**Run it on the typeset artifact, never on a log that anything counts.**

Test frameworks that read verdicts out of logs typically match a token at
column 1 after trimming whitespace. Restyling a continuation in such a file
can *manufacture* a verdict: a wrapped line whose continuation happens to
begin `PASS:` becomes, once the `>` is replaced by spaces and the line is
trimmed, indistinguishable from a real one.

| file | read by | |
|---|---|---|
| `*.log.tex` | LaTeX only | safe |
| `*.log`, `*.smcl` | scanners, humans | leave alone |

---

## Why this exists

Five Stata packages by the same author print sessions in their papers, and did
it three different ways: `sjlog` from the Stata Journal's own `sjlatex`; a log
written directly to a `.log.tex`; and a post-hoc Python cleaner. One of the
three was built and never adopted. Only one handled continuations at all, and
it rejoined without re-breaking, which trades a visible marker for a line that
overflows the column.

`sjclean` is the one implementation those five should share. It is deliberately
*not* a replacement for `sjlog`: use `sjlog` to capture the session — it
escapes LaTeX specials correctly, which a plain `log using x.log.tex` does not
— and `sjclean` afterwards to set the width.

---

## Requirements and dependencies

**`sjclean` itself needs nothing but Stata 14.** It reads a text file and
writes a text file; there is no dependency to install for the command to run.

**The workflow it belongs to needs the Stata Journal's editorial ados**, and
that is where the real dependency sits:

| you need | for | from |
|---|---|---|
| `sjlog` | capturing the session into a `.log.tex` | `sjlatex` |
| `statapress.cls`, `sj.sty`, `stata.sty`, `pagedims.sty` | typesetting it, and running the probes | `sjlatex` |

```stata
net install sjlatex, from("http://www.stata-journal.com/production")
```

The full editorial package, its documentation, and the author guidelines are at
**<https://www.stata-journal.com/production/>**.

`sjclean` is deliberately downstream of `sjlog` rather than a replacement for
it. Use `sjlog` to capture — it escapes LaTeX specials, which a plain
`log using x.log.tex` does not, so a session printing `%`, `_`, `&` or a
backslash survives — then `sjclean` to set the width:

```stata
sjlog do myexample, replace              // sjlatex: session -> myexample.log.tex
sjclean using myexample.log.tex, ///     // sjclean:  set the width
    width(96) rejoin replace
```

The two probes in `examples/` compile against the Stata Journal class, so they
need `sjlatex` installed and its `.cls`/`.sty` files visible to LaTeX. Without
them the probes will not build; `sjclean` will still work.

## Author

João Pedro Azevedo, UNICEF — jpazevedo@unicef.org

## License

MIT
