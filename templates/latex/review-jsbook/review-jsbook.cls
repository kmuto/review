%#!ptex2pdf -l -u -ot '-synctex=1' test-rejsbk
% Copyright (c) 2018 Munehiro Yamamoto, Kenshi Muto.
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

\def\recls@error{\ClassError{review-jsbook}}
\def\recls@warning{\ClassWarning{review-jsbook}}
\def\recls@warningnoline{\ClassWarningNoLine{review-jsbook}}
\def\recls@info{\ClassInfo{review-jsbook}}

%% hook at end of reviewmacro
\let\@endofreviewmacrohook\@empty
\def\AtEndOfReVIEWMacro{%
  \g@addto@macro\@endofreviewmacrohook}
\@onlypreamble\AtEndOfReVIEWMacro

%% fixes to LaTeX2e
\RequirePackage{fix-cm}%%\RequirePackage{fix-cm,exscale}
\IfFileExists{latexrelease.sty}{}{\RequirePackage{fixltx2e}}

%% graphicx: added nosetpagesize
\IfFileExists{platexrelease.sty}{%% is bundled in TL16 or higher release version
\PassOptionsToPackage{nosetpagesize}{graphicx}%%for TL16 or higher version
}{}

\RequirePackage{xkeyval,everypage}%%,etoolbox

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

%% define/set specific paper(s) for review-jsbook.cls
\def\recls@define@paper#1#2{%
  %% \paper@<papername>=> <size>:<width>x<height>+<cutoffset>
  \@namedef{recls@paper@#1}{#1#2}%
}

\def\recls@set@paper#1{%
  \@ifundefined{recls@paper@#1}{%
    \recls@error{Not define such paper: #1}}\relax
  \expandafter\expandafter\expandafter
    \@recls@set@paper\expandafter\expandafter\expandafter
      {\csname recls@paper@#1\endcsname}}
\def\@recls@set@paper#1{%
  \edef\recls@set@js@paper{#1}%
  \PassOptionsToClass{\recls@set@js@paper}{jsbook}}

\def\recls@disable@jsopt#1{%
  \recls@DeclareOption{#1}{\recls@error{option #1: not available}}}

\recls@define@paper{a3}{paper}
\recls@define@paper{a4}{paper}
\recls@define@paper{a5}{paper}
\recls@define@paper{a6}{paper}
\recls@define@paper{b4}{paper}
\recls@define@paper{b5}{paper}
\recls@define@paper{b6}{paper}
\recls@define@paper{a4var}{}
\recls@define@paper{b5var}{}
\recls@define@paper{letter}{paper}
\recls@define@paper{legal}{paper}
\recls@define@paper{executive}{paper}

%% disable some options of jsbook.cls
\@for\recls@tmp:={%
  a4j,a5j,b4j,b5j,%
  8pt,9pt,10pt,11pt,12pt,14pt,17pt,20pt,21pt,25pt,30pt,36pt,43pt,12Q,14Q,%
  10ptj,10.5ptj,11ptj,12ptj,winjis,mingoth}\do{%
  \expandafter\recls@disable@jsopt\expandafter{\recls@tmp}}

%% \recls@set@tombowpaper{<papersize>}
\def\recls@set@tombowpaper#1{%
  \xdef#1{\ifx\recls@hiddenfolio\@empty tombo,\fi#1}}

%% \recls@set@hiddenfolio{<preset>}
%% <preset>: default, marusho-ink (丸正インキ), nikko-pc (日光企画), 
%%    shippo (ねこのしっぽ)
\def\recls@set@hiddenfolio#1{\ifx#1\@empty\else
  \@ifundefined{@makehiddenfolio@#1}{%
    \recls@error{Not define such hiddenfolio: #1}}\relax
  %% set hiddenfolio preset
  \expandafter\let\expandafter\@makehiddenfolio\csname @makehiddenfolio@#1\endcsname
  %% redefine to output \@makehiddenfolio for every page
  \settombowbanner{\hskip-5mm\smash{\hiddenfolio@font\@makehiddenfolio}}%
  \AddEverypageHook{\maketombowbox}%
\fi}

\def\hiddenfolio@font{\reset@font
  \scriptsize\sffamily\baselineskip.8\baselineskip}

%% hiddenfolio=default
\@namedef{@makehiddenfolio@default}{%
  \ifodd\c@page
    \llap{\thepage\hspace{\dimexpr\@tombowbleed}}%
  \else
    \rlap{\hspace{\dimexpr\paperwidth+\@tombowbleed}\thepage}%
  \fi}

%% hiddenfolio=marusho-ink
\@namedef{@makehiddenfolio@marusho-ink}{%
  \gdef\recls@tombobleed{5mm}%
  \@nameuse{@makehiddenfolio@nikko-pc}}

%% hiddenfolio=nikko-pc
\@namedef{@makehiddenfolio@nikko-pc}{%
  \def\recls@hiddfolio{%
    \edef\recls@tmp{\thepage}%
    \lower\dimexpr4pt+\@tombowbleed+.5\paperheight+5\p@\hbox{%
      \vbox{\expandafter\@tfor\expandafter\recls@x\expandafter:\expandafter=\recls@tmp\do{%
        \hbox to 1zw{\hss\recls@x\hss}}}}}%
  \ifodd\c@page
    \rlap{\recls@hiddfolio}%
  \else
    \llap{\recls@hiddfolio\hspace{-\paperwidth}}%
  \fi}

%% hiddenfolio=shippo
\@namedef{@makehiddenfolio@shippo}{%
  \@nameuse{@makehiddenfolio@nikko-pc}}


%% media=print,ebook,preview
\newif\if@cameraready \@camerareadyfalse
\newif\if@pdfhyperlink \@pdfhyperlinkfalse
\DeclareOptionX{cameraready}[print]{\gdef\recls@cameraready{#1}}
\DeclareOptionX{media}[print]{\gdef\recls@cameraready{#1}}

%% 用紙
\DeclareOptionX{paper}[a5]{\gdef\recls@paper{#1}}
\DeclareOptionX{tombopaper}{%
  \gdef\recls@tombowopts{}%%default: auto-detect
  \ifx#1\@empty\else\gdef\recls@tombowopts{tombow-#1}\fi}
\DeclareOptionX{bleed_margin}[3mm]{\gdef\recls@tombobleed{#1}}
%% 隠しノンブルプリセット
\DeclareOptionX{hiddenfolio}{\gdef\recls@hiddenfolio{#1}}%%default: (none)
%% カスタム用紙サイズ
\DeclareOptionX{paperwidth}{\gdef\recls@paperwidth{#1}}
\DeclareOptionX{paperheight}{\gdef\recls@paperheight{#1}}
%% 基本版面 QWLH、天、ノド
\DeclareOptionX{Q}[13]{\gdef\recls@Q{#1}}
\DeclareOptionX{W}[35]{\gdef\recls@W{#1}}
\DeclareOptionX{L}[32]{\gdef\recls@L{#1}}
\DeclareOptionX{H}[22]{\gdef\recls@H{#1}}
\DeclareOptionX{head}[\z@]{\gdef\recls@head{#1}}%[18mm]
\DeclareOptionX{gutter}[\z@]{\gdef\recls@gutter{#1}}%[20mm]
%% headheight,headsep,footskip
\DeclareOptionX{headheight}[\z@]{\gdef\recls@headheight{#1}}
\DeclareOptionX{headsep}[\z@]{\gdef\recls@headsep{#1}}
\DeclareOptionX{footskip}[\z@]{\gdef\recls@footskip{#1}}

%% 表紙・開始番号・通しノンブル
\newif\if@reclscover \@reclscovertrue
\newif\ifrecls@serialpage \recls@serialpagefalse
\DeclareOptionX{cover}[\@empty]{\gdef\recls@forcecover{#1}}
\DeclareOptionX{startpage}[1]{\gdef\recls@startpage{\numexpr#1}}
\DeclareOptionX{serial_pagination}[false]{\csname recls@serialpage#1\endcsname}

\PassOptionsToClass{dvipdfmx,nomag}{jsbook}
\DeclareOptionX*{\PassOptionsToClass{\CurrentOption}{jsbook}}%
\ExecuteOptionsX{media,cameraready,hiddenfolio,%
  paper,tombopaper,bleed_margin,paperwidth,paperheight,%
  Q,W,L,H,head,gutter,headheight,headsep,footskip,%
  cover,startpage,serial_pagination}
\ProcessOptionsX\relax

%% set specific papersize
\recls@set@paper{\recls@paper}
\recls@set@tombowpaper{\recls@tombowopts}

%% camera-ready PDF file preparation for each print, ebook
\def\recls@tmp{preview}\ifx\recls@cameraready\recls@tmp
%%FIXME: media=preview の挙動は保留。例：フォント関係を仕込む
  \@camerareadyfalse\@pdfhyperlinkfalse\@reclscovertrue
\else\def\recls@tmp{print}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinkfalse\@reclscoverfalse
  \IfFileExists{gentombow.sty}{%
    \AtEndOfClass{%
      \RequirePackage[pdfbox,\recls@tombowopts]{gentombow}%
      \settombowbleed{\recls@tombobleed}%
      \recls@set@hiddenfolio{\recls@hiddenfolio}}%
    %%FIXME: gentombow upstreamでトンボ版スタイルコマンドが実装されたら、それに置き換えても良いかな。
    % \AtEndOfClass{%
    %   \PassOptionsToPackage{\recls@tombowopts}{gentombow}%
    %   \RequirePackage[hiddenfolio=\recls@hiddenfolio,tombobleed=\recls@tombobleed]{gentombow-hiddenfolio}%
    % }%
  }{%
    \IfFileExists{gentombow09j.sty}{% from vendor/gentombow.
      \AtEndOfClass{%
        \RequirePackage[pdfbox,\recls@tombowopts]{gentombow09j}%
        \settombowbleed{\recls@tombobleed}%
        \recls@set@hiddenfolio{\recls@hiddenfolio}}%
    }{%
      \recls@warning{%
        package gentombow: not installed^^J
        option tombopaper: not available}%
      \PassOptionsToClass{tombo}{jsbook}%
    }}%
\else\def\recls@tmp{ebook}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinktrue\@reclscovertrue
  \PassOptionsToClass{papersize}{jsbook}%
\else
  \recls@error{No such value of media: \recls@cameraready}%
\fi\fi\fi

%% 内部Unicode動作の時だけupTeXとみなす
\newif\if@recls@uptex \@recls@uptexfalse
\ifx\ucs\@undefined\else \ifnum\ucs"3000="3000
  \@recls@uptextrue
  \PassOptionsToClass{uplatex}{jsbook}
  \PassOptionsToPackage{uplatex}{otf}
\fi\fi

\PassOptionsToClass{10pt}{jsbook}%%<= forcely load 10pt
\LoadClass{jsbook}
%%\typeout{!!! mag: \the\mag}%%=> 1000 -> OK

\IfFileExists{platexrelease.sty}{}{%% is bundled in TL16 or higher release version
\@ifundefined{jsc@setfontsize}{%%compatibility for TL13, TL14, TL15 frozen
\newdimen\jsc@mpt
\jsc@mpt=1\p@
\def\jsc@setfontsize#1#2#3{%
  \@setfontsize#1{#2\jsc@mpt}{#3\jsc@mpt}}
}\relax
}

%% override papersize with custom papersize
\ifx\recls@paperwidth\@empty\else\ifx\recls@paperheight\@empty\else
  \setlength{\paperwidth}{\recls@paperwidth}
  \setlength{\paperheight}{\recls@paperheight}
  \def\recls@tmp{ebook}\ifx\recls@cameraready\recls@tmp
    \AtBeginDvi{\special{papersize=\the\paperwidth,\the\paperheight}}
  \fi
\fi\fi

\def\recls@JYn{\if@recls@uptex JY2\else JY1\fi}%
\def\recls@JTn{\if@recls@uptex JT2\else JT1\fi}%
\def\recls@pfx@{\if@recls@uptex up\else \fi}%
\def\recls@sfx@{\if@recls@uptex \else n\fi}%
\def\recls@sc@le{\if@recls@uptex 0.924714\else 0.961026\fi}%
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
\recls@get@p@{\@tempdima}{\recls@fnt@scale}% \typeout{!!! \recls@fnt@scale}%

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
  {\dimexpr\recls@Q\JQ - 3\JQ}{1.25\dimexpr\recls@Q H - 3H}}
\renewcommand{\tiny}{\jsc@setfontsize\tiny
  {.5\dimexpr\recls@Q\JQ}{.5\dimexpr\recls@Q H + 2H}}
\if@twocolumn
  \renewcommand{\large}{\@setfontsize\large
    {\recls@fnt@scale\dimexpr 18\JQ}{\n@baseline}}
\else
  \renewcommand{\large}{\@setfontsize\large
    {\recls@fnt@scale\dimexpr 18\JQ}{\recls@fnt@scale\dimexpr 27H}}
\fi
\renewcommand{\Large}{\@setfontsize\Large
  {\recls@fnt@scale\dimexpr 20\JQ}{\recls@fnt@scale\dimexpr 30H}}
\renewcommand{\LARGE}{\@setfontsize\LARGE
  {\recls@fnt@scale\dimexpr 24\JQ}{\recls@fnt@scale\dimexpr 36H}}
\renewcommand{\huge}{\@setfontsize\huge
  {\recls@fnt@scale\dimexpr 28\JQ}{\recls@fnt@scale\dimexpr 42H}}
\renewcommand{\Huge}{\@setfontsize\Huge
  {\recls@fnt@scale\dimexpr 32\JQ}{\recls@fnt@scale\dimexpr 48H}}
\renewcommand{\HUGE}{\jsc@setfontsize\HUGE
  {\recls@fnt@scale\dimexpr 36\JQ}{\recls@fnt@scale\dimexpr 54H}}

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
\edef\recls@gutter{\evensidemargin}
\fi

%% 天、地
\ifdim\recls@head>\z@
\setlength\topmargin{\recls@head}%天
\else
\setlength\topmargin\paperheight
\addtolength\topmargin{-\textheight}
\edef\recls@head{\dimexpr\topmargin+1in+\headheight+\headsep}
\setlength\topmargin{.5\topmargin}
\fi
\addtolength\topmargin{-1in}
\addtolength\topmargin{-\headheight}\addtolength\topmargin{-\headsep}

%% load hyperref package
\RequirePackage[dvipdfmx, \if@pdfhyperlink\else draft,\fi
  bookmarks=true,
  bookmarksnumbered=true,
  hidelinks,
  setpagesize=false,
]{hyperref}
\RequirePackage[dvipdfmx]{pxjahyper}

%% more useful macros
%% ----------
%% include fullpage graphics
\let\grnchry@head\recls@head
\let\grnchry@gutter\recls@gutter
\newcommand*\includefullpagegraphics{%
  \clearpage
  \@ifstar
    {\@includefullpagegraphics}%
    {\thispagestyle{empty}\@includefullpagegraphics}
}

\newcommand*\@includefullpagegraphics[2][]{%
    \vbox to \textheight{%
      \vskip-\grnchry@head
      \vbox to \paperheight{\vss
        \hbox to \textwidth{%
          \ifodd\c@page
            \hskip-\dimexpr\oddsidemargin + 1in\relax
          \else
            \hskip-\dimexpr\evensidemargin + 1in\relax
          \fi
          \hbox to \paperwidth{\hss
            \includegraphics[#1]{#2}%
          \hss}%
        \hss}%
      \vss}%
    \vss}%
  \clearpage
}

% 空ページ
\newcommand\oneblankpage{\clearpage\thispagestyle{empty}%
  \hbox{}\newpage\if@twocolumn\hbox{}\newpage\fi}

% 横書き向けの、奇数ページまでの改丁(\cleardoublepage)・偶数ページまでの改丁(\clearoddpage)
\let\cleardoublepage@right\cleardoublepage
\def\cleardoublepage@left{\clearpage\if@twoside\ifodd\c@page
  \hbox{}\thispagestyle{empty}\newpage\if@twocolumn\hbox{}\newpage\fi\fi\fi}
\let\clearoddpage\cleardoublepage@left

% coverオプションによる表紙判定の上書き
\def\recls@tmp{true}\ifx\recls@forcecover\recls@tmp
\@reclscovertrue
\else\def\recls@tmp{false}\ifx\recls@forcecover\recls@tmp
\@reclscoverfalse
\else% それ以外の値は単に無視
\fi\fi

% シンプルな通しノンブル
\ifrecls@serialpage
\renewcommand*{\pagenumbering}[1]{%
  \gdef\thepage{\@arabic\c@page}}
\fi

% 開始ページを変更
\g@addto@macro\frontmatter{\setcounter{page}{\the\recls@startpage}}

% titlepageのsetcounterを使わない
\renewenvironment{titlepage}{%
    \clearpage
    \if@twoside\ifodd\c@page\else
      \hbox{}\thispagestyle{empty}\newpage
      \if@twocolumn\hbox{}\newpage\fi
    \fi\fi
    \if@twocolumn
      \@restonecoltrue\onecolumn
    \else
      \@restonecolfalse\newpage
    \fi
    \thispagestyle{empty}%
    \ifodd\c@page\relax%% \setcounter{page}\@ne
      \else\setcounter{page}\z@\fi %% 2017-02-24
  }%
  {\if@restonecol\twocolumn \else \newpage \fi
    \if@twoside\else
      %% \setcounter{page}\@ne
    \fi}

\listfiles
\endinput
