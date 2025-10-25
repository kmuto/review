= マルチコンテンツ機能テスト

この文書では複数章にまたがる参照や、異なるコンテンツタイプの組み合わせをテストします。

== コンテンツの混在

=== コードとテーブルの複雑な組み合わせ

//list[api_implementation][API実装例]{
class APIService {
  constructor(config) {
    this.endpoints = {
      'GET /users': this.getUsers.bind(this),
      'POST /users': this.createUser.bind(this),
      'PUT /users/:id': this.updateUser.bind(this),
      'DELETE /users/:id': this.deleteUser.bind(this)
    };
  }
  
  async getUsers(req, res) {
    try {
      const users = await User.findAll({
        attributes: ['id', 'name', 'email', 'status'],
        where: req.query.filters || {},
        limit: req.query.limit || 10,
        offset: req.query.offset || 0
      });
      
      res.json({
        data: users,
        pagination: {
          total: await User.count(),
          page: Math.floor(req.query.offset / req.query.limit) + 1
        }
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }
}
//}

//table[api_endpoints][API エンドポイント仕様]{
メソッド	パス	説明	認証	レート制限	レスポンス形式
------------
GET	/users	ユーザー一覧取得	Required	100/min	JSON Array
POST	/users	新規ユーザー作成	Required	10/min	JSON Object
PUT	/users/:id	ユーザー情報更新	Required	50/min	JSON Object
DELETE	/users/:id	ユーザー削除	Admin	5/min	Status Code
GET	/users/:id	特定ユーザー取得	Optional	200/min	JSON Object
//}

@<list>{api_implementation}の実装は@<table>{api_endpoints}の仕様に基づいています。

=== ネストしたリストとコードの組み合わせ

API設計のベストプラクティス:

 1. RESTful原則の遵守
 a. 適切なHTTPメソッドの使用
 i. GET: リソース取得 (@<list>{api_implementation}のgetUsers参照)
 ii. POST: リソース作成
 iii. PUT: リソース更新
 iv. DELETE: リソース削除
 b. ステートレス設計
 c. 統一されたURL構造
 2. セキュリティ対策
 a. 認証・認可の実装
 b. 入力値検証
 c. レート制限 (@<table>{api_endpoints}参照)
 3. パフォーマンス最適化
 a. キャッシング戦略
 b. ページネーション実装
 c. データベースクエリ最適化

=== 複雑なテーブル構造

//table[response_codes][HTTPレスポンスコード詳細]{
カテゴリ	コード	名称	説明	使用場面	例
------------
成功	200	OK	正常処理完了	GET、PUT成功時	ユーザー取得成功
成功	201	Created	リソース作成成功	POST成功時	新規ユーザー登録
成功	204	No Content	処理成功・レスポンスなし	DELETE成功時	ユーザー削除完了
クライアントエラー	400	Bad Request	不正なリクエスト	バリデーションエラー	必須フィールド未入力
クライアントエラー	401	Unauthorized	認証が必要	認証情報なし	トークン未提供
クライアントエラー	403	Forbidden	アクセス権限なし	権限不足	管理者権限が必要
クライアントエラー	404	Not Found	リソースが存在しない	存在しないID指定	削除済みユーザー
クライアントエラー	409	Conflict	リソースの競合	重複データ	既存メールアドレス
クライアントエラー	422	Unprocessable Entity	処理不可能なエンティティ	ビジネスロジックエラー	無効なステータス遷移
サーバーエラー	500	Internal Server Error	サーバー内部エラー	予期しないエラー	データベース接続エラー
サーバーエラー	503	Service Unavailable	サービス利用不可	メンテナンス中	システムメンテナンス
//}

== 高度なエラーハンドリング

//list[error_handling][包括的エラーハンドリング実装]{
class ErrorHandler {
  static handleError(error, req, res, next) {
    // ログ出力
    console.error(`[${new Date().toISOString()}] ${error.stack}`);
    
    // エラータイプの判定
    if (error.name === 'ValidationError') {
      return res.status(422).json({
        error: {
          type: 'validation_error',
          message: 'Validation failed',
          details: error.details.map(detail => ({
            field: detail.path,
            message: detail.message,
            value: detail.value
          }))
        }
      });
    }
    
    if (error.name === 'UnauthorizedError') {
      return res.status(401).json({
        error: {
          type: 'authentication_error',
          message: 'Authentication required',
          code: 'AUTH_REQUIRED'
        }
      });
    }
    
    if (error.name === 'ForbiddenError') {
      return res.status(403).json({
        error: {
          type: 'authorization_error',
          message: 'Insufficient permissions',
          required_role: error.requiredRole
        }
      });
    }
    
    // デフォルトエラー（500）
    res.status(500).json({
      error: {
        type: 'internal_error',
        message: 'An unexpected error occurred',
        request_id: req.id
      }
    });
  }
}
//}

エラーハンドリングの詳細は@<table>{response_codes}を参照し、
実装例は@<list>{error_handling}で確認できます。

== ミニコラムでの複雑な参照

//note[API設計の重要なポイント]{
@<list>{api_implementation}の実装では以下の点に注意:

 1. エラーハンドリング: @<list>{error_handling}のパターン適用
 2. レスポンス形式: @<table>{response_codes}の標準に準拠
 3. セキュリティ: @<table>{api_endpoints}の認証要件遵守

特に@<table>{response_codes}の422エラーは、
@<list>{error_handling}の ValidationError 処理と対応しています。
//}

//tip[パフォーマンス最適化テクニック]{
実装時のパフォーマンス向上策:

 * データベースクエリ最適化:
 ** @<list>{api_implementation}のfindAll()でのselective loading
 ** インデックスの適切な設定
 * キャッシング戦略:
 ** Redis/Memcached活用
 ** @<table>{api_endpoints}のGETエンドポイントでの適用
 * レート制限実装:
 ** @<table>{api_endpoints}で定義された制限値の実装
 ** @<list>{error_handling}での429エラー処理
//}

//warning[セキュリティ脆弱性対策]{
重要なセキュリティ考慮事項:

 1. SQL インジェクション対策
 - @<list>{api_implementation}のクエリパラメータ処理
 - ORMの適切な使用
 2. 認証・認可の実装
 - @<table>{api_endpoints}の認証要件
 - JWTトークンの適切な検証
 3. 入力値検証
 - @<list>{error_handling}のValidationError処理
 - @<table>{response_codes}の400/422エラー活用

@<table>{response_codes}の401/403エラーの使い分けが重要です。
//}

== 複雑なデータ構造のテスト

//list[complex_data_structures][複雑なデータ構造操作]{
class DataTransformer {
  static async transformUserData(rawData) {
    const processedData = rawData.map(user => {
      // ネストしたデータ構造の処理
      const profile = {
        personal: {
          firstName: user.first_name,
          lastName: user.last_name,
          fullName: `${user.first_name} ${user.last_name}`,
          email: user.email?.toLowerCase(),
          phone: user.phone ? this.formatPhone(user.phone) : null
        },
        professional: {
          title: user.job_title,
          department: user.department,
          level: this.calculateLevel(user.experience_years),
          skills: user.skills ? user.skills.split(',').map(s => s.trim()) : []
        },
        metadata: {
          created_at: new Date(user.created_at),
          updated_at: new Date(user.updated_at),
          is_active: user.status === 'active',
          permissions: this.parsePermissions(user.role)
        }
      };
      
      return profile;
    });
    
    // 複雑なフィルタリングと集約
    const activeUsers = processedData.filter(user => user.metadata.is_active);
    const departmentGroups = activeUsers.reduce((groups, user) => {
      const dept = user.professional.department;
      if (!groups[dept]) {
        groups[dept] = [];
      }
      groups[dept].push(user);
      return groups;
    }, {});
    
    return {
      total: processedData.length,
      active: activeUsers.length,
      departments: Object.keys(departmentGroups).map(dept => ({
        name: dept,
        count: departmentGroups[dept].length,
        averageLevel: this.calculateAverageLevel(departmentGroups[dept])
      }))
    };
  }
}
//}

//table[data_transformation_matrix][データ変換マトリックス]{
元フィールド	変換後	変換ルール	バリデーション	デフォルト値
------------
first_name	personal.firstName	文字列変換	必須、2-50文字	N/A
last_name	personal.lastName	文字列変換	必須、2-50文字	N/A
email	personal.email	小文字変換	メール形式	null
phone	personal.phone	フォーマット適用	電話番号形式	null
job_title	professional.title	文字列変換	0-100文字	"Unspecified"
department	professional.department	文字列変換	必須	"General"
experience_years	professional.level	レベル計算	0-50年	1
skills	professional.skills	配列分割	カンマ区切り	[]
status	metadata.is_active	真偽値変換	"active"/"inactive"	false
role	metadata.permissions	権限パース	JSON形式	{}
//}

データ変換の実装（@<list>{complex_data_structures}）は
@<table>{data_transformation_matrix}の仕様に従って行われます。

== まとめと統合テスト

この文書では以下の高度な機能を組み合わせてテストしました:

 1. **API実装**: @<list>{api_implementation}
 2. **エラーハンドリング**: @<list>{error_handling}  
 3. **データ変換**: @<list>{complex_data_structures}
 4. **API仕様**: @<table>{api_endpoints}
 5. **レスポンスコード**: @<table>{response_codes}
 6. **データ変換仕様**: @<table>{data_transformation_matrix}

相互関係:
- @<list>{api_implementation} ← → @<table>{api_endpoints}
- @<list>{error_handling} ← → @<table>{response_codes}
- @<list>{complex_data_structures} ← → @<table>{data_transformation_matrix}

全ての参照が正しく解決され、BuilderとRendererで同一の出力が
生成されることを検証します。
