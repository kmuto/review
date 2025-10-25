%#!ptex2pdf -l -u -ot '-synctex=1' test-rejlreqbk
% Copyright (c) 2018-2021 Kenshi Muto.
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

\IfFileExists{plautopatch.sty}{\RequirePackage{plautopatch}}{}
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{review-jlreq}[2021/09/07 Re:VIEW 5.3 upLaTeX/LuaLaTeX class modified for jlreq.cls]

%% hook at end of reviewmacro
\let\@endofreviewmacrohook\@empty
\def\AtEndOfReVIEWMacro{%
  \g@addto@macro\@endofreviewmacrohook}
\@onlypreamble\AtEndOfReVIEWMacro

\RequirePackage{fix-cm}%%\RequirePackage{fix-cm,exscale}
\IfFileExists{latexrelease.sty}{}{\RequirePackage{fixltx2e}}

%% amsmath: override \@ifstar with \new@ifnextchar in amsgen.sty
\let\ltx@ifstar\@ifstar%%as \@ifstar of LaTeX kernel

%% graphicx: added nosetpagesize
\IfFileExists{platexrelease.sty}{%% is bundled in TL16 or higher release version
\PassOptionsToPackage{nosetpagesize}{graphicx}%%for TL16 or higher version
}{}

\RequirePackage{xkeyval,everypage,ifthen}

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

%% \recls@set@hiddenfolio{<preset>}
%% <preset>: default, marusho-ink (丸正インキ), nikko-pc (日光企画),
%%    shippo (ねこのしっぽ)
\def\recls@set@hiddenfolio#1{\ifx#1\@empty\else
  \@ifundefined{@makehiddenfolio@#1}{%
    \recls@error{Not define such hiddenfolio: #1}}\relax
  %% set hiddenfolio preset
  \expandafter\let\expandafter\@makehiddenfolio\csname @makehiddenfolio@#1\endcsname
  \@makehiddenfolio
\fi}

\def\hiddenfolio@font{\reset@font
  \scriptsize\sffamily\baselineskip.8\baselineskip}

%% hiddenfolio=default
\@namedef{@makehiddenfolio@default}{%
  \jlreqtrimmarkssetup{banner = { top-gutter = { \hiddenfolio@font\selectfont \thepage} } } }

%% hiddenfolio=marusho-ink
\@namedef{@makehiddenfolio@marusho-ink}{%
  \gdef\recls@tombobleed{5mm}% XXX: won't work. should set via bleed_margin
  \@nameuse{@makehiddenfolio@nikko-pc}}

%% hiddenfolio=nikko-pc
\@namedef{@makehiddenfolio@nikko-pc}{%
  \jlreqtrimmarkssetup{banner = { center-gutter= { in = { \hiddenfolio@font\selectfont \thepage} } } } }

%% hiddenfolio=shippo
\@namedef{@makehiddenfolio@shippo}{%
  \@nameuse{@makehiddenfolio@nikko-pc}}

%% media=print,ebook,preview
\newif\if@cameraready \@camerareadyfalse
\newif\if@pdfhyperlink \@pdfhyperlinkfalse
\newif\if@pdftombo \@pdftombofalse
\newif\if@reclscover \@reclscovertrue
\newif\ifrecls@coverfitpage \recls@coverfitpagefalse
\newif\ifrecls@serialpage \recls@serialpagefalse
\DeclareOptionX{cameraready}[print]{\gdef\recls@cameraready{#1}}
\DeclareOptionX{media}[print]{\gdef\recls@cameraready{#1}}
\DeclareOptionX{tombopaper}[a4]{\gdef\recls@tombopaper{#1}}
\DeclareOptionX{bleed_margin}[3mm]{\gdef\recls@tombobleed{#1}}
\DeclareOptionX{cover}[\@empty]{\gdef\recls@forcecover{#1}}
\DeclareOptionX{cover_fit_page}[false]{\csname recls@coverfitpage#1\endcsname}
\DeclareOptionX{startpage}[1]{\gdef\recls@startpage{\numexpr #1\relax}}
\DeclareOptionX{serial_pagination}[false]{\csname recls@serialpage#1\endcsname}

%% 隠しノンブルプリセット
\DeclareOptionX{hiddenfolio}{\gdef\recls@hiddenfolio{#1}}%%default: (none)

% jlreqのオプションについては https://github.com/abenori/jlreq/blob/master/README-ja.md を参照
\PassOptionsToClass{book,paper=a5}{jlreq}% クラスで必ず使うオプションの指定。デフォルトをA5にしておく
\DeclareOptionX*{\PassOptionsToClass{\CurrentOption}{jlreq}}%
\ExecuteOptionsX{media,cameraready,tombopaper,bleed_margin,cover,startpage,serial_pagination,hiddenfolio}
\ProcessOptionsX\relax

\def\recls@tmp{preview}\ifx\recls@cameraready\recls@tmp
  \@camerareadyfalse\@pdfhyperlinktrue\@pdftombofalse\@reclscovertrue
\else\def\recls@tmp{print}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinkfalse\@pdftombotrue\@reclscoverfalse
\else\def\recls@tmp{ebook}\ifx\recls@cameraready\recls@tmp
  \@camerareadytrue\@pdfhyperlinktrue\@pdftombofalse\@reclscovertrue
\else
  \recls@error{No such value of media: \recls@cameraready}%
\fi\fi\fi

\LoadClass{jlreq}

% coverオプションによる表紙判定の上書き
\def\recls@tmp{true}\ifx\recls@forcecover\recls@tmp
\@reclscovertrue
\else\def\recls@tmp{false}\ifx\recls@forcecover\recls@tmp
\@reclscoverfalse
\else% それ以外の値は単に無視
\fi\fi

% トンボ設定
\if@pdftombo
  \RequirePackage[trimmarks_paper=\recls@tombopaper,bleed_margin=\recls@tombobleed]{jlreq-trimmarks}
  % https://github.com/abenori/jlreq/blob/master/jlreq-trimmarks-ja.md を参照
  \jlreqtrimmarkssetup{banner={}}
  % 隠しノンブル
  \AtEndOfClass{%
    \recls@set@hiddenfolio{\recls@hiddenfolio}}
\fi

% エンジンとドライバの情報。jlreq-trimmarksが定義されていればそっちから持ってくる。
% 定義されていなければjlreqから持ってくる
\def\recls@engine{}
\def\recls@driver{}
\ifdefined\jlreq@trimmarks@engine
  \ifx l\jlreq@trimmarks@engine\def\recls@engine{lualatex}\def\recls@driver{luatex}\fi
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

% jlreq-trimmarksを使わないとき(ebook)には紙面サイズを自前で指定する
\if@pdftombo
\else
  \ifx luatex\recls@driver\else
    \newdimen\pdfpaperwidth  \pdfpaperwidth\paperwidth
    \newdimen\pdfpaperheight \pdfpaperheight\paperheight
    \AtBeginDvi{\special{papersize=\the\pdfpaperwidth,\the\pdfpaperheight}}
  \fi
\fi

\RequirePackage[\recls@driver]{graphicx}
\RequirePackage[\recls@driver,table]{xcolor}

% luatex固有
\def\recls@tmp{luatex}\ifx\recls@tmp\recls@driver
  \DeclareGraphicsRule{.ai}{pdf}{.ai}{}
  \usepackage[no-math]{fontspec}
\else
  \RequirePackage[T1]{fontenc}
  \RequirePackage{lmodern}%\ttdefault: lmtt
\fi

\RequirePackage{textcomp}%T1/TS1
\RequirePackage{tikz}
\usetikzlibrary{calc}
\RequirePackage{multirow}
\RequirePackage{amsmath}
\RequirePackage{amssymb}
\RequirePackage{amsthm}
\RequirePackage{needspace}
\RequirePackage{alltt}
\RequirePackage{float}
\RequirePackage{upquote}
\RequirePackage{bm}
\RequirePackage[table]{xcolor}
\RequirePackage{tcolorbox}
\tcbuselibrary{xparse,hooks,skins,breakable}
\RequirePackage{ulem}
\RequirePackage{tabularx}

\def\recls@tmp{luatex}
\RequirePackage[\recls@driver, \if@pdfhyperlink\else draft,\fi
  \ifx\recls@tmp\recls@driver unicode,\fi
  bookmarks=true,
  bookmarksnumbered=true,
  hidelinks,
  setpagesize=false,
]{hyperref}

\def\recls@tmp{uplatex}\ifx\recls@tmp\recls@engine
  \RequirePackage{pxjahyper}
\fi

%% better line breaks for long urls
\AtBeginDocument{%
  %% modified url.sty
  \def\UrlBreaks{%
    \do\0\do\1\do\2\do\3\do\4\do\5\do\6\do\7\do\8\do\9%
    \do\A\do\B\do\C\do\D\do\E\do\F\do\G\do\H\do\I\do\J\do\K\do\L\do\M\do\N%
    \do\O\do\P\do\Q\do\R\do\S\do\T\do\U\do\V\do\W\do\X\do\Y\do\Z%
    \do\a\do\b\do\c\do\d\do\e\do\f\do\g\do\h\do\i\do\j\do\k\do\l\do\m\do\n%
    \do\o\do\p\do\q\do\r\do\s\do\t\do\u\do\v\do\w\do\x\do\y\do\z%
    %%
    \do\.\do\@\do\\\do\/\do\!\do\_\do\|\do\;\do\>\do\]%
    \do\)\do\,\do\?\do\&\do\'\do+\do\=\do\#}%
}

%% include fullpage graphics
\edef\grnchry@head{\dimexpr\topmargin+1in+\headheight+\headsep}
\edef\grnchry@gutter{\evensidemargin}
\newcommand*\includefullpagegraphics{%
  \clearpage
  \ltx@ifstar
    {\@includefullpagegraphics}%
    {\thispagestyle{empty}\@includefullpagegraphics}
}

\newcommand*\@includefullpagegraphics[2][]{%
  \if@tate
    \vbox to \textheight{%
      \ifodd\c@page
        \vskip-\dimexpr\evensidemargin - \topskip + 1in\relax
      \else
        \vskip-\dimexpr\oddsidemargin - \topskip + 1in\relax
      \fi
      \vbox to \paperwidth{\vss
        \hbox to \textwidth{%
          \hskip-\grnchry@head\relax
          \hbox to \paperheight{\hss
            \rotatebox{90}{\includegraphics[#1]{#2}}%
          \hss}%
        \hss}%
      \vss}%
    \vss}%
  \else
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
  \fi
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

%% 行のサンプル。\makelines{行数} で「■□■□…」からなる行を指定行数配置する
\def\makelines#1{%
  \@tempcnta\z@\relax
  \def\@makeline@f@size{\f@size}%
  \@whilenum\@tempcnta<#1\do{%
    \advance\@tempcnta\@ne\relax
    \noindent\rlap{\the\@tempcnta}\nobreak
    \makelines@neline\par}%
}
\def\makelines@unit@#10#2\relax{%
  \ifx!#2!\relax □\else\relax ■\fi}%
\newcounter{makelines@unit}
\def\makelines@neline{%
  \c@makelines@unit\@ne
  \@whilenum\c@makelines@unit<\dimexpr(\textwidth + \Cwd)/\Cwd\do{%
    \expandafter\makelines@unit@\the\c@makelines@unit0\relax
  \advance\c@makelines@unit\@ne}%
}

% シンプルな通しノンブル
\ifrecls@serialpage
  \jlreqsetup{frontmatter_pagination=continuous}
  \if@openright\else\jlreqsetup{mainmatter_pagebreak=clearpage}\fi
\fi

% 開始ページを変更
\let\recls@frontmatterorg\frontmatter
\renewcommand*{\frontmatter}{
  \recls@frontmatterorg
  \setcounter{page}{\the\recls@startpage}
}

% titlepageのsetcounterを使わない
\renewenvironment{titlepage}{%
  \if@twocolumn
    \@restonecoltrue\onecolumn
  \else
    \@restonecolfalse\newpage
  \fi
  \thispagestyle{empty}%
}{%
  \if@restonecol\twocolumn\else\newpage\fi
}

% pdfpagesのトンボずれへの対処
\if@pdftombo
  \def\recls@patch@pdfpages{%
    \patchcmd{\AM@output}{%
      \setlength{\@tempdima}{\AM@xmargin}%
      \edef\AM@xmargin{\the\@tempdima}%
      \setlength{\@tempdima}{\AM@ymargin}%
      \edef\AM@ymargin{\the\@tempdima}%
    }{%
      \setlength{\@tempdima}{\AM@xmargin+1in}%
      \edef\AM@xmargin{\the\@tempdima}%
      \setlength{\@tempdima}{\AM@ymargin-1in}%
      \edef\AM@ymargin{\the\@tempdima}%
    }%
  }{\message{patch for pdfpages applied}}{}
  \AtBeginDocument{\@ifpackageloaded{pdfpages}{\recls@patch@pdfpages}{}}
\fi

%% 表紙のノンブル
\def\coverpagezero#1{\expandafter\@coverpagezero\csname c@#1\endcsname}
\def\@coverpagezero#1{cover}

%% xkanjiskip抽象化
\newcommand*\setxkanjiskip[1]{%
  \def\recls@tmp{lualatex}\ifx\recls@tmp\recls@engine
    \ltjsetparameter{xkanjiskip={#1}}
  \else
    \xkanjiskip=#1\relax
  \fi
}

%% 脚注がページをまたいで泣き別れさせない
\interfootnotelinepenalty\@M

%% 代替定義
\def\reviewleftcurlybrace{\{}
\def\reviewrightcurlybrace{\}}

%% 後注を見出しではなくchapter前にし、endnoteカウンタを新規に用意する
\jlreqsetup{endnote_position=_chapter}
\newcounter{reclsendnote}
\setcounter{reclsendnote}{0}
\if@tate
  \renewcommand*{\thereclsendnote}{\jlreq@open@bracket@before@space\inhibitglue（\tatechuyoko{\@arabic\c@reclsendnote}）\inhibitglue}
\else
  \renewcommand*{\thereclsendnote}{(\arabic{reclsendnote}\hbox{}）\inhibitglue}
\fi
\def\jlreq@endnotecounter{reclsendnote}
\ifthenelse{\equal{\jlreq@article@type}{article}}{}{\@addtoreset{reclsendnote}{chapter}}

\listfiles
\endinput
