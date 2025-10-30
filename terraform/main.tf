# ========================================
# プロバイダー設定
# ========================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Environment = var.environment
      }
    )
  }
}

# ========================================
# ローカル変数
# ========================================

locals {
  # リソース名のプレフィックス
  resource_prefix = "${var.project_name}-${var.environment}"

  # DynamoDBテーブル名
  dynamodb_table_name = "${local.resource_prefix}-data"

  # S3バケット名（グローバルでユニークである必要がある）
  sam_artifacts_bucket_name = "${local.resource_prefix}-sam-artifacts-${data.aws_caller_identity.current.account_id}"

  # Lambda関数名のプレフィックス
  lambda_function_prefix = local.resource_prefix

  # CloudWatch Logs グループ名のプレフィックス
  log_group_prefix = "/aws/lambda/${local.lambda_function_prefix}"
}

# ========================================
# データソース
# ========================================

# 現在のAWSアカウントIDを取得
data "aws_caller_identity" "current" {}

# 現在のリージョンを取得
data "aws_region" "current" {}

# ========================================
# モジュール呼び出し（必要に応じて）
# ========================================

# 今回は単一ファイルではなく、各リソースを別ファイルに分割しています
# vpc.tf, iam.tf, s3.tf, dynamodb.tf, cloudwatch.tf を参照してください
