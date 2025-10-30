# ========================================
# 変数定義
# ========================================

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスとして使用）"
  type        = string
  default     = "terraform-sam-demo"
}

variable "environment" {
  description = "環境名（dev, staging, prod）"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev, staging, prod のいずれかである必要があります。"
  }
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

# ========================================
# VPC設定
# ========================================

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロック"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロック"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "NAT Gatewayを有効化するか（VPC Lambda の外部通信に必要）"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "単一のNAT Gatewayを使用するか（コスト削減）"
  type        = bool
  default     = true # dev/staging では true、prod では false 推奨
}

# ========================================
# DynamoDB設定
# ========================================

variable "dynamodb_billing_mode" {
  description = "DynamoDBの課金モード（PROVISIONED or PAY_PER_REQUEST）"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "billing_mode は PROVISIONED または PAY_PER_REQUEST である必要があります。"
  }
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB読み込みキャパシティユニット（PROVISIONEDモード時）"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB書き込みキャパシティユニット（PROVISIONEDモード時）"
  type        = number
  default     = 5
}

variable "enable_dynamodb_streams" {
  description = "DynamoDB Streamsを有効化するか"
  type        = bool
  default     = true
}

variable "dynamodb_stream_view_type" {
  description = "DynamoDB Streamsのビュータイプ"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  validation {
    condition = contains([
      "KEYS_ONLY",
      "NEW_IMAGE",
      "OLD_IMAGE",
      "NEW_AND_OLD_IMAGES"
    ], var.dynamodb_stream_view_type)
    error_message = "無効なstream_view_typeです。"
  }
}

variable "enable_dynamodb_point_in_time_recovery" {
  description = "DynamoDB Point-in-Time Recoveryを有効化するか"
  type        = bool
  default     = false # 本番環境では true 推奨
}

# ========================================
# CloudWatch設定
# ========================================

variable "log_retention_days" {
  description = "CloudWatch Logsの保持日数"
  type        = number
  default     = 7 # dev: 7, staging: 30, prod: 90 推奨
}

variable "enable_lambda_insights" {
  description = "Lambda Insightsを有効化するか"
  type        = bool
  default     = false # 本番環境では true 推奨
}

# ========================================
# タグ設定
# ========================================

variable "common_tags" {
  description = "全リソースに適用する共通タグ"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "TerraformSAMDemo"
  }
}

# ========================================
# S3設定
# ========================================

variable "enable_s3_versioning" {
  description = "S3バケットのバージョニングを有効化するか"
  type        = bool
  default     = false # 本番環境では true 推奨
}

variable "s3_lifecycle_days" {
  description = "S3オブジェクトのライフサイクル日数"
  type        = number
  default     = 90
}

# ========================================
# セキュリティ設定
# ========================================

variable "allowed_cidr_blocks" {
  description = "許可するCIDRブロック（VPC内通信用）"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enable_waf" {
  description = "WAFを有効化するか（API Gateway保護）"
  type        = bool
  default     = false # 本番環境では true 推奨
}
