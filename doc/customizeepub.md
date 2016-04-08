# EPUB ローカルルールへの対応方法
Re:VIEW の review-epubmaker が生成する EPUB ファイルは IDPF 標準に従っており、EpubCheck を通過する正規のものです。

しかし、ストアによってはこれに固有のローカルルールを設けていることがあり、それに合わせるためには別途 EPUB ファイルに手を入れる必要があります。幸い、ほとんどのルールは EPUB 内のメタ情報ファイルである OPF ファイルにいくつかの情報を加えることで対処できます。

Re:VIEW の設定ファイルは config.yml を使うものとします。

## 電書協ガイドライン
* http://ebpaj.jp/counsel/guide

電書協ガイドラインの必須属性を満たすには、次の設定を config.yml に加えます。

```yaml
opf_prefix: {ebpaj: "http://www.ebpaj.jp/"}
opf_meta: {"ebpaj:guide-version": "1.1.3"}
```

これは次のように展開されます。

```xml
<package …… prefix="ebpaj: http://www.ebpaj.jp/">
 ……
    <meta property="ebpaj:guide-version">1.1.3</meta>
```

ただし、Re:VIEW の生成する EPUB は、ファイルやフォルダの構成、スタイルシートの使い方などにおいて電書協ガイドラインには準拠していません。

## iBooks ストア
デフォルトでは、iBooks で EPUB を見開きで開くと、左右ページの間に影が入ります。
これを消すには、次のように指定します。

```yaml
opf_prefix: {ibooks: "http://vocabulary.itunes.apple.com/rdf/ibooks/vocabulary-extensions-1.0/"}
opf_meta: {"ibooks:binding": "false"}
```

すでにほかの定義があるときには、たとえば次のように追加してください。

```yaml
opf_prefix: {ebpaj: "http://www.ebpaj.jp/", ibooks: "http://vocabulary.itunes.apple.com/rdf/ibooks/vocabulary-extensions-1.0/"}
opf_meta: {"ebpaj:guide-version": "1.1.3", "ibooks:binding": "false"}
```
