# ベストプラクティス & セキュリティガイド

このドキュメントでは、TerraformとAWS SAMを使用したサーバーレスアプリケーション開発のベストプラクティスとセキュリティ考慮事項をまとめています。

## 📋 目次

- [コード管理](#コード管理)
- [インフラストラクチャ管理](#インフラストラクチャ管理)
- [Lambda開発](#lambda開発)
- [セキュリティ](#セキュリティ)
- [コスト最適化](#コスト最適化)
- [モニタリング](#モニタリング)
- [CI/CD](#cicd)

## コード管理

### バージョン管理

✅ **推奨事項**

```bash
# .gitignore で機密情報を除外
*.tfstate
*.tfstate.backup
.aws-sam/
.env

# コミット前に検証
terraform fmt -recursive
sam validate
```

❌ **避けるべき**

- terraform.tfstate をGitにコミット
- AWS認証情報をコードに含める
- 機密情報を .tfvars に平文で保存

### ブランチ戦略

```
main (本番環境)
  ↑
develop (開発環境)
  ↑
feature/* (機能ブランチ)
```

**推奨フロー:**
1. feature ブランチで開発
2. develop にマージ → 自動的に dev 環境にデプロイ
3. 検証後、main にマージ → 自動的に prod 環境にデプロイ

### コードレビュー

**必須チェック項目:**
- [ ] Terraform plan の確認
- [ ] IAM権限の最小化
- [ ] セキュリティグループの設定
- [ ] コスト影響の確認
- [ ] テストの実施

## インフラストラクチャ管理

### Terraform ベストプラクティス

#### 1. State管理

✅ **推奨: リモートバックエンド**

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "terraform-sam-demo/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

**メリット:**
- チーム開発での状態共有
- State ロックによる同時実行防止
- バージョニングによる履歴管理

#### 2. モジュール化

✅ **推奨構成**

```
terraform/
├── modules/
│   ├── vpc/
│   ├── lambda/
│   └── dynamodb/
└── environments/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

**メリット:**
- コードの再利用性
- 環境ごとの設定分離
- テストの容易性

#### 3. 変数管理

✅ **推奨**

```hcl
# 環境変数で認証情報を管理
export TF_VAR_database_password="secret"

# またはAWS Secrets Managerから取得
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}
```

❌ **避けるべき**

```hcl
# 平文でパスワードを記載
variable "database_password" {
  default = "mypassword123"  # NG!
}
```

#### 4. リソースの命名規則

✅ **推奨**

```hcl
# <project>-<environment>-<resource>-<description>
resource "aws_s3_bucket" "sam_artifacts" {
  bucket = "${var.project_name}-${var.environment}-sam-artifacts-${data.aws_caller_identity.current.account_id}"
}
```

**命名ルール:**
- 小文字とハイフンのみ使用
- 環境名を含める
- グローバルリソースはアカウントIDを含める

### Terraform Tips

```bash
# フォーマット自動修正
terraform fmt -recursive

# プランを保存して確認
terraform plan -out=tfplan
less tfplan

# 特定リソースのみ適用
terraform apply -target=aws_s3_bucket.sam_artifacts

# リソースをStateから削除（リソース自体は削除しない）
terraform state rm aws_s3_bucket.old_bucket

# リソースのインポート
terraform import aws_s3_bucket.existing bucket-name
```

## Lambda開発

### Lambda関数のベストプラクティス

#### 1. ハンドラー設計

✅ **推奨: 単一責任の原則**

```python
def lambda_handler(event, context):
    """
    Lambda エントリーポイント
    - 入力検証
    - ビジネスロジック実行
    - レスポンス生成
    """
    try:
        # 入力検証
        validate_input(event)

        # ビジネスロジック
        result = process_request(event)

        # レスポンス生成
        return create_response(200, result)

    except ValidationError as e:
        return create_response(400, {'error': str(e)})
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})
```

#### 2. 環境変数の活用

✅ **推奨**

```python
import os

# 環境変数から設定を取得
TABLE_NAME = os.environ['DYNAMODB_TABLE']
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
ENVIRONMENT = os.environ['ENVIRONMENT']

# 環境に応じた動作
if ENVIRONMENT == 'prod':
    # 本番環境の処理
    pass
```

#### 3. エラーハンドリング

✅ **推奨**

```python
import traceback
import logging

logger = logging.getLogger()

def lambda_handler(event, context):
    try:
        # 処理
        pass
    except botocore.exceptions.ClientError as e:
        # AWS SDK のエラー
        error_code = e.response['Error']['Code']
        logger.error(f"AWS Error: {error_code}")

        if error_code == 'AccessDeniedException':
            # 権限エラーの処理
            pass
    except Exception as e:
        # 予期しないエラー
        logger.error(f"Error: {str(e)}")
        logger.error(traceback.format_exc())

        # アラート送信（本番環境）
        if os.environ['ENVIRONMENT'] == 'prod':
            send_alert(str(e))
```

#### 4. パフォーマンス最適化

**コネクションの再利用**

✅ **推奨**

```python
# グローバルスコープでクライアントを初期化
# Lambda コンテナの再利用時に接続が維持される
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def lambda_handler(event, context):
    # tableを使用（接続を再利用）
    table.put_item(Item=item)
```

❌ **避けるべき**

```python
def lambda_handler(event, context):
    # 毎回新しい接続を作成（遅い）
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
```

**メモリサイズの最適化**

```yaml
# sam/template.yaml
Globals:
  Function:
    MemorySize: 256  # 128, 256, 512, 1024... と調整
    Timeout: 30
```

**推奨手順:**
1. CloudWatch Logs で実際の使用メモリを確認
2. Lambda Power Tuning ツールで最適値を測定
3. コストとパフォーマンスのバランスを考慮

#### 5. ロギング

✅ **推奨: 構造化ログ**

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # 構造化ログ
    logger.info(json.dumps({
        'event': 'request_received',
        'request_id': context.request_id,
        'path': event['path'],
        'method': event['httpMethod']
    }))
```

**ログレベルの使い分け:**
- `DEBUG`: 詳細なデバッグ情報
- `INFO`: 通常の動作ログ
- `WARNING`: 警告（処理は継続）
- `ERROR`: エラー（処理失敗）
- `CRITICAL`: 致命的エラー

### Lambda レイヤー

✅ **推奨用途**

- 共通ライブラリ（utils, helpers）
- 重い依存関係（Pandas, NumPyなど）
- 共通設定

**レイヤーの構成:**

```
layers/common/
└── python/
    ├── lib/
    │   └── utils.py
    └── requirements.txt
```

**レイヤーの作成:**

```bash
cd layers/common
pip install -r requirements.txt -t python/
```

## セキュリティ

### IAM権限の最小化

✅ **推奨: 最小権限の原則**

```hcl
# 特定のテーブルのみアクセス許可
data "aws_iam_policy_document" "lambda_dynamodb_access" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.main.arn
    ]

    # 条件を追加
    condition {
      test     = "StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["ITEM#"]
    }
  }
}
```

❌ **避けるべき**

```hcl
# すべてのリソースへのアクセス許可
statement {
  effect = "Allow"
  actions = ["dynamodb:*"]
  resources = ["*"]  # NG!
}
```

### シークレット管理

✅ **推奨: AWS Secrets Manager**

```python
import boto3
import json

def get_secret(secret_name):
    """Secrets Manager からシークレットを取得"""
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# 使用例
db_credentials = get_secret('prod/database/credentials')
```

**Terraform での作成:**

```hcl
resource "aws_secretsmanager_secret" "api_key" {
  name = "${var.environment}/api/key"
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key
}
```

❌ **避けるべき**

```python
# 環境変数に直接APIキーを設定
API_KEY = os.environ['API_KEY']  # 平文で保存される
```

### VPCセキュリティ

✅ **推奨構成**

```hcl
# セキュリティグループ: アウトバウンドのみ
resource "aws_security_group" "lambda" {
  # インバウンド: 不要（Lambdaは受信しない）

  # アウトバウンド: 必要最小限
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to external APIs"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "HTTPS to VPC endpoints"
  }
}
```

### API セキュリティ

#### 1. 認証

✅ **推奨オプション**

**API Key:**
```yaml
# sam/template.yaml
ApiGateway:
  Type: AWS::Serverless::Api
  Properties:
    Auth:
      ApiKeyRequired: true
```

**IAM 認証:**
```yaml
Auth:
  DefaultAuthorizer: AWS_IAM
```

**Lambda Authorizer (推奨):**
```yaml
Auth:
  DefaultAuthorizer: LambdaTokenAuthorizer
  Authorizers:
    LambdaTokenAuthorizer:
      FunctionArn: !GetAtt AuthorizerFunction.Arn
```

#### 2. レート制限

```yaml
# sam/template.yaml
ApiGateway:
  Type: AWS::Serverless::Api
  Properties:
    ThrottleSettings:
      RateLimit: 1000   # リクエスト/秒
      BurstLimit: 2000  # バースト時の上限
```

#### 3. CORS設定

✅ **推奨: 必要なオリジンのみ許可**

```yaml
Cors:
  AllowOrigin: "'https://example.com'"  # 特定のドメイン
  AllowMethods: "'GET,POST'"            # 必要なメソッドのみ
  AllowHeaders: "'Content-Type,Authorization'"
```

### DynamoDB セキュリティ

#### 暗号化

```hcl
# terraform/dynamodb.tf
resource "aws_dynamodb_table" "main" {
  # サーバーサイド暗号化（デフォルトで有効）
  server_side_encryption {
    enabled = true
  }

  # KMS暗号化（追加のセキュリティが必要な場合）
  # server_side_encryption {
  #   enabled     = true
  #   kms_key_arn = aws_kms_key.dynamodb.arn
  # }
}
```

#### バックアップ

```hcl
# Point-in-Time Recovery（本番環境推奨）
point_in_time_recovery {
  enabled = var.environment == "prod" ? true : false
}
```

## コスト最適化

### Lambda コスト削減

1. **ARM64 アーキテクチャ**
   ```yaml
   Architectures:
     - arm64  # x86_64 より 20% 安い
   ```

2. **適切なメモリサイズ**
   - 過剰なメモリは無駄
   - 不足するとタイムアウト
   - Lambda Power Tuning で最適化

3. **タイムアウト設定**
   ```yaml
   Timeout: 30  # 必要最小限に設定
   ```

### DynamoDB コスト削減

1. **課金モードの選択**
   - 予測可能: PROVISIONED + オートスケーリング
   - 不規則: PAY_PER_REQUEST

2. **GSIの最適化**
   - 必要な属性のみプロジェクション
   - 使用しないGSIは削除

3. **TTLの活用**
   ```hcl
   ttl {
     enabled        = true
     attribute_name = "ExpiresAt"
   }
   ```

### VPC コスト削減

1. **NAT Gateway の最適化**
   - 開発環境: 単一 NAT Gateway
   - 本番環境: 高可用性のため複数

2. **VPC Endpoint の活用**
   ```hcl
   # Gateway Endpoint（無料）
   resource "aws_vpc_endpoint" "s3" {
     service_name = "com.amazonaws.ap-northeast-1.s3"
   }
   ```

### CloudWatch コスト削減

1. **ログ保持期間**
   ```hcl
   retention_in_days = var.environment == "prod" ? 90 : 7
   ```

2. **メトリクスフィルター**
   - 必要なメトリクスのみ作成

## モニタリング

### CloudWatch Alarms

✅ **必須アラーム**

```hcl
# Lambda エラー
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
}
```

### X-Ray トレーシング

✅ **推奨設定**

```yaml
# sam/template.yaml
Globals:
  Function:
    Tracing: Active  # X-Ray を有効化
```

**メリット:**
- リクエストの可視化
- パフォーマンスボトルネックの特定
- エラーの根本原因分析

### Lambda Insights

```yaml
# 本番環境で有効化推奨
Layers:
  - !Ref LambdaInsightsLayerArn
```

## CI/CD

### GitHub Actions ベストプラクティス

#### 1. Secrets管理

```yaml
# .github/workflows/deploy.yml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

#### 2. Environment Protection

```yaml
jobs:
  deploy-prod:
    environment: prod  # 承認が必要
```

**設定:**
1. GitHub リポジトリ → Settings → Environments
2. "prod" 環境を作成
3. Required reviewers を設定

#### 3. Terraform Plan のレビュー

```yaml
- name: Terraform Plan
  id: plan
  run: terraform plan -out=tfplan

- name: Comment PR
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        body: `## Terraform Plan\n${process.env.PLAN}`
      })
```

### デプロイの自動化

✅ **推奨フロー**

```
Code Push
  ↓
Automated Tests
  ↓
Terraform Plan (PR Comment)
  ↓
Manual Review & Approval
  ↓
Terraform Apply
  ↓
SAM Deploy
  ↓
Integration Tests
  ↓
Smoke Tests
```

### ロールバック戦略

```bash
# CloudFormation スタックのロールバック
aws cloudformation rollback-stack \
  --stack-name terraform-sam-demo-prod-app

# Terraform の特定バージョンに戻す
git checkout <previous-commit>
terraform apply
```

## チェックリスト

### デプロイ前

- [ ] コードレビュー完了
- [ ] Terraform plan 確認
- [ ] セキュリティチェック（IAM、SG）
- [ ] コスト影響の見積もり
- [ ] テスト実施（ユニット、統合）
- [ ] ドキュメント更新

### デプロイ後

- [ ] CloudWatch Alarms 確認
- [ ] API エンドポイントの疎通確認
- [ ] Lambda 関数の実行確認
- [ ] CloudWatch Logs の確認
- [ ] コスト監視の開始
- [ ] チームへの通知

### 本番環境のみ

- [ ] Point-in-Time Recovery 有効化
- [ ] Lambda Insights 有効化
- [ ] 複数 NAT Gateway（高可用性）
- [ ] CloudWatch Alarms の通知設定
- [ ] バックアップ戦略の確認

---

このガイドは定期的に更新してください。新しいベストプラクティスや学びがあれば追加しましょう！
