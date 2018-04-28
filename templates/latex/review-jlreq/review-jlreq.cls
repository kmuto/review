% Re:VIEW + jlreq
% Copyright 2018 Kenshi Muto <kmuto@debian.org>
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{review-jlreq}[2018/4/28]
\LoadClassWithOptions{jlreq}

% クラスオプション
% munepiさんのを踏襲しておいたほうがいいかな
% hanmengrid(boolean)→これは今回実装対応しない
% hanmen(boolean)→版面表示。便利なので入れたい
% draft(boolean)→これはjlreqでいける？
% tombo(boolean)→トンボ有効化 (done)
% mentuke(boolean)→これはどうしようかな
% cameraready=pdf/print(string)→設定どうしよう
% paper=a5+3mm→これだとパースをまるまる複製しないとかな…。jlreq-trimmarksのオプションとだいぶ違う
% toc:break-before=right, index:break-before=both あたりは完全白ページが問題になる同人誌だと怖い？
% 白ページでもノンブルを打つ という設定(とpagestyleが必要？)
% 扉画像の指定はreviewmacroのパラメータのほうでやらせるべきかな

% Unused global option [book] が出るの嫌だなぁ(実際はchapterに必要)
% \setkeyしたら影響が…なんとかなるんかなこれ
\DeclareOption{book}{}
\DeclareOption{dvipdfmx}{}

\newif\if@review@jlreq@tombo
\@review@jlreq@tombofalse
\DeclareOption{tombo}{\@review@jlreq@tombotrue}% トンボ有効化
\DeclareOption*{\rjreq@setkey}
\def\rjreq@setkey{\expandafter\@rjreq@setkey\expandafter{\CurrentOption}}
\def\@rjreq@setkey{\setkeys{rjreq}}
% トンボのバナー、bleed幅、色の指定
% バナーにはむしろ通し番号とか入れたくなるが…
\def\@review@jlreq@tombo@banner{\jobname\space(\number\year-\two@digits\month-\two@digits\day\space\two@digits\hour:\two@digits\minute)}
\def\@review@jlreq@tombo@bleed{3mm}
\def\@review@jlreq@tombo@color{cmyk}
\define@key{rjreq}{tombo:banner}{\def\@review@jlreq@tombo@banner{#1}}
\define@key{rjreq}{tombo:bleed}{\def\@review@jlreq@tombo@bleed{#1}}
\define@key{rjreq}{tombo:color}{\def\@review@jlreq@tombo@color{#1}}

\ExecuteOptions{}% 初期有効化するもの
\ProcessOptions\relax

%% fixes to LaTeX2e
\RequirePackage{fix-cm,exscale}
\IfFileExists{latexrelease.sty}{}{\RequirePackage{fixltx2e}}
\IfFileExists{platexrelease.sty}{%% is bundled in TL16 or higher release version

\PassOptionsToPackage{nosetpagesize}{graphicx}%%for TL16 or higher version
}{}

% トンボ指定
\if@review@jlreq@tombo
% FIXME:パッケージオプションのtrimmarks_paper, showをどう渡すか
\RequirePackage{jlreq-trimmarks}
\fi

% エンジンとドライバの情報。jlreq-trimmarksが定義されていればそっちから持ってくる。
% 定義されていなければjlreqから持ってくる
\def\review@jlreq@engine{}
\def\review@jlreq@driver{}
\ifdefined\jlreq@trimmarks@engine
  \ifx l\jlreq@trimmarks@engine\def\review@jlreq@engine{lualatex}\fi
  \ifx u\jlreq@trimmarks@engine\def\review@jlreq@engine{uplatex}\fi
  \ifx p\jlreq@trimmarks@engine\def\review@jlreq@engine{platex}\fi
\else% jlreqから持ってくる
  \ifx l\jlreq@engine\def\review@jlreq@engine{lualatex}\fi
  \ifx u\jlreq@engine\def\review@jlreq@engine{uplatex}\fi
  \ifx p\jlreq@engine\def\review@jlreq@engine{platex}\fi
\fi
\ifdefined\jlreq@trimmarks@driver
  \ifx f\jlreq@trimmarks@driver\def\review@jlreq@driver{dvipdfmx}\fi
  \ifx s\jlreq@trimmarks@driver\def\review@jlreq@driver{dvips}\fi
  \ifx o\jlreq@trimmarks@driver\def\review@jlreq@driver{dviout}\fi
\else% jlreqから持ってくる
  \ifx l\jlreq@engine
    \def\review@jlreq@driver{lualatex}
  \else
    \def\review@jlreq@driver{dvipdfmx}
  \fi
\fi

\RequirePackage[\review@jlreq@driver]{graphicx}
\RequirePackage[\review@jlreq@driver,table]{xcolor}

% jlreq-trimmarksへ追加オプション渡し(事前にxcolorが必要)
% trimmarks_widthを指定したくなるケースはまずないとしてよいかな…bannerもどうするか
\if@review@jlreq@tombo
  \jlreqtrimmarkssetup{bleed_margin=\@review@jlreq@tombo@bleed,color=\@review@jlreq@tombo@color,banner=\@review@jlreq@tombo@banner}% デフォルトは3mm, cmyk
\fi

\RequirePackage[T1]{fontenc}
\RequirePackage{textcomp}%T1/TS1
\RequirePackage{lmodern}%\ttdefault: lmtt
\RequirePackage[\review@jlreq@driver, bookmarks=true, bookmarksnumbered=true,
  % colorlinks=true,
  hidelinks,
setpagesize=false]{hyperref}[2016/06/24 v6.83q]
\RequirePackage[\review@jlreq@driver]{pxjahyper}[2012/05/27 v0.2]

\RequirePackage{tikz}%requires xcolor
\usetikzlibrary{calc}
\RequirePackage{tcolorbox}
\tcbuselibrary{xparse,hooks,skins,breakable}
\RequirePackage{multirow}
\RequirePackage{amsmath}
\RequirePackage{amssymb}
\RequirePackage{bm}
\RequirePackage{needspace}
