# ========================================
# Terraform Backend 設定
# ========================================

# Terraform State の保存先を設定
# チーム開発では S3 + DynamoDB によるリモートバックエンドを推奨

# ========================================
# ローカルバックエンド（開発・検証用）
# ========================================

# デフォルトではローカルにstateファイルを保存
# terraform init を実行すると、カレントディレクトリに terraform.tfstate が作成される

# ========================================
# S3バックエンド（チーム開発・本番用）
# ========================================

# 以下のコメントを解除してS3バックエンドを使用
# 使用前に以下を実施:
# 1. S3バケットを作成（別途作成が必要）
# 2. DynamoDBテーブルを作成（Stateロック用、別途作成が必要）
# 3. backend.tfを編集
# 4. terraform init -reconfigure を実行

# terraform {
#   backend "s3" {
#     # S3バケット名（事前に作成が必要）
#     bucket = "your-terraform-state-bucket"
#
#     # Stateファイルのパス
#     # 環境ごとに異なるパスを使用することを推奨
#     key = "terraform-sam-demo/dev/terraform.tfstate"
#
#     # リージョン
#     region = "ap-northeast-1"
#
#     # State ロック用 DynamoDB テーブル（事前に作成が必要）
#     # テーブルのパーティションキー: LockID (String型)
#     dynamodb_table = "terraform-state-locks"
#
#     # 暗号化を有効化
#     encrypt = true
#
#     # KMSキーを使用する場合（オプション）
#     # kms_key_id = "arn:aws:kms:ap-northeast-1:123456789012:key/12345678-1234-1234-1234-123456789012"
#   }
# }

# ========================================
# S3バックエンド用リソースの作成例
# ========================================

# 注意: このリソースは別のTerraformプロジェクトで作成することを推奨
# （鶏と卵の問題を避けるため）

# S3バケット（State保存用）
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "your-terraform-state-bucket"
#
#   tags = {
#     Name        = "Terraform State Bucket"
#     Description = "Stores Terraform state files"
#   }
# }
#
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
#
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
#
# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# DynamoDBテーブル（State Lock用）
# resource "aws_dynamodb_table" "terraform_locks" {
#   name         = "terraform-state-locks"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#
#   tags = {
#     Name        = "Terraform State Lock Table"
#     Description = "Locks Terraform state files"
#   }
# }

# ========================================
# Terraform Cloud バックエンド（オプション）
# ========================================

# Terraform Cloud を使用する場合
# https://app.terraform.io/ でワークスペースを作成後、以下を設定

# terraform {
#   cloud {
#     organization = "your-organization-name"
#
#     workspaces {
#       name = "terraform-sam-demo-dev"
#     }
#   }
# }

# ========================================
# State管理のベストプラクティス
# ========================================

# 1. 環境ごとに別のStateファイルを使用
#    - dev:     key = "terraform-sam-demo/dev/terraform.tfstate"
#    - staging: key = "terraform-sam-demo/staging/terraform.tfstate"
#    - prod:    key = "terraform-sam-demo/prod/terraform.tfstate"

# 2. State ファイルの暗号化を有効化
#    - encrypt = true

# 3. State ロックを有効化（DynamoDB使用）
#    - 同時実行の防止

# 4. State ファイルのバージョニングを有効化
#    - S3バケットのバージョニングを有効化

# 5. State ファイルのバックアップ
#    - S3のライフサイクルポリシーで古いバージョンを保持

# 6. アクセス制御
#    - State ファイルには機密情報が含まれる可能性があるため
#    - IAMポリシーで適切なアクセス制御を実施

# ========================================
# State の移行（ローカル → S3）
# ========================================

# ローカルからS3バックエンドへの移行手順:
#
# 1. S3バケットとDynamoDBテーブルを作成
# 2. backend.tf を編集（S3設定のコメント解除）
# 3. 移行を実行:
#    terraform init -reconfigure
# 4. Stateファイルがアップロードされたことを確認:
#    aws s3 ls s3://your-terraform-state-bucket/terraform-sam-demo/dev/

# ========================================
# Workspace の使用（環境分離の別の方法）
# ========================================

# Terraform Workspace を使用して環境を分離することも可能
# ただし、完全に独立したStateファイルを使用する方が推奨される

# Workspaceの作成と切り替え:
# terraform workspace new dev
# terraform workspace new staging
# terraform workspace new prod
# terraform workspace select dev
# terraform workspace list
