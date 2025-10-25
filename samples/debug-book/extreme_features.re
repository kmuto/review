= 超複雑機能テスト：エッジケースと高度な構文

この文書では、Re:VIEWの最も複雑な機能とエッジケースを包括的にテストします。

== ネストした複雑なインライン要素

深くネストしたインライン要素: @<b>{太字の中にイタリックがあり、その中にコードがあります}

複雑なリンク構造: @<href>{https://example.com?param=test, 複雑なリンクテキスト}

特殊文字の組み合わせ: @<tt>{"quoted"と'single'と<tag>と&amp;entity;}

== 複雑なコードブロックとキャプション

//list[nested_functions][深くネストした関数構造]{
function complexProcessor(data) {
  return data
    .filter(item => {
      return item.status === 'active' && 
             item.category && 
             item.category.subcategory;
    })
    .map(item => ({
      ...item,
      processed: true,
      metadata: {
        timestamp: Date.now(),
        validator: (value) => {
          if (typeof value !== 'string') return false;
          return /^[a-zA-Z0-9_-]+$/.test(value);
        }
      }
    }))
    .reduce((acc, item) => {
      const key = item.category.name;
      if (!acc[key]) {
        acc[key] = [];
      }
      acc[key].push(item);
      return acc;
    }, {});
}
//}

//emlist[無名コードブロック][ruby]{
# 複雑なRubyメタプログラミング
class DynamicClass
  define_method :dynamic_method do |*args, **kwargs|
    puts "Called with: #{args.inspect}, #{kwargs.inspect}"
    
    singleton_class.define_method :runtime_method do
      "This method was created at runtime"
    end
  end
  
  class << self
    def inherited(subclass)
      subclass.define_singleton_method :custom_new do |*args|
        instance = allocate
        instance.send(:initialize, *args)
        instance.extend(Module.new {
          def extended_behavior
            "Extended at creation time"
          end
        })
        instance
      end
    end
  end
end
//}

//listnum[numbered_code][行番号付きPythonコード]{
import asyncio
from typing import AsyncGenerator, Dict, List, Optional
from dataclasses import dataclass, field

@dataclass
class ComplexDataProcessor:
    cache: Dict[str, any] = field(default_factory=dict)
    
    async def process_stream(self, 
                           data_stream: AsyncGenerator[Dict, None]
                           ) -> AsyncGenerator[Dict, None]:
        async for item in data_stream:
            # 複雑な非同期処理
            processed = await self._complex_transform(item)
            if await self._validate_item(processed):
                yield processed
    
    async def _complex_transform(self, item: Dict) -> Dict:
        # CPU集約的な処理をシミュレート
        await asyncio.sleep(0.001)
        return {
            **item,
            'transformed': True,
            'hash': hash(str(item))
        }
//}

コード参照のテスト: @<list>{nested_functions}は関数型プログラミング、
@<list>{numbered_code}は非同期処理の例です。

== 極度に複雑なテーブル構造

//table[performance_matrix][パフォーマンス比較マトリックス]{
機能	CPU使用率(%)	メモリ(MB)	レイテンシ(ms)	スループット(req/s)	信頼性	コスト
------------
Basic API	15.2	128	45	1000	★★★☆☆	$
Advanced API	32.7	256	12	5000	★★★★☆	$$
Premium API	58.1	512	3	15000	★★★★★	$$$
Enterprise API	75.4	1024	1	50000	★★★★★	$$$$
Custom Solution	95.2	2048	0.5	100000	★★★☆☆	$$$$$
//}

//table[compatibility_matrix][互換性マトリックス（複雑な記号含む）]{
ブラウザ	Windows	macOS	Linux	iOS	Android	備考
------------
Chrome 90+	○	○	○	○	○	全機能対応
Firefox 88+	○	○	○	○	△	一部制限あり
Safari 14+	△	○	△	○	×	WebKit制限
Edge 90+	○	○	○	×	×	IE互換モードなし
Opera 76+	○	○	○	△	△	Chromiumベース
//}

テーブル参照: @<table>{performance_matrix}と@<table>{compatibility_matrix}を
組み合わせて分析します。

== 深い階層のリスト構造

 * レベル1: 基本機能
 ** レベル2: 標準API
 *** レベル3: REST API
 **** レベル4: GET/POST/PUT/DELETE
 ***** レベル5: ペイロード形式
 ****** レベル6: JSON/XML/MessagePack
 ******* レベル7: スキーマ検証
 ******** レベル8: バリデーションルール
 ********* レベル9: エラーハンドリング
 *** レベル3: GraphQL API
 **** レベル4: Query/Mutation/Subscription
 ** レベル2: 認証・認可
 *** レベル3: OAuth 2.0
 *** レベル3: JWT Token
 * レベル1: 高度な機能
 ** レベル2: リアルタイム通信
 *** レベル3: WebSocket
 *** レベル3: Server-Sent Events

順序ありリストの複雑な例:

 1. 第1段階: 設計フェーズ
 a. 要件定義
 i. 機能要件
 A. 必須機能
 I. ユーザー認証
 II. データ管理
 B. オプション機能
 ii. 非機能要件
 b. アーキテクチャ設計
 2. 第2段階: 実装フェーズ
 a. バックエンド開発
 b. フロントエンド開発
 c. API統合
 3. 第3段階: テストフェーズ

== 複雑なミニコラムとエッジケース

//note[重複ID対策]{
同じIDのミニコラムを複数配置した場合の動作テスト。

特殊文字を含むテキスト: @<code>{<script>alert('XSS')</script>}

ネストしたマークアップ: @<b>{deeply.nested.code}
//}

//memo[パフォーマンス最適化のヒント]{
複数のアプローチを比較検討:

 1. @<list>{nested_functions}: 関数型アプローチ
 2. @<list>{numbered_code}: オブジェクト指向アプローチ
 3. @<table>{performance_matrix}: パフォーマンス比較

特に@<table>{compatibility_matrix}で示された互換性問題に注意。
//}

//tip[高度なテクニック]{
実装時の注意点:

 * エスケープ処理: @<tt>{&lt;script&gt;}は@<tt>{<script>}としてレンダリング
 * 特殊文字: @<tt>{"quotes"}, @<tt>{'apostrophes'}, @<tt>{&amp;entities;}
 * ネストした参照: @<list>{nested_functions}内の@<table>{performance_matrix}参照
//}

//warning[セキュリティ重要事項]{
セキュリティ上の重要な考慮事項:

 * 入力値検証: 全ての@<code>{user_input}に対してサニタイゼーション実施
 * SQL インジェクション対策
 * XSS (Cross-Site Scripting) 対策
 * CSRF (Cross-Site Request Forgery) 対策

詳細は@<list>{numbered_code}のバリデーション部分を参照。
//}

//info[デバッグ情報]{
デバッグ時に有用な情報:

 * ログレベル設定
 * スタックトレース詳細出力
 * パフォーマンスプロファイリング

@<table>{performance_matrix}の数値は本番環境での実測値。
//}

//caution[重要な制限事項]{
システムの制限事項と回避策:

 1. 同時接続数制限: 最大10,000接続
 2. ファイルサイズ制限: 1リクエストあたり100MB
 3. レート制限: 1秒あたり1,000リクエスト

対策については@<list>{nested_functions}の実装例を参照。
//}

== 画像とその他のメディア参照

//image[complex_architecture][複雑なシステムアーキテクチャ図]{
//}

//image[data_flow][データフロー図（多層構造）]{
//}

アーキテクチャ概要: @<img>{complex_architecture}に示すように、
多層構造を採用しています。データフローは@<img>{data_flow}を参照。

== 複雑な相互参照とクロスリファレンス

この章では以下の要素を相互参照します:

 * コードサンプル群:
 ** @<list>{nested_functions}: JavaScript関数型プログラミング
 ** @<list>{numbered_code}: Python非同期プログラミング
 * データ比較表:
 ** @<table>{performance_matrix}: パフォーマンス指標
 ** @<table>{compatibility_matrix}: ブラウザ互換性
 * システム図:
 ** @<img>{complex_architecture}: 全体アーキテクチャ
 ** @<img>{data_flow}: データフロー詳細

相互依存関係: @<list>{nested_functions}の実装は@<table>{performance_matrix}の
「Advanced API」行に対応し、@<img>{complex_architecture}の「API Layer」部分
で動作します。

== エッジケースとストレステスト

=== 空のブロック要素

//list[empty_list][空のリストブロック]{
//}

//table[empty_table][空のテーブル]{
項目	値
------------
テスト	OK
//}

//note[empty_note]{
//}

=== 特殊文字の大量使用

Unicode文字のテスト: 🚀📊💻🔧⚡️🛡️🎯📈🔍✨

数学記号: ∑∏∆∇∂∫∮√∞≤≥≠≈±×÷

特殊記号: @<tt>{©®™°±²³¼½¾}

=== 長いテキストブロック

//emlist[long_text_block]{
この非常に長いテキストブロックは、HTMLRendererとHTMLBuilderの両方が
長いコンテンツを正しく処理できるかをテストするためのものです。
テキストには様々な文字種が含まれており、改行、空白、特殊文字、
そして非常に長い単語antidisestablishmentarianismのような
極端なケースも含まれています。また、数値123456789や
記号!@#$%^&*()_+-=[]{}|;':\",./<>?も含まれています。
//}

== まとめと検証結果

この超複雑なテストでは以下を検証しました:

 1. **深いネスト構造**: 9階層のリスト、複雑なインライン要素
 2. **複雑なコードブロック**: 関数型、OOP、非同期処理の組み合わせ
 3. **高度なテーブル**: 複雑な記号、マルチバイト文字を含むセル
 4. **全種類のミニコラム**: note, memo, tip, warning, info, caution
 5. **相互参照の複雑性**: 複数要素間のクロスリファレンス
 6. **エッジケース**: 空要素、特殊文字、長いテキスト
 7. **Unicode対応**: 絵文字、数学記号、特殊記号

すべての機能が@<list>{nested_functions}から@<list>{numbered_code}まで、
@<table>{performance_matrix}から@<table>{compatibility_matrix}まで、
そして@<img>{complex_architecture}と@<img>{data_flow}で示されたように、
BuilderとRendererで同一の出力を生成することを期待します。
