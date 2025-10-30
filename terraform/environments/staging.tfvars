# ========================================
# Staging 環境設定
# ========================================

environment = "staging"
aws_region  = "ap-northeast-1"

# ========================================
# VPC設定
# ========================================

vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

# NAT Gateway設定（staging では単一構成でコスト削減）
enable_nat_gateway = true
single_nat_gateway = true

# ========================================
# DynamoDB設定
# ========================================

# Stagingではオンデマンド課金を使用
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Streams有効化
enable_dynamodb_streams     = true
dynamodb_stream_view_type   = "NEW_AND_OLD_IMAGES"

# Point-in-Time Recovery（staging では有効化検討）
enable_dynamodb_point_in_time_recovery = false

# ========================================
# CloudWatch設定
# ========================================

# ログ保持期間（staging では中程度）
log_retention_days = 30

# Lambda Insights（staging では有効化してテスト）
enable_lambda_insights = true

# ========================================
# S3設定
# ========================================

# バージョニング（staging では有効化推奨）
enable_s3_versioning = true

# ライフサイクル
s3_lifecycle_days = 60

# ========================================
# セキュリティ設定
# ========================================

# WAF（staging では有効化してテスト）
enable_waf = false

# ========================================
# タグ
# ========================================

common_tags = {
  Environment = "staging"
  ManagedBy   = "Terraform"
  Project     = "TerraformSAMDemo"
  CostCenter  = "Engineering"
  Owner       = "DevOpsTeam"
}
