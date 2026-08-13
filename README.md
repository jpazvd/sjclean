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
A considerably longer line that Stata will break because it exceeds the current linesize setting
    .

    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
       price |         74    6165.257    2949.496       3291      15906
         mpg |         74     21.2973    5.785503         12         41
```

The table is whole, because at width 96 it fits on one line. Nothing was added
or removed — the logical lines were reassembled and split again somewhere more
useful.

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

`replace` or `saving()` is required. A command that silently picked one would
eventually pick wrong.

**`rejoin` is the option that matters.** Without it, `sjclean` only restyles
the existing markers and the text is still broken at whatever `c(linesize)`
was when the log was written — it just looks different. With it, the break is
at *your* width.

`r(read)`, `r(joined)` and `r(broken)` are returned.

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

## Requirements

Stata 14 or later. No dependencies.

## Author

João Pedro Azevedo, UNICEF — jpazevedo@unicef.org

## License

MIT
