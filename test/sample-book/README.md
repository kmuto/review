# Re:VIEWサンプル書籍データ

Re:VIEW ( http://github.com/kmuto/review )で書籍データを作るためのサンプルファイルです。

必要なファイルはsrc/ディレクトリ内にあります。srcディレクトリで「review-epubmaker config.yml」と実行すればEPUBが、「review-pdfmaker config.yml」とすればPDFが生成されます(PDFの生成にはpLaTeXとdvipdfmxが必要です)。

Ruby製のビルドツールであるrakeがインストールされている環境の場合、「rake pdf」を実行すればPDFが、「rake epub」を実行すればEPUBが生成されます。また、「rake html_all」を実行すればHTMLが生成されます。
