# ========================================
# Production 環境設定
# ========================================

environment = "prod"
aws_region  = "ap-northeast-1"

# ========================================
# VPC設定
# ========================================

vpc_cidr             = "10.2.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24"]

# NAT Gateway設定（本番環境では高可用性のため各AZに配置）
enable_nat_gateway = true
single_nat_gateway = false # 本番環境では false 推奨（高可用性）

# ========================================
# DynamoDB設定
# ========================================

# 本番環境：トラフィックが予測可能ならPROVISIONED、不規則ならPAY_PER_REQUEST
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Streams有効化
enable_dynamodb_streams     = true
dynamodb_stream_view_type   = "NEW_AND_OLD_IMAGES"

# Point-in-Time Recovery（本番環境では必須）
enable_dynamodb_point_in_time_recovery = true

# ========================================
# CloudWatch設定
# ========================================

# ログ保持期間（本番環境では長期保持）
log_retention_days = 90

# Lambda Insights（本番環境では有効化推奨）
enable_lambda_insights = true

# ========================================
# S3設定
# ========================================

# バージョニング（本番環境では必須）
enable_s3_versioning = true

# ライフサイクル（本番環境では長めに）
s3_lifecycle_days = 180

# ========================================
# セキュリティ設定
# ========================================

# WAF（本番環境では有効化推奨）
enable_waf = true

# ========================================
# タグ
# ========================================

common_tags = {
  Environment       = "prod"
  ManagedBy         = "Terraform"
  Project           = "TerraformSAMDemo"
  CostCenter        = "Production"
  Owner             = "Platform Team"
  DataClassification = "Confidential"
  Compliance        = "Required"
  BackupPolicy      = "Daily"
}
