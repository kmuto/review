# Re:VIEW カタログファイル ガイド

Re:VIEW のカタログファイル catalog.ymlについて説明します。

## カタログファイルとは

Re:VIEW フォーマットで記述された各ファイルを特に一冊の本（例えばPDFやEPUB）にまとめる際に、どのようにそれらのファイルを構造化するかを指定するファイルです。
現在はカタログファイルと言えばcatalog.ymlのことを指します。

## catalog.ymlを用いた場合の設定方法

catalog.yml内で、`PREDEF`（前付け）、`CHAPS`（本編）、`APPENDIX`（付録、連番あり）、`POSTDEF`（後付け、連番なし）を記述します。CHAPSのみ必須です。

```yaml
PREDEF:
  - intro.re

CHAPS:
  - ch01.re
  - ch02.re

APPENDIX:
  - appendix.re

POSTDEF:
  - postscript.re
```

本編に対して、「部」構成を加えたい場合、`CHAPS`を段階的にして記述します。部の指定については、タイトル名でもファイル名でもどちらでも使えます。

```yaml
CHAPS:
  - ch01.re
  - 第1部:
    - ch02.re
    - ch03.re
  - pt02.re:
    - ch04.re
```

（旧バージョンの利用者の方へ: `PART`という項目はありません。`CHAPS`に記述してください）

## バージョン 1.3以前について

`APPENDIX`は指定できません。`POSTDEF`を使ってください。

## バージョン 1.2以前について

1.2以前のRe:VIEWではカタログファイルとしてPREDEF, CHAPS, POSTDEF, PARTという独立した4つのファイルを使用していました。
そのため、当時のバージョンを利用する際にはcatalog.ymlではなくそちらを記述する必要があります。

現在のRe:VIEWはcatalog.ymlを用いた方法と旧バージョンが使用していたCHAPS, PREDEF, POSTDEF, PARTを用いた方法と両方をサポートしています。
ただしcatalog.ymlが存在する場合、そちらが優先されます。
