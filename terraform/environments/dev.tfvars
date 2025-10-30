# ========================================
# Development 環境設定
# ========================================

environment = "dev"
aws_region  = "ap-northeast-1"

# ========================================
# VPC設定
# ========================================

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# NAT Gateway設定（コスト削減のため単一構成）
enable_nat_gateway = true
single_nat_gateway = true

# ========================================
# DynamoDB設定
# ========================================

# 開発環境ではオンデマンド課金を使用
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Streams有効化（Processor Lambdaのテスト用）
enable_dynamodb_streams     = true
dynamodb_stream_view_type   = "NEW_AND_OLD_IMAGES"

# Point-in-Time Recovery（開発環境では無効）
enable_dynamodb_point_in_time_recovery = false

# ========================================
# CloudWatch設定
# ========================================

# ログ保持期間（開発環境では短めに）
log_retention_days = 7

# Lambda Insights（開発環境では無効、コスト削減）
enable_lambda_insights = false

# ========================================
# S3設定
# ========================================

# バージョニング（開発環境では無効）
enable_s3_versioning = false

# ライフサイクル（開発環境では短め）
s3_lifecycle_days = 30

# ========================================
# セキュリティ設定
# ========================================

# WAF（開発環境では無効）
enable_waf = false

# ========================================
# タグ
# ========================================

common_tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Project     = "TerraformSAMDemo"
  CostCenter  = "Development"
  Owner       = "DevTeam"
}
