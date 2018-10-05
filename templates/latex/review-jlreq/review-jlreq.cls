%#!ptex2pdf -l -u -ot '-synctex=1' test-rejlreqbk
% Copyright (c) 2018 Kenshi Muto.
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{review-jlreq}[2018/10/05 Re:VIEW pLaTeX class modified for jlreq.
cls]

\RequirePackage{fix-cm}%%\RequirePackage{fix-cm,exscale}
\IfFileExists{latexrelease.sty}{}{\RequirePackage{fixltx2e}}

%% graphicx: added nosetpagesize
\IfFileExists{platexrelease.sty}{%% is bundled in TL16 or higher release version
\PassOptionsToPackage{nosetpagesize}{graphicx}%%for TL16 or higher version
}{}

\RequirePackage{xkeyval}

%% useful helpers
\newcommand\recls@get@p@[2]{%
  \edef#2{\expandafter\@recls@GET@P@\the#1}}
{\catcode`p=12\catcode`t=12\gdef\@recls@GET@P@#1pt{#1}}%

\long\def\recls@ifempty#1{%
  \expandafter\ifx\expandafter\relax\detokenize{#1}\relax\expandafter\@firstoftwo\else\expandafter\@secondoftwo\fi}
% \long\def\recls@ifempty#1{\recls@xifempty#1@@..\@nil}
% \long\def\recls@xifempty#1#2@#3#4#5\@nil{%
%   \ifx#3#4\expandafter\@firstoftwo\else\expandafter\@secondoftwo\fi}
\long\def\recls@ifnotempty#1{\recls@ifempty{#1}{}}

\newcommand*{\recls@DeclareOption}[2]{%
  \DeclareOptionX{#1}{%
    \recls@ifempty{##1}{}{%
      \ClassError{recls}{The option #1 should have no value}{\@ehc}}%
    #2}}

%% cameraready=print,ebook,preview
\newif\if@cameraready \@camerareadyfalse
\newif\if@pdfhyperlink \@pdfhyperlinkfalse
\newif\if@pdftombo \@pdftombofalse
\DeclareOptionX{cameraready}[print]{\gdef\recls@cameraready{#1}}
\DeclareOptionX{tombopaper}[a4]{\gdef\recls@tombopaper{#1}}

\PassOptionsToClass{book}{jlreq}% クラスで必ず使うオプションの指定
\DeclareOptionX*{\PassOptionsToClass{\CurrentOption}{jlreq}}%
\ExecuteOptionsX{cameraready,tombopaper}
\ProcessOptionsX\relax

\def\recls@tmp{preview}\ifx\recls@cameraready\recls@tmp
  \@camerareadyfalse\@pdfhyperlinktrue\@pdftombofalse
\else\def\recls@tmp{print}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinkfalse\@pdftombotrue
\else\def\recls@tmp{ebook}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinktrue\@pdftombofalse
\else
  \recls@error{No such value of cameraready: \recls@cameraready}%
\fi\fi\fi

\LoadClass{jlreq}

% トンボ設定
\if@pdftombo
  % ★ほかのpackage設定もしたくなるか？ だいたいは\jlreqtrimmarkssetupで上書きできる
  \RequirePackage[trimmarks_paper=\recls@tombopaper]{jlreq-trimmarks}
\fi

% エンジンとドライバの情報。jlreq-trimmarksが定義されていればそっちから持ってくる。
% 定義されていなければjlreqから持ってくる
\def\recls@engine{}
\def\recls@driver{}
\ifdefined\jlreq@trimmarks@engine
  \ifx l\jlreq@trimmarks@engine\def\recls@engine{lualatex}\fi
  \ifx u\jlreq@trimmarks@engine\def\recls@engine{uplatex}\fi
  \ifx p\jlreq@trimmarks@engine\def\recls@engine{platex}\fi
\else% jlreqから持ってくる
  \ifx l\jlreq@engine\def\recls@engine{lualatex}\fi
  \ifx u\jlreq@engine\def\recls@engine{uplatex}\fi
  \ifx p\jlreq@engine\def\recls@engine{platex}\fi
\fi
\ifdefined\jlreq@trimmarks@driver
  \ifx f\jlreq@trimmarks@driver\def\recls@driver{dvipdfmx}\fi
  \ifx s\jlreq@trimmarks@driver\def\recls@driver{dvips}\fi
  \ifx o\jlreq@trimmarks@driver\def\recls@driver{dviout}\fi
\else% jlreqから持ってくる
  \ifx l\jlreq@engine
    \def\recls@driver{luatex}
  \else
    \def\recls@driver{dvipdfmx}
  \fi
\fi

\RequirePackage[\recls@driver]{graphicx}
\RequirePackage[\recls@driver,table]{xcolor}

\RequirePackage[T1]{fontenc}
\RequirePackage{textcomp}%T1/TS1
\RequirePackage{lmodern}%\ttdefault: lmtt
\RequirePackage{tikz}
\usetikzlibrary{calc}
\RequirePackage{multirow}
\RequirePackage{amsmath}
\RequirePackage{amssymb}
\RequirePackage{needspace}
\RequirePackage{alltt}
\RequirePackage{float}
\RequirePackage{upquote}
\RequirePackage{bm}
\RequirePackage[table]{xcolor}
\RequirePackage{tcolorbox}
\tcbuselibrary{xparse,hooks,skins,breakable}

\IfFileExists{jumoline.sty}{
\RequirePackage{jumoline}
}

\RequirePackage[dvipdfmx, \if@pdfhyperlink\else draft,\fi
  bookmarks=true,
  bookmarksnumbered=true,
  hidelinks,
  setpagesize=false,
]{hyperref}
\RequirePackage[\recls@driver]{pxjahyper}

\listfiles
\endinput
