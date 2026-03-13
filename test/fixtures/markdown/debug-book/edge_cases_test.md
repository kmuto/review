# エッジケースと国際化テスト

この文書では、Re:VIEWの境界条件、エラーケース、国際化対応をテストします。

## 国際化とマルチバイト文字

### 各国語のテスト

<div id="multilingual_comments">

**多言語コメント付きコード**

```
// English: Hello World implementation
// 日本語：ハローワールドの実装
// 中文：你好世界的实现
// 한국어: 헬로 월드 구현
// العربية: تنفيذ مرحبا بالعام
// עברית: יישום שלום עולם
// Русский: Реализация Hello World
// Ελληνικά: Υλοποίηση Hello World

function multilingualGreeting(language) {
  const greetings = {
    'en': 'Hello, World!',
    'ja': 'こんにちは、世界！',
    'zh': '你好，世界！',
    'ko': '안녕하세요, 세계!',
    'ar': 'مرحبا بالعالم!',
    'he': 'שלום עולם!',
    'ru': 'Привет, мир!',
    'el': 'Γεια σου κόσμε!',
    'de': 'Hallo Welt!',
    'fr': 'Bonjour le monde!',
    'es': '¡Hola mundo!',
    'pt': 'Olá mundo!',
    'it': 'Ciao mondo!',
    'th': 'สวัสดีโลก!',
    'hi': 'नमस्ते दुनिया!'
  };

  return greetings[language] || greetings['en'];
}
```

</div>

### Unicode文字とエモジ

<div id="unicode_characters">

**Unicode文字分類表**

| 分類 | 文字例 | Unicode範囲 | 説明 | 表示 |
| :-- | :-- | :-- | :-- | :-- |
| 基本ラテン | ABC abc | U+0000-U+007F | ASCII文字 | ✓ |
| ラテン1補助 | àáâãäå | U+0080-U+00FF | 西欧語文字 | ✓ |
| ひらがな | あいうえお | U+3040-U+309F | 日本語ひらがな | ✓ |
| カタカナ | アイウエオ | U+30A0-U+30FF | 日本語カタカナ | ✓ |
| 漢字 | 漢字中文字 | U+4E00-U+9FFF | CJK統合漢字 | ✓ |
| ハングル | 한글조선글 | U+AC00-U+D7AF | 韓国語文字 | ✓ |
| アラビア文字 | العربية | U+0600-U+06FF | アラビア語 | ✓ |
| エモジ | 😀🎉💻🚀 | U+1F600-U+1F64F | 絵文字 | ✓ |
| 数学記号 | ∑∏∆√∞ | U+2200-U+22FF | 数学記号 | ✓ |

</div>

Unicode テスト文字列の例: `😀🎉💻🚀⚡️🛡️🎯📊📈🔍✨`

## 極端なケースのテスト

### 非常に長い文字列

<div id="very_long_strings">

**超長文字列処理**

```
function processVeryLongString() {
  // 非常に長い文字列（実際の処理では外部ファイルから読み込む）
  const extremelyLongString = "A".repeat(10000);

  // 長いURL
  const longUrl = "https://example.com/api/v1/extremely/long/path/with/many/segments/" +
                  "and/query/parameters?param1=value1&param2=value2&param3=value3&" +
                  "very_long_parameter_name_that_exceeds_normal_limits=corresponding_very_long_value";

  // 長いSQL（疑似コード）
  const longQuery = `
    SELECT
      users.id,
      users.first_name,
      users.last_name,
      users.email,
      profiles.bio,
      profiles.avatar_url,
      departments.name as department_name,
      departments.description as department_description,
      roles.name as role_name,
      roles.permissions,
      projects.title as project_title,
      projects.description as project_description,
      tasks.title as task_title,
      tasks.status as task_status
    FROM users
    LEFT JOIN profiles ON users.id = profiles.user_id
    LEFT JOIN departments ON users.department_id = departments.id
    LEFT JOIN roles ON users.role_id = roles.id
    LEFT JOIN project_members ON users.id = project_members.user_id
    LEFT JOIN projects ON project_members.project_id = projects.id
    LEFT JOIN tasks ON projects.id = tasks.project_id
    WHERE users.status = 'active'
      AND departments.status = 'active'
      AND projects.status IN ('planning', 'in_progress', 'testing')
      AND tasks.assigned_to = users.id
    ORDER BY users.last_name, users.first_name, projects.created_at DESC
    LIMIT 1000 OFFSET 0;
  `;

  return {
    stringLength: extremelyLongString.length,
    urlLength: longUrl.length,
    queryLength: longQuery.length
  };
}
```

</div>

### 空の要素と特殊ケース

<div id="empty_and_special_cases">

**空要素と特殊ケース**

```
// 空の関数
function emptyFunction() {
  // コメントのみ
}

// 空の配列とオブジェクト
const emptyArray = [];
const emptyObject = {};
const nullValue = null;
const undefinedValue = undefined;

// 特殊な文字列
const emptyString = "";
const whitespaceString = "   \t\n\r   ";
const zeroWidthSpace = "​"; // U+200B

// 特殊な数値
const zero = 0;
const negativeZero = -0;
const infinity = Infinity;
const negativeInfinity = -Infinity;
const notANumber = NaN;

// 制御文字
const tab = "\t";
const newline = "\n";
const carriageReturn = "\r";
const formFeed = "\f";
const verticalTab = "\v";
const backspace = "\b";
```

</div>

## エラー処理とリカバリ

<div id="error_recovery">

**エラー処理とリカバリ機構**

```
class RobustProcessor {
  async processWithRetry(operation, maxRetries = 3) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        console.warn(`Attempt ${attempt} failed:`, error.message);

        if (attempt === maxRetries) {
          throw new Error(`All ${maxRetries} attempts failed. Last error: ${error.message}`);
        }

        // Exponential backoff
        const delay = Math.pow(2, attempt) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  validateInput(input) {
    const errors = [];

    // Null/undefined チェック
    if (input === null || input === undefined) {
      errors.push("Input cannot be null or undefined");
    }

    // 型チェック
    if (typeof input !== 'object') {
      errors.push("Input must be an object");
    }

    // 必須フィールドチェック
    const requiredFields = ['id', 'name', 'type'];
    requiredFields.forEach(field => {
      if (!input[field]) {
        errors.push(`Required field '${field}' is missing`);
      }
    });

    // 文字列長チェック
    if (input.name && input.name.length > 255) {
      errors.push("Name field exceeds maximum length (255 characters)");
    }

    // 特殊文字チェック
    if (input.name && /[<>\"'&]/.test(input.name)) {
      errors.push("Name contains invalid characters");
    }

    if (errors.length > 0) {
      throw new ValidationError("Input validation failed", errors);
    }

    return true;
  }
}

class ValidationError extends Error {
  constructor(message, details) {
    super(message);
    this.name = 'ValidationError';
    this.details = details;
  }
}
```

</div>

## 特殊文字とエスケープ処理

<div id="special_characters">

**特殊文字エスケープテーブル**

| 文字 | HTML実体参照 | URL エンコード | JSON エスケープ | SQL エスケープ | 説明 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| < | &lt; | %3C | \u003c | < | 小なり記号 |
| > | &gt; | %3E | \u003e | > | 大なり記号 |
| & | &amp; | %26 | \u0026 | & | アンパサンド |
| " | &quot; | %22 | \" | "" | ダブルクォート |
| ' | &#39; | %27 | \u0027 | '' | シングルクォート |
| / | &#x2F; | %2F | \/ | / | スラッシュ |
| \ | &#x5C; | %5C | \\ | \\ | バックスラッシュ |
|  | &nbsp; | %20 | \u0020 |   | 非改行スペース |
| \\t | &#x09; | %09 | \t | \t | タブ文字 |
| \\n | &#x0A; | %0A | \n | \n | 改行文字 |

</div>

エスケープ処理のテスト文字列: `<script>alert("XSS")</script>` `'DROP TABLE users; --` `{"malformed": json,`}

## 複雑なリスト参照とクロスリファレンス

複雑な参照チェーン:

1. 国際化対応: <span class="listref"><a href="./edge_cases_test.html#multilingual_comments">リスト4.1</a></span>の実装
2. 文字種対応: <span class="tableref"><a href="./edge_cases_test.html#unicode_characters">表4.1</a></span>の分類
3. 長文字列処理: <span class="listref"><a href="./edge_cases_test.html#very_long_strings">リスト4.2</a></span>の最適化
4. エラー処理: <span class="listref"><a href="./edge_cases_test.html#error_recovery">リスト4.4</a></span>の実装
5. セキュリティ: <span class="tableref"><a href="./edge_cases_test.html#special_characters">表4.2</a></span>のエスケープ
6. 特殊ケース: <span class="listref"><a href="./edge_cases_test.html#empty_and_special_cases">リスト4.3</a></span>の処理

相互依存関係: - <span class="listref"><a href="./edge_cases_test.html#multilingual_comments">リスト4.1</a></span> → <span class="tableref"><a href="./edge_cases_test.html#unicode_characters">表4.1</a></span> - <span class="listref"><a href="./edge_cases_test.html#very_long_strings">リスト4.2</a></span> → <span class="listref"><a href="./edge_cases_test.html#error_recovery">リスト4.4</a></span> - <span class="tableref"><a href="./edge_cases_test.html#special_characters">表4.2</a></span> → <span class="listref"><a href="./edge_cases_test.html#empty_and_special_cases">リスト4.3</a></span>

## ストレステストとパフォーマンス

<div class="note">

**パフォーマンステスト結果**

大量データでのテスト結果:

* 文字列処理: <span class="listref"><a href="./edge_cases_test.html#very_long_strings">リスト4.2</a></span>で10,000文字の処理時間 < 1ms
* Unicode処理: <span class="tableref"><a href="./edge_cases_test.html#unicode_characters">表4.1</a></span>の全文字種で正常表示
* エラー処理: <span class="listref"><a href="./edge_cases_test.html#error_recovery">リスト4.4</a></span>で99.9%の成功率
* セキュリティ: <span class="tableref"><a href="./edge_cases_test.html#special_characters">表4.2</a></span>で全エスケープ正常動作

<span class="listref"><a href="./edge_cases_test.html#multilingual_comments">リスト4.1</a></span>の16言語すべてで正常表示を確認。


</div>

<div class="warning">

**メモリ使用量注意**

大量データ処理時の注意点:

1. <span class="listref"><a href="./edge_cases_test.html#very_long_strings">リスト4.2</a></span>の処理では最大512MB使用
2. <span class="tableref"><a href="./edge_cases_test.html#unicode_characters">表4.1</a></span>のレンダリングで一時的なメモリ急増
3. <span class="listref"><a href="./edge_cases_test.html#error_recovery">リスト4.4</a></span>のリトライ処理でメモリリーク可能性

対策として<span class="listref"><a href="./edge_cases_test.html#empty_and_special_cases">リスト4.3</a></span>で示したnullチェックが重要。


</div>



## まとめ

このエッジケーステストでは以下を検証:

1. **国際化**: 16言語対応 (<span class="listref"><a href="./edge_cases_test.html#multilingual_comments">リスト4.1</a></span>)
2. **Unicode**: 9種類の文字体系 (<span class="tableref"><a href="./edge_cases_test.html#unicode_characters">表4.1</a></span>)
3. **極端ケース**: 超長文字列とnull処理 (<span class="listref"><a href="./edge_cases_test.html#very_long_strings">リスト4.2</a></span>, <span class="listref"><a href="./edge_cases_test.html#empty_and_special_cases">リスト4.3</a></span>)
4. **エラー処理**: 堅牢性確保 (<span class="listref"><a href="./edge_cases_test.html#error_recovery">リスト4.4</a></span>)
5. **セキュリティ**: 完全エスケープ (<span class="tableref"><a href="./edge_cases_test.html#special_characters">表4.2</a></span>)

全ての機能でBuilderとRendererの完全互換性を期待します。

