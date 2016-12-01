# LaTeX and review-pdfmaker

The command `review-pdfmaker` in Re:VIEW use [LaTeX](https://en.wikipedia.org/wiki/LaTeX) to generate a PDF file.

To use the command, you need to set up LaTeX system.


## Important Changes about LaTeX in Re:VIEW 2.0

* Default LaTeX compiler is upLaTeX, not pLaTeX.
* The meaning of `scale` option in `@<image>` command is changed and configurable.
* `prt` is printer, not publisher. You can use `pbl` for publisher.

## about upLaTeX

In Re:VIEW 2.0 released at April 2016, default LaTeX compiler became upLaTeX from pLaTeX.  The upLaTeX support Unicode and you can use unicode characters such like ①②... and other characters without otf package.

Almost packages in pLaTeX can be supported in upLaTeX, but some package (such as jsbook class and otf package) need `uplatex` option.

Default settings of Re:VIEW is below:

```yaml
texcommand: uplatex
texoptions: null
texdocumentclass: ["jsbook", "uplatex,oneside"]
dvicommand: dvipdfmx
dvioptions: "-d 5"
```

## How to use old pLaTeX

You also use pLaTeX with Re:VIEW 2.0.

To use pLaTeX, You can add these configuration in config.yml.

```yaml
texcommand: platex
texoptions: "-kanji=utf-8"
texdocumentclass: ["jsbook", "oneside"]
dvicommand: dvipdfmx
dvioptions: "-d 5"
```

You can use a variable `@texcompiler` to compare latex command in layout ERB files (lib/review/layout.tex.erb in default).
The value of `@texcompiler` is `platex` (when using pLaTeX) and `uplatex` (when using upLaTeX).
The usage is below:

```
<% if @texcompiler == "uplatex" %>
\usepackage[deluxe,uplatex]{otf}
<% else %>
\usepackage[deluxe]{otf}
<% end %>
```

## about `scale` option

In Re:VIEW 2.0, the meaning of `scale=..` in the third option of ``//image`` command.
The meaning in 1.0 is "scale for image file" (`1.0` is same as original image size), but the one in 2.0 is "scale for paper width" (`1.0` is same as paper widdth.)

If you need the same behavior in Re:VIEW 1.x, you should add ``image_scale2width: false`` in config.yml (default value is `true`).

```yaml
image_scale2width: false
```
