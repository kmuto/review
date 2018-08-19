#`plistings` パッケージ

`plistings` パッケージは，`listings` パッケージを pLaTeX 上で用いる際の日本語対応処理を
強化するためのパッケージである．
[LuaTeX-ja](https://osdn.jp/projects/luatex-ja/wiki/FrontPage) 中の `lltjp-listings.sty` を
ベースとしている．

ライセンスは今まで明記していなかったが，MIT License とした (2010-10-11)．

## 注意点（と，現在の制約）

* 実行には e-TeX 拡張が必要である（`\scantokens`, `\detokenize` 利用のため）．
  最近の TeX Live, W32TeX では `platex` と打つと標準で e-TeX 拡張が有効になっている．
* 内部で文字コード 0 の文字 (`^^@`, NUL) を日本語処理命令として用いている．
  そのため，NUL を含んだソースリストを出力することは出来なくなる．
* 「LaTeX へのエスケープ」内では，和文文字を含んだ制御綴が試験的にできるようになったが，
   エスケープ内に書かれた NUL は自動的に取り除かれる．

