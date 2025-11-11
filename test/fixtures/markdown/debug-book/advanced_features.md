# 高度な機能テスト

この文書では、Re:VIEWの高度な機能を包括的にテストします。

## インライン要素の組み合わせ

複雑なインライン要素: **太字**と*イタリック*、`コード`と**太字**、 [リンクテキスト](https://example.com)などを組み合わせて使用します。

特殊文字のテスト: `<>&"'`、エスケープが必要な文字を含みます。

### 複雑なリスト参照とコード参照

複数のコードブロックを参照: <span class="listref"><a href="./advanced_features.html#sample1">リスト2.1</a></span>、<span class="listref"><a href="./advanced_features.html#sample2">リスト2.2</a></span>、<span class="listref"><a href="./advanced_features.html#advanced_code">リスト2.3</a></span>

## 複数のコードブロック

<div id="sample1">

**基本的なPythonコード**

```
def hello_world():
    """簡単な挨拶関数"""
    print("Hello, World!")
    return True

if __name__ == "__main__":
    hello_world()
```

</div>

<div id="sample2">

**Rubyのクラス定義**

```
class Calculator
  def initialize
    @history = []
  end

  def add(a, b)
    result = a + b
    @history << "#{a} + #{b} = #{result}"
    result
  end

  def multiply(a, b)
    result = a * b
    @history << "#{a} * #{b} = #{result}"
    result
  end
end
```

</div>

<div id="advanced_code">

**JavaScriptの非同期処理**

```
async function fetchUserData(userId) {
  try {
    const response = await fetch(`/api/users/${userId}`);

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const userData = await response.json();
    return {
      success: true,
      data: userData,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error('Failed to fetch user data:', error);
    return {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

// 使用例
fetchUserData(123)
  .then(result => {
    if (result.success) {
      console.log('User data:', result.data);
    } else {
      console.error('Error:', result.error);
    }
  });
```

</div>

コードの説明: <span class="listref"><a href="./advanced_features.html#sample1">リスト2.1</a></span>は基本的な関数、<span class="listref"><a href="./advanced_features.html#sample2">リスト2.2</a></span>はオブジェクト指向、 <span class="listref"><a href="./advanced_features.html#advanced_code">リスト2.3</a></span>は非同期処理を示しています。

## 複雑なテーブル

<div id="performance_comparison">

**パフォーマンス比較表**

| 言語 | 実行時間(ms) | メモリ使用量(MB) | コード行数 | 複雑度 |
| :-- | :-- | :-- | :-- | :-- |
| C++ | 15.2 | 8.4 | 245 | 高 |
| Rust | 18.7 | 6.2 | 189 | 高 |
| Go | 22.1 | 12.8 | 156 | 中 |
| Python | 125.4 | 28.5 | 98 | 低 |
| JavaScript | 45.6 | 35.2 | 123 | 中 |
| Java | 32.8 | 45.7 | 234 | 高 |
| C# | 28.9 | 38.1 | 201 | 中 |

</div>

パフォーマンステーブル（<span class="tableref"><a href="./advanced_features.html#performance_comparison">表2.1</a></span>）では、 各言語の特性が明確に示されています。

### ネストした構造のリスト

* レベル1の項目A
  * レベル2の項目A-1
    * レベル3の項目A-1-a
    * レベル3の項目A-1-b

  * レベル2の項目A-2

* レベル1の項目B
  * レベル2の項目B-1
    * レベル3の項目B-1-a
      * レベル4の項目B-1-a-i
      * レベル4の項目B-1-a-ii


  * レベル2の項目B-2


1. 順序ありリスト項目1
2. 順序ありリスト項目2a. サブ項目2-ab. サブ項目2-bi. サブサブ項目2-b-iii. サブサブ項目2-b-ii
3. 順序ありリスト項目3

## 複数種類のミニコラム

<div class="note">

**重要な注意事項**

この機能は実験的なものであり、本番環境での使用は推奨されません。 必ず十分なテストを行ってから使用してください。

特に以下の点に注意が必要です：

* パフォーマンスへの影響
* セキュリティリスク
* 互換性の問題


</div>

<div class="memo">

**開発者向けメモ**

この実装では以下のデザインパターンを使用しています：

* Factory Pattern: オブジェクトの生成を抽象化
* Observer Pattern: イベント駆動アーキテクチャ
* Strategy Pattern: アルゴリズムの動的な切り替え

詳細は<span class="listref"><a href="./advanced_features.html#advanced_code">リスト2.3</a></span>のコメントを参照してください。


</div>

<div class="tip">

**プロのヒント**

開発効率を向上させるために、以下のツールの使用を強く推奨します：

1. IDE: Visual Studio Code または IntelliJ IDEA 2. バージョン管理: Git with conventional commits 3. テストフレームワーク: Jest (JavaScript) / pytest (Python) 4. CI/CD: GitHub Actions または GitLab CI

これらのツールを組み合わせることで、<span class="tableref"><a href="./advanced_features.html#performance_comparison">表2.1</a></span>で 示されたような品質の高いコードを効率的に開発できます。


</div>

<div class="warning">

**セキュリティ警告**

この機能を使用する際は、以下のセキュリティリスクに注意してください：

* SQLインジェクション攻撃
* XSS（クロスサイトスクリプティング）攻撃
* CSRF（クロスサイトリクエストフォージェリ）攻撃
* 機密情報の漏洩リスク

<span class="listref"><a href="./advanced_features.html#advanced_code">リスト2.3</a></span>のような非同期処理では、特に入力値の検証が重要です。


</div>

## 複雑な引用と参照

この章では、前述の内容を踏まえ、 複数のコード例（<span class="listref"><a href="./advanced_features.html#sample1">リスト2.1</a></span>、<span class="listref"><a href="./advanced_features.html#sample2">リスト2.2</a></span>、<span class="listref"><a href="./advanced_features.html#advanced_code">リスト2.3</a></span>） およびパフォーマンステーブル（<span class="tableref"><a href="./advanced_features.html#performance_comparison">表2.1</a></span>）を 相互参照しながら解説します。

### 画像参照（仮想）

![システムアーキテクチャ図](architecture_diagram)

<span class="imgref"><a href="./advanced_features.html#architecture_diagram">図2.1</a></span>に示すように、マイクロサービスアーキテクチャでは 各サービスが独立してデプロイ可能です。

## キーワードと特殊表記

重要なキーワード: **マイクロサービス**、**API Gateway**、 **Service Mesh**、**Container Orchestration**

数式的表記: `O(n log n)`、`2^n`、`sum(i=1 to n) = n(n+1)/2`

ファイル名参照: `config.yaml`、`docker-compose.yml`

## まとめ

この文書では、Re:VIEWの高度な機能を包括的にテストしました：

* 複雑なインライン要素の組み合わせ
* 複数のコードブロックと相互参照
* 多層のネストしたリスト構造
* 複雑なテーブル定義
* 各種ミニコラム（note、memo、tip、warning）
* 章参照、画像参照、その他の参照機能

全ての機能が<span class="listref"><a href="./advanced_features.html#sample1">リスト2.1</a></span>から<span class="listref"><a href="./advanced_features.html#advanced_code">リスト2.3</a></span>まで、 および<span class="tableref"><a href="./advanced_features.html#performance_comparison">表2.1</a></span>で示されたように、 BuilderとRendererで同一の出力を生成することが期待されます。

