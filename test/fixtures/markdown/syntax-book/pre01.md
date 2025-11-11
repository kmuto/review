# 前書き

PREDEF内に列挙したものは前付として章採番なしです。後付のPOSTDEFも同様。

PREDEF内/POSTDEFのリストの採番表記は「リスト1」のようになります: <span class="listref"><a href="./pre01.html#main1">リスト1</a></span>

（正確にはi18n.yml/locale.ymlのformat_number_header_without_chapterが使われます）

<div id="main1">

<p class="caption">main()</p>

```
int
main(int argc, char **argv)
{
    puts("OK");
    return 0;
}
```

</div>

図（<span class="imgref"><a href="./pre01.html#fractal">図1</a></span>）、表（<span class="tableref"><a href="./pre01.html#tbl1">表1</a></span>）も同様に章番号なしです。

<figure id="fractal">
<img src="fractal" alt="フラクタル">
<figcaption>フラクタル</figcaption>
</figure>

<div id="tbl1">

<p class="caption">前付表</p>

| A | B |
| :-- | :-- |
| C | D |

</div>

