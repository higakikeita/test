# アーキテクチャ設計書

## 📋 概要

このドキュメントでは、TerraformとAWS SAMを組み合わせたサーバーレスアプリケーションのアーキテクチャについて説明します。

## 🏗️ システムアーキテクチャ

### アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                    ┌────▼─────┐
                    │ API GW   │
                    │ (REST)   │
                    └────┬─────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
   │ Lambda   │    │ Lambda   │    │ Lambda   │
   │  API     │    │Processor │    │Scheduled │
   └────┬─────┘    └────┬─────┘    └────┬─────┘
        │               │               │
        │          ┌────▼─────┐        │
        │          │ DynamoDB │◄───────┘
        └─────────►│ Streams  │
                   └────┬─────┘
                        │
                   ┌────▼─────┐
                   │ DynamoDB │
                   │  Table   │
                   └──────────┘

[VPC]
├── Public Subnet (x2)
│   ├── NAT Gateway
│   └── Internet Gateway
└── Private Subnet (x2)
    ├── Lambda Functions
    ├── VPC Endpoints (S3, DynamoDB)
    └── Security Groups

[Monitoring]
├── CloudWatch Logs
├── CloudWatch Metrics
├── CloudWatch Alarms
├── CloudWatch Dashboard
└── X-Ray Tracing
```

## 🎯 責務分離

### Terraform が管理するリソース

**インフラストラクチャ層**

1. **ネットワーク**
   - VPC
   - サブネット（パブリック/プライベート）
   - インターネットゲートウェイ
   - NAT ゲートウェイ
   - ルートテーブル
   - VPCエンドポイント（S3、DynamoDB）
   - セキュリティグループ

2. **データストア**
   - DynamoDB テーブル
   - DynamoDB Streams
   - グローバルセカンダリインデックス (GSI)

3. **IAM**
   - Lambda 実行ロール
   - IAM ポリシー
   - CloudFormation 実行ロール

4. **ストレージ**
   - S3 バケット（SAMアーティファクト用）
   - バケットポリシー
   - ライフサイクルポリシー

5. **モニタリング**
   - CloudWatch Logs グループ
   - CloudWatch Alarms
   - CloudWatch Dashboard

### SAM が管理するリソース

**アプリケーション層**

1. **コンピュート**
   - Lambda 関数
   - Lambda レイヤー
   - 関数のバージョン管理

2. **API**
   - API Gateway
   - REST API エンドポイント
   - ステージ設定

3. **イベントソース**
   - DynamoDB Streams トリガー
   - EventBridge ルール
   - スケジュール実行

4. **エラーハンドリング**
   - Dead Letter Queue (SQS)
   - リトライ設定

## 🔄 データフロー

### 1. API リクエストフロー

```
Client Request
    ↓
API Gateway
    ↓
Lambda (API Function)
    ↓
DynamoDB Table
    ↓
API Gateway Response
    ↓
Client
```

### 2. Stream Processing フロー

```
DynamoDB Table
    ↓
DynamoDB Streams
    ↓
Lambda (Processor Function)
    ↓
[処理: 通知、集計、連携など]
    ↓
CloudWatch Metrics
```

### 3. Scheduled Task フロー

```
EventBridge Rule (Cron)
    ↓
Lambda (Scheduled Function)
    ↓
DynamoDB / 外部API
    ↓
CloudWatch Logs
```

## 🛡️ セキュリティ設計

### ネットワークセキュリティ

1. **VPC 分離**
   - Lambda は Private Subnet に配置
   - インターネットアクセスは NAT Gateway 経由
   - VPCエンドポイントで AWS サービスアクセス

2. **セキュリティグループ**
   - Lambda: アウトバウンドのみ許可
   - VPC内通信は最小限に制限

### アクセス制御

1. **IAM ロール**
   - 最小権限の原則
   - リソースベースポリシー
   - Condition による制限

2. **API 認証**
   - API Key（オプション）
   - IAM 認証
   - Cognito 連携（拡張可能）

### データ保護

1. **暗号化**
   - DynamoDB: Server-side encryption
   - S3: AES-256 暗号化
   - Lambda 環境変数: KMS暗号化（オプション）

2. **バックアップ**
   - DynamoDB: Point-in-Time Recovery
   - S3: バージョニング

## 📊 スケーラビリティ

### 水平スケーリング

- **Lambda**: 自動スケーリング（同時実行数制限設定可能）
- **DynamoDB**: オンデマンド課金 or プロビジョンドキャパシティ
- **API Gateway**: 自動スケーリング

### パフォーマンス最適化

1. **Lambda 最適化**
   - ARM64 (Graviton2) アーキテクチャ
   - 適切なメモリサイズ設定
   - Lambda レイヤーで依存関係を共有

2. **DynamoDB 最適化**
   - GSI による効率的なクエリ
   - BatchGetItem/BatchWriteItem の活用
   - DynamoDB Streams のバッチ処理

3. **API Gateway 最適化**
   - レスポンスキャッシュ（オプション）
   - スロットリング設定

## 🔍 監視とロギング

### メトリクス

1. **Lambda メトリクス**
   - Invocations（実行回数）
   - Errors（エラー数）
   - Duration（実行時間）
   - Throttles（スロットル数）
   - ConcurrentExecutions（同時実行数）

2. **DynamoDB メトリクス**
   - ConsumedReadCapacityUnits
   - ConsumedWriteCapacityUnits
   - UserErrors
   - SystemErrors
   - ThrottledRequests

3. **API Gateway メトリクス**
   - Count（リクエスト数）
   - 4XXError
   - 5XXError
   - Latency

### ログ

- **CloudWatch Logs**: 全Lambda関数のログ
- **API Gateway アクセスログ**: リクエスト詳細
- **X-Ray トレーシング**: 分散トレーシング

### アラート

- Lambda エラー率
- API Gateway 5XX エラー
- DynamoDB スロットリング
- Lambda 実行時間超過

## 💰 コスト最適化

### コスト構造

1. **NAT Gateway**: 最大のコスト要因
   - 単一 NAT Gateway で開発環境のコスト削減
   - VPC Endpoint で NAT Gateway トラフィック削減

2. **Lambda**
   - ARM64 で20%コスト削減
   - 適切なメモリサイズでコスト最適化
   - Lambda Insights は本番環境のみ

3. **DynamoDB**
   - オンデマンド課金で予測困難なワークロードに対応
   - 予測可能なワークロードではプロビジョンドモード

4. **CloudWatch**
   - ログ保持期間を環境別に設定
   - 不要なログは削除

### 月間コスト見積もり（開発環境）

| リソース | 数量 | 単価 | 月額 |
|---------|------|------|------|
| NAT Gateway | 1 | $32.40 | $32.40 |
| Lambda (100万実行) | 1 | $0.20 | $0.20 |
| API Gateway (100万) | 1 | $3.50 | $3.50 |
| DynamoDB (少量) | - | - | $1.00 |
| CloudWatch Logs | - | - | $0.50 |
| **合計** | | | **$37.60** |

## 🚀 デプロイ戦略

### 環境分離

```
Development (dev)
    ↓
Staging (staging)
    ↓
Production (prod)
```

### CI/CD パイプライン

1. **コード検証**
   - Terraform fmt, validate
   - SAM validate
   - Python syntax check

2. **PR レビュー**
   - Terraform plan のコメント
   - コードレビュー

3. **自動デプロイ**
   - develop → dev 環境
   - main → prod 環境

### Blue/Green デプロイ（将来の拡張）

- Lambda エイリアスとバージョン
- API Gateway ステージ
- トラフィックシフト

## 📈 将来の拡張性

### 考慮されている拡張ポイント

1. **マイクロサービス化**
   - 機能ごとにLambda関数を分離
   - イベント駆動アーキテクチャ

2. **データストア追加**
   - RDS（リレーショナルデータ）
   - ElastiCache（キャッシュ）
   - OpenSearch（全文検索）

3. **非同期処理**
   - SQS キュー
   - Step Functions（ワークフロー）

4. **認証・認可**
   - Cognito（ユーザー管理）
   - API Gateway Authorizer

5. **CDN / WAF**
   - CloudFront（コンテンツ配信）
   - AWS WAF（セキュリティ）

## 🔗 参考資料

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Serverless Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [DynamoDB Single Table Design](https://aws.amazon.com/blogs/compute/creating-a-single-table-design-with-amazon-dynamodb/)
