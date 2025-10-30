# トラブルシューティングガイド

このドキュメントでは、よくある問題とその解決方法をまとめています。

## 📋 目次

- [Terraform関連](#terraform関連)
- [SAM関連](#sam関連)
- [Lambda関連](#lambda関連)
- [DynamoDB関連](#dynamodb関連)
- [VPC関連](#vpc関連)
- [デプロイ関連](#デプロイ関連)

## Terraform関連

### エラー: `Error: state lock`

**症状:**
```
Error: Error acquiring the state lock
Error message: ConditionalCheckFailedException
Lock Info:
  ID: xxxxx-xxxxx-xxxxx
```

**原因:**
Terraform の前回実行が異常終了し、State ロックが解除されていない

**解決方法:**
```bash
# ロックIDを確認してロックを強制解除
terraform force-unlock <LOCK_ID>

# または、DynamoDB コンソールから手動で削除
```

**予防策:**
- `terraform apply` を Ctrl+C で中断しない
- CI/CD パイプラインのタイムアウト設定を適切に

---

### エラー: `Error: creating S3 bucket: BucketAlreadyExists`

**症状:**
```
Error: Error creating S3 Bucket: BucketAlreadyExists:
The requested bucket name is not available
```

**原因:**
S3 バケット名がグローバルで一意である必要があるが、既に使用されている

**解決方法:**
```bash
# terraform/main.tf の sam_artifacts_bucket_name を変更
# アカウントIDを含めることで一意性を保証
```

**推奨:**
プロジェクトではアカウントIDを自動的に含めるようになっています

---

### エラー: `Error: Invalid count argument`

**症状:**
```
Error: Invalid count argument
The "count" value depends on resource attributes that cannot be determined until apply
```

**原因:**
count に動的な値を使用している

**解決方法:**
```bash
# 一度適用を2段階に分ける
terraform apply -target=aws_dynamodb_table.main
terraform apply
```

---

## SAM関連

### エラー: `Error: Unable to upload artifact`

**症状:**
```
Error: Unable to upload artifact functions/api/
An error occurred (AccessDenied) when calling the PutObject operation
```

**原因:**
S3 バケットへのアップロード権限がない

**解決方法:**
```bash
# AWS認証情報を確認
aws sts get-caller-identity

# S3バケットの存在を確認
aws s3 ls | grep sam-artifacts

# バケットポリシーを確認
aws s3api get-bucket-policy --bucket <bucket-name>

# Terraformで作成したバケット名を使用しているか確認
cat sam/terraform-outputs.json | jq -r '.sam_artifacts_bucket.value'
```

---

### エラー: `Error: template.yaml is invalid`

**症状:**
```
Error: template.yaml is not a valid SAM template
```

**原因:**
SAM テンプレートの構文エラー

**解決方法:**
```bash
# SAM validate で詳細を確認
sam validate --lint

# YAML構文チェック
yamllint sam/template.yaml

# インデントを確認（YAMLは厳密）
```

**よくある間違い:**
- インデントミス（スペース vs タブ）
- 必須プロパティの欠落
- パラメータの型ミス

---

### エラー: `Build Failed`

**症状:**
```
Build Failed
Error: PythonPipBuilder:ResolveDependencies - {requirements.txt not found}
```

**原因:**
requirements.txt が存在しないか、パスが間違っている

**解決方法:**
```bash
# 各Lambda関数ディレクトリにrequirements.txtが存在するか確認
ls -la sam/functions/api/requirements.txt
ls -la sam/functions/processor/requirements.txt

# 空のrequirements.txtでも良い（boto3は含まれている）
echo "boto3>=1.28.0" > sam/functions/api/requirements.txt
```

---

## Lambda関連

### エラー: `Task timed out after 30.00 seconds`

**症状:**
Lambda関数がタイムアウトする

**原因:**
- 関数の実行時間が設定されたタイムアウトを超えている
- VPC Lambdaでインターネット接続ができない（NAT Gateway未設定）
- DynamoDBへのクエリが遅い

**解決方法:**

1. **タイムアウト設定を増やす**
```yaml
# sam/template.yaml
Globals:
  Function:
    Timeout: 60  # 30 → 60に変更
```

2. **VPC設定を確認**
```bash
# NAT Gatewayが存在するか確認
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"

# プライベートサブネットのルートテーブルを確認
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"
```

3. **CloudWatch Logsで詳細を確認**
```bash
# 最新のログを確認
aws logs tail /aws/lambda/<function-name> --follow
```

---

### エラー: `Unable to import module 'index'`

**症状:**
```
{
  "errorMessage": "Unable to import module 'index': No module named 'index'",
  "errorType": "Runtime.ImportModuleError"
}
```

**原因:**
- ハンドラーのパスが間違っている
- 必要なファイルがパッケージに含まれていない

**解決方法:**

1. **ハンドラー設定を確認**
```yaml
# sam/template.yaml
Handler: index.lambda_handler  # ファイル名.関数名
CodeUri: functions/api/        # ディレクトリパス
```

2. **ファイル構成を確認**
```bash
# .aws-sam/build/ を確認
ls -la .aws-sam/build/ApiFunction/
```

3. **再ビルド**
```bash
sam build --use-container
```

---

### エラー: `AccessDeniedException`

**症状:**
```
botocore.exceptions.ClientError: An error occurred (AccessDeniedException)
when calling the PutItem operation: User is not authorized
```

**原因:**
Lambda実行ロールに必要な権限がない

**解決方法:**

1. **IAMロールを確認**
```bash
# TerraformのIAMポリシーを確認
cat terraform/iam.tf

# 実際のポリシーを確認
aws iam get-role-policy --role-name <role-name> --policy-name <policy-name>
```

2. **最小限の権限を追加**
```hcl
# terraform/iam.tf
statement {
  effect = "Allow"
  actions = [
    "dynamodb:PutItem",
    "dynamodb:GetItem"
  ]
  resources = [
    aws_dynamodb_table.main.arn
  ]
}
```

3. **Terraformを再適用**
```bash
cd terraform
terraform apply -var-file=environments/dev.tfvars
```

---

## DynamoDB関連

### エラー: `ProvisionedThroughputExceededException`

**症状:**
```
botocore.exceptions.ClientError: An error occurred (ProvisionedThroughputExceededException)
```

**原因:**
プロビジョンドキャパシティを超えたリクエスト

**解決方法:**

1. **オンデマンド課金モードに切り替え**
```hcl
# terraform/environments/dev.tfvars
dynamodb_billing_mode = "PAY_PER_REQUEST"
```

2. **オートスケーリングの設定（PROVISIONEDモード時）**
```hcl
# terraform/dynamodb.tf で既に実装済み
resource "aws_appautoscaling_target" "dynamodb_table_read" {
  max_capacity = 100
  min_capacity = 5
  # ...
}
```

3. **バッチ操作を使用**
```python
# BatchWriteItem を使用
table.batch_writer() as batch:
    for item in items:
        batch.put_item(Item=item)
```

---

### エラー: `ValidationException: Invalid KeyConditionExpression`

**症状:**
```
botocore.exceptions.ClientError: An error occurred (ValidationException)
Query key condition not supported
```

**原因:**
- パーティションキーのみでソートキーを使用していない
- GSIの使用方法が間違っている

**解決方法:**

1. **正しいキー条件式を使用**
```python
# パーティションキーのみ
response = table.query(
    KeyConditionExpression=Key('PK').eq('ITEM#123')
)

# パーティションキー + ソートキー
response = table.query(
    KeyConditionExpression=Key('PK').eq('USER#123') & Key('SK').begins_with('ORDER#')
)
```

2. **GSIを使用**
```python
# GSI を使用した検索
response = table.query(
    IndexName='EntityTypeIndex',
    KeyConditionExpression=Key('EntityType').eq('Item')
)
```

---

## VPC関連

### 問題: Lambda が外部APIにアクセスできない

**症状:**
Lambda関数から外部API（例: https://api.example.com）への接続がタイムアウトする

**原因:**
- NAT Gatewayが設定されていない
- ルートテーブルの設定ミス
- セキュリティグループのアウトバウンドルールが制限されている

**解決方法:**

1. **NAT Gatewayの確認**
```bash
# NAT Gatewayが存在し、stateがavailableか確認
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<vpc-id>" \
  --query 'NatGateways[*].[NatGatewayId,State]'
```

2. **ルートテーブルの確認**
```bash
# プライベートサブネットのルートテーブルを確認
# 0.0.0.0/0 → NAT Gateway のルートが存在するか
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<private-subnet-id>"
```

3. **セキュリティグループの確認**
```bash
# Lambdaのセキュリティグループでアウトバウンドが許可されているか
aws ec2 describe-security-groups --group-ids <security-group-id>
```

4. **VPCエンドポイントの利用検討**
```hcl
# S3, DynamoDB以外にもVPCエンドポイントを追加
# 例: Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}
```

---

### 問題: VPC Lambda のコールドスタートが遅い

**症状:**
Lambda関数の初回実行に10秒以上かかる

**原因:**
VPC Lambda は ENI (Elastic Network Interface) の作成に時間がかかる

**解決方法:**

1. **プロビジョンド同時実行数の設定**
```yaml
# sam/template.yaml
ApiFunction:
  Type: AWS::Serverless::Function
  Properties:
    ProvisionedConcurrencyConfig:
      ProvisionedConcurrentExecutions: 1
```

2. **VPCの必要性を再検討**
- 外部APIのみにアクセスする場合、VPCは不要
- DynamoDBやS3は VPCエンドポイントで高速化

3. **Hyperplane ENI の活用**
- 現在のAWS LambdaはHyperplane ENIを使用し、従来より高速化されています

---

## デプロイ関連

### エラー: `CloudFormation stack is in ROLLBACK_COMPLETE state`

**症状:**
```
Error: Stack is in ROLLBACK_COMPLETE state and can not be updated
```

**原因:**
前回のデプロイが失敗し、スタックがロールバック完了状態になっている

**解決方法:**

1. **失敗の原因を確認**
```bash
# CloudFormation イベントを確認
aws cloudformation describe-stack-events \
  --stack-name terraform-sam-demo-dev-app \
  --max-items 20
```

2. **スタックを削除して再作成**
```bash
# スタックを削除
aws cloudformation delete-stack \
  --stack-name terraform-sam-demo-dev-app

# 削除完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name terraform-sam-demo-dev-app

# 再デプロイ
cd sam
sam deploy
```

**よくある失敗原因:**
- IAM ロールの権限不足
- リソース名の重複
- パラメータの型ミス

---

### エラー: GitHub Actions デプロイ失敗

**症状:**
GitHub Actions ワークフローでデプロイが失敗する

**原因:**
- AWS認証情報が設定されていない
- 権限不足

**解決方法:**

1. **GitHub Secrets の設定**
```bash
# GitHubリポジトリの Settings → Secrets and variables → Actions
# 以下を設定:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

2. **IAMユーザーの権限確認**
```bash
# 必要な権限:
# - CloudFormation Full Access
# - Lambda Full Access
# - IAM Role PassRole
# - S3 Read/Write
# - API Gateway Full Access
```

3. **ローカルで動作確認**
```bash
# ローカルで同じコマンドを実行
./scripts/deploy.sh dev
```

---

### 問題: デプロイに時間がかかりすぎる

**症状:**
SAM デプロイに10分以上かかる

**原因:**
- VPC Lambda の ENI 作成
- CloudFormation のスタック更新
- 依存関係のインストール

**解決方法:**

1. **変更がない場合はスキップ**
```bash
# --no-fail-on-empty-changeset オプション（既に使用中）
sam deploy --no-fail-on-empty-changeset
```

2. **Docker ビルドの高速化**
```bash
# ビルドキャッシュの利用
sam build --cached --parallel
```

3. **Terraform と SAM を分離してデプロイ**
```bash
# Terraform のみ更新
./scripts/deploy.sh dev --tf-only

# SAM のみ更新
./scripts/deploy.sh dev --sam-only
```

---

## 一般的なデバッグ手法

### CloudWatch Logs でログを確認

```bash
# リアルタイムでログを確認
aws logs tail /aws/lambda/terraform-sam-demo-dev-api --follow

# エラーログのみフィルタ
aws logs tail /aws/lambda/terraform-sam-demo-dev-api \
  --filter-pattern "ERROR" \
  --follow
```

### X-Ray トレースの確認

```bash
# X-Ray コンソールで確認
# https://console.aws.amazon.com/xray/home

# または AWS CLI で確認
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

### Lambda 関数のテスト

```bash
# ローカルでテスト
cd sam
sam local invoke ApiFunction -e events/event.json

# AWS上でテスト
aws lambda invoke \
  --function-name terraform-sam-demo-dev-api \
  --payload '{"httpMethod":"GET","path":"/health"}' \
  response.json
```

### DynamoDB テーブルの確認

```bash
# テーブルの内容をスキャン
aws dynamodb scan \
  --table-name terraform-sam-demo-dev-data \
  --max-items 10

# 特定のアイテムを取得
aws dynamodb get-item \
  --table-name terraform-sam-demo-dev-data \
  --key '{"PK":{"S":"ITEM#123"},"SK":{"S":"METADATA"}}'
```

---

## サポートリソース

### 公式ドキュメント

- [AWS Lambda トラブルシューティング](https://docs.aws.amazon.com/lambda/latest/dg/lambda-troubleshooting.html)
- [SAM CLI トラブルシューティング](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/troubleshooting.html)
- [Terraform AWS Provider トラブルシューティング](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### コミュニティ

- [AWS re:Post](https://repost.aws/)
- [Stack Overflow - AWS Lambda](https://stackoverflow.com/questions/tagged/aws-lambda)
- [Terraform Community Forum](https://discuss.hashicorp.com/c/terraform-core)

---

## 問題が解決しない場合

1. **CloudWatch Logs を確認** - 詳細なエラーメッセージが記録されています
2. **AWS Personal Health Dashboard** - AWSサービスの障害情報
3. **GitHub Issues** - 本プロジェクトの既知の問題
4. **AWS サポート** - ビジネスサポート以上の契約がある場合

問題が解決した場合は、このドキュメントへの追加をご検討ください！
