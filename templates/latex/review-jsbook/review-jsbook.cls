%#!ptex2pdf -l -u -ot '-synctex=1' test-rejsbk
% Copyright (c) 2018 Munehiro Yamamoto.
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

\ifx\epTeXinputencoding\undefined\else
  \epTeXinputencoding utf8
\fi
\NeedsTeXFormat{pLaTeX2e}
\ProvidesClass{review-jsbook}
  [2018/09/30 v3.0  Re:VIEW pLaTeX class modified for jsbook.cls]

%% fixes to LaTeX2e
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

%% 基本版面 QWLH、天、ノド
\DeclareOptionX{Q}[13]{\gdef\recls@Q{#1}}
\DeclareOptionX{W}[35]{\gdef\recls@W{#1}}
\DeclareOptionX{L}[32]{\gdef\recls@L{#1}}
\DeclareOptionX{H}[22]{\gdef\recls@H{#1}}
\DeclareOptionX{head}[\z@]{\gdef\recls@head{#1}}%[18mm]
\DeclareOptionX{gutter}[\z@]{\gdef\recls@gutter{#1}}%[20mm]

\DeclareOptionX{headheight}[\z@]{\gdef\recls@headheight{#1}}
\DeclareOptionX{headsep}[\z@]{\gdef\recls@headsep{#1}}
\DeclareOptionX{footskip}[\z@]{\gdef\recls@footskip{#1}}

\PassOptionsToClass{dvipdfmx}{jsbook}
\DeclareOptionX*{\PassOptionsToClass{\CurrentOption}{jsbook}}%
\ExecuteOptionsX{cameraready,Q,W,L,H,head,gutter,headheight,headsep,footskip}
\ProcessOptionsX\relax

\def\recls@tmp{preview}\ifx\recls@cameraready\recls@tmp
  \@camerareadyfalse\@pdfhyperlinktrue
\else\def\recls@tmp{print}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinkfalse\@pdftombotrue
  \IfFileExists{gentobmow.sty}{}
  {% 代替
    \PassOptionsToClass{papersize,tombo}{jsbook}
  }
\else\def\recls@tmp{ebook}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinktrue
\else
  \recls@error{No such value of cameraready: \recls@cameraready}%
\fi\fi\fi

%% 内部Unicode動作の時だけupTeXとみなす
\newif\if@recls@uptex \@recls@uptexfalse
\ifx\ucs\@undefined\else \ifnum\ucs"3000="3000
  \@recls@uptextrue
  \PassOptionsToClass{uplatex}{jsbook}
  \PassOptionsToPackage{uplatex}{otf}
\fi\fi

\PassOptionsToClass{10pt}{jsbook}
\LoadClass{jsbook}

\def\recls@JYn{\if@recls@uptex JY2\else JY1\fi}%
\def\recls@JTn{\if@recls@uptex JT2\else JT1\fi}%
\def\recls@pfx@{\if@recls@uptex up\else \fi}%
\def\recls@sfx@{\if@recls@uptex \else n\fi}%
\def\recls@sc@le{\if@recls@uptex 0.924714\else 0.961026\fi}%
\def\recls@jisrh{\if@recls@uptex upjisr-h\else jisn\fi}%
\def\recls@jisgh{\if@recls@uptex upjisg-h\else jisgn\fi}%
\def\recls@jisrv{\if@recls@uptex upjisr-v\else jisn-v\fi}%
\def\recls@jisgv{\if@recls@uptex upjisg-v\else jisgn-v\fi}%

\def\recls@jisrh{\recls@pfx@ jis\if@recls@uptex r-h\fi}%
\def\recls@jisgh{\recls@pfx@ jisg\if@recls@uptex -h\fi}%
\def\recls@jisrv{\recls@pfx@ jis\if@recls@uptex r\fi -v}%
\def\recls@jisgv{\recls@pfx@ jisg-v}%

\expandafter\let\csname\recls@JYn/mc/m/n/10\endcsname\relax
\expandafter\let\csname\recls@JYn/gt/m/n/10\endcsname\relax

%% calculate font size scaler
\@tempdima=13\dimexpr 13\p@\relax
\@tempdimb=\recls@Q\dimexpr\recls@Q\p@\relax
\@settopoint\@tempdima \@settopoint\@tempdimb
\@tempcnta=\strip@pt\@tempdima\relax
\@tempcntb=\strip@pt\@tempdimb\relax
\@tempdima=\dimexpr\@tempcntb\p@/\@tempcnta\relax
\recls@get@p@{\@tempdima}{\recls@@scale}% \typeout{!!! \recls@@scale}%

\RequirePackage{lmodern}

\newdimen\JQ \JQ=1.08141Q\relax

%% declare relative font definitions
%% <family>: mc (reserved), gt (reserved), mgt?
%% <series>: m (reserved), bx (reserved), eb?
%% <shape>: n (reserved)
%% JYn
\DeclareFontShape{\recls@JYn}{mc}{m}{n}{%
  <-> s * [\recls@sc@le] \recls@jisrh
}{}
\DeclareFontShape{\recls@JYn}{gt}{m}{n}{%
  <-> s * [\recls@sc@le] \recls@jisgh
}{}
\DeclareFontShape{\recls@JYn}{mc}{bx}{n}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JYn}{gt}{bx}{n}{<->ssub*gt/m/n}{}
%% JTn
\DeclareFontShape{\recls@JTn}{mc}{m}{n}{%
  <-> s * [\recls@sc@le] \recls@jisrv
}{}
\DeclareFontShape{\recls@JTn}{gt}{m}{n}{%
  <-> s * [\recls@sc@le] \recls@jisgv
}{}
\DeclareFontShape{\recls@JTn}{mc}{bx}{n}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JTn}{gt}{bx}{n}{<->ssub*gt/m/n}{}
%% it
\DeclareFontShape{\recls@JYn}{mc}{m}{it}{<->ssub*mc/m/n}{}
\DeclareFontShape{\recls@JYn}{mc}{bx}{it}{<->ssub*mc/bx/n}{}
\DeclareFontShape{\recls@JYn}{gt}{m}{it}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JYn}{gt}{bx}{it}{<->ssub*gt/bx/n}{}
\DeclareFontShape{\recls@JTn}{mc}{m}{it}{<->ssub*mc/m/n}{}
\DeclareFontShape{\recls@JTn}{mc}{bx}{it}{<->ssub*mc/bx/n}{}
\DeclareFontShape{\recls@JTn}{gt}{m}{it}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JTn}{gt}{bx}{it}{<->ssub*gt/bx/n}{}
%% sl
\DeclareFontShape{\recls@JYn}{mc}{m}{sl}{<->ssub*mc/m/n}{}
\DeclareFontShape{\recls@JYn}{mc}{bx}{sl}{<->ssub*mc/bx/n}{}
\DeclareFontShape{\recls@JYn}{gt}{m}{sl}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JYn}{gt}{bx}{sl}{<->ssub*gt/bx/n}{}
\DeclareFontShape{\recls@JTn}{mc}{m}{sl}{<->ssub*mc/m/n}{}
\DeclareFontShape{\recls@JTn}{mc}{bx}{sl}{<->ssub*mc/bx/n}{}
\DeclareFontShape{\recls@JTn}{gt}{m}{sl}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JTn}{gt}{bx}{sl}{<->ssub*gt/bx/n}{}
%% sc
\DeclareFontShape{\recls@JYn}{mc}{m}{sc}{<->ssub*mc/m/n}{}
\DeclareFontShape{\recls@JYn}{mc}{bx}{sc}{<->ssub*mc/bx/n}{}
\DeclareFontShape{\recls@JYn}{gt}{m}{sc}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JYn}{gt}{bx}{sc}{<->ssub*gt/bx/n}{}
\DeclareFontShape{\recls@JTn}{mc}{m}{sc}{<->ssub*mc/m/n}{}
\DeclareFontShape{\recls@JTn}{mc}{bx}{sc}{<->ssub*mc/bx/n}{}
\DeclareFontShape{\recls@JTn}{gt}{m}{sc}{<->ssub*gt/m/n}{}
\DeclareFontShape{\recls@JTn}{gt}{bx}{sc}{<->ssub*gt/bx/n}{}

\renewcommand{\normalsize}{%
  \jsc@setfontsize\normalsize{\recls@Q\JQ}{\recls@H H}
  \abovedisplayskip 11\jsc@mpt \@plus3\jsc@mpt \@minus4\jsc@mpt
  \abovedisplayshortskip \z@ \@plus3\jsc@mpt
  \belowdisplayskip 9\jsc@mpt \@plus3\jsc@mpt \@minus4\jsc@mpt
  \belowdisplayshortskip \belowdisplayskip
  \let\@listi\@listI}
\hyphenpenalty\@M\relax
\exhyphenpenalty\@M\relax
\normalsize

\setbox0\hbox{\char\jis"3441}%"
\setlength\Cht{\ht0}
\setlength\Cdp{\dp0}
\setlength\Cwd{\wd0}
\setlength\Cvs{\baselineskip}
\setlength\Chs{\wd0}
\setbox0=\box\voidb@x

\renewcommand{\small}{%
  \ifnarrowbaselines
    \jsc@setfontsize\small
      {\dimexpr\recls@Q\JQ - 1\JQ}{1.5\dimexpr\recls@Q H - 3H}%
  \else
    \jsc@setfontsize\small
      {\dimexpr\recls@Q\JQ - 1\JQ}{1.5\dimexpr\recls@Q H - 1H}%
  \fi
  \abovedisplayskip 9\jsc@mpt \@plus3\jsc@mpt \@minus4\jsc@mpt
  \abovedisplayshortskip  \z@ \@plus3\jsc@mpt
  \belowdisplayskip \abovedisplayskip
  \belowdisplayshortskip \belowdisplayskip
  \def\@listi{\leftmargin\leftmargini
              \topsep \z@
              \parsep \z@
              \itemsep \parsep}}

\renewcommand{\footnotesize}{%
  \ifnarrowbaselines
    \jsc@setfontsize\footnotesize
      {\dimexpr\recls@Q\JQ - 2\JQ}{1.5\dimexpr\recls@Q H - 3H}%
  \else
    \jsc@setfontsize\footnotesize
      {\dimexpr\recls@Q\JQ - 2\JQ}{1.5\dimexpr\recls@Q H - 2H}%
  \fi
  \abovedisplayskip 6\jsc@mpt \@plus2\jsc@mpt \@minus3\jsc@mpt
  \abovedisplayshortskip  \z@ \@plus2\jsc@mpt
  \belowdisplayskip \abovedisplayskip
  \belowdisplayshortskip \belowdisplayskip
  \def\@listi{\leftmargin\leftmargini
              \topsep \z@
              \parsep \z@
              \itemsep \parsep}}

\renewcommand{\scriptsize}{\jsc@setfontsize\scriptsize
  {\dimexpr\grnchry@Qnum\JQ - 3\JQ}{1.25\dimexpr\grnchry@Qnum H - 3H}}
\renewcommand{\tiny}{\jsc@setfontsize\tiny
  {.5\dimexpr\grnchry@Qnum\JQ}{.5\dimexpr\grnchry@Qnum H + 2H}}
\if@twocolumn
  \renewcommand{\large}{\@setfontsize\large{18\JQ}{\n@baseline}}
\else
  \renewcommand{\large}{\@setfontsize\large{18\JQ}{27H}}
\fi
\renewcommand{\Large}{\@setfontsize\Large{20\JQ}{30H}}
\renewcommand{\LARGE}{\@setfontsize\LARGE{24\JQ}{36H}}
\renewcommand{\huge}{\@setfontsize\huge{28\JQ}{42H}}
\renewcommand{\Huge}{\@setfontsize\Huge{32\JQ}{48H}}
\renewcommand{\HUGE}{\jsc@setfontsize\HUGE{36\JQ}{54H}}

%% headheight, headsep, footskip
\setlength\topskip{\Cht}
\ifdim\recls@headheight>\z@\relax\setlength\headheight{\recls@headheight}\fi
\ifdim\recls@headsep>\z@\relax\setlength\headsep{\recls@headsep}\fi
\ifdim\recls@footskip>\z@\relax\setlength\footskip{\recls@footskip}\fi
\setlength\maxdepth{.5\topskip}

%% 字詰め数、行数
\setlength\textwidth{\recls@W\Cwd}
\setlength\textheight{\recls@L\Cvs}
\addtolength\textheight{-\Cvs}\addtolength\textheight{\Cwd}
\addtolength\textheight{1H}%.5H

\setlength\fullwidth{\textwidth}

%% ノド、小口
\ifdim\recls@gutter>\z@
\setlength\oddsidemargin{\recls@gutter}%ノド
\addtolength\oddsidemargin{-1in}
\setlength\evensidemargin{\paperwidth}
\addtolength\evensidemargin{-2in}
\addtolength\evensidemargin{-\oddsidemargin}
\addtolength\evensidemargin{-\textwidth}
\else
\setlength\oddsidemargin\paperwidth
\addtolength\oddsidemargin{-\textwidth}
\setlength\oddsidemargin{.5\oddsidemargin}
\addtolength\oddsidemargin{-1in}
\setlength\evensidemargin\oddsidemargin
\fi

%% 天、地
\ifdim\recls@head>\z@
\setlength\topmargin{\recls@head}%天
\else
\setlength\topmargin\paperheight
\addtolength\topmargin{-\textheight}
\setlength\topmargin{.5\topmargin}
\fi
\addtolength\topmargin{-1in}
\addtolength\topmargin{-\headheight}\addtolength\topmargin{-\headsep}


\RequirePackage[dvipdfmx, \if@pdfhyperlink\else draft,\fi
  bookmarks=true,
  bookmarksnumbered=true,
  hidelinks,
  setpagesize=false,
]{hyperref}
% \def\equationautorefname{式}%
% \def\footnoteautorefname{脚注}%
% \def\itemautorefname{項目}%
% \def\figureautorefname{図}%
% \def\tableautorefname{表}%
% \def\partautorefname{パート}%部
% \def\appendixautorefname{付録}%
% \def\chapterautorefname{章}%チャプター
% \def\sectionautorefname{節}%セクション
% \def\subsectionautorefname{小節}%小セクション
% \def\subsubsectionautorefname{小々節}%小々セクション
% \def\paragraphautorefname{段落}%パラグラフ
% \def\subparagraphautorefname{小段落}%小パラグラフ
% \def\FancyVerbLineautorefname{行}%
% \def\theoremautorefname{定理}%
% \def\pageautorefname{ページ}%
\RequirePackage[dvipdfmx]{pxjahyper}

\listfiles
\endinput
