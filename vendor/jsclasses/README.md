# jsclasses

The bundle provides Japanese classes and packages, mainly for use with
pLaTeX and upLaTeX. These were originally written by Haruhiko Okumura,
and currently maintained by the Japanese TeX Development Community
(https://texjp.org) on the GitHub repository:

- https://github.com/texjporg/jsclasses

The classes themselves do not automatically enable the support of
Japanese language. You'll need to set up LaTeX environment appropriately
so that it can handle Japanese.

## Character encoding

In the above repository, we include the pre-generated cls/sty files to
ensure proper encoding. All files are now encoded in UTF-8, since
recent versions of pLaTeX/upLaTeX recognizes `\epTeXinputencoding`
primitive of e-(u)pTeX. If you are using old (< 2015) pLaTeX/upLaTeX,
please download files in jis/ directory.

## Contents

- jsclasses (jsarticle, jsbook, jsreport and miscellaneous)
    - Japanese classes for pLaTeX/upLaTeX.
- minijs
    - Minimal jsclasses-like settings for pLaTeX/upLaTeX.
- okumacro
    - Miscellaneous macros for pLaTeX/upLaTeX, written by H. Okumura.
- jsverb, okuverb
    - Extended version of `\verb` and `verbatim` env. for pLaTeX/upLaTeX.
- jslogo
    - Extended version of LaTeX-related logos for all *LaTeX engines.

The package [morisawa](https://github.com/texjporg/morisawa) is now
distributed separately.

## Release Date

$RELEASEDATE

Haruhiko Okumura,
Japanese TeX Development Community
