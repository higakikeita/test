# ========================================
# S3バケット - SAMアーティファクト保存用
# ========================================

resource "aws_s3_bucket" "sam_artifacts" {
  bucket = local.sam_artifacts_bucket_name

  tags = {
    Name    = local.sam_artifacts_bucket_name
    Purpose = "SAM deployment artifacts"
  }

  # バケット削除時に強制削除（開発環境用）
  # 本番環境では force_destroy = false を推奨
  force_destroy = var.environment == "prod" ? false : true
}

# ========================================
# S3バケット - パブリックアクセスブロック
# ========================================

resource "aws_s3_bucket_public_access_block" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================
# S3バケット - バージョニング
# ========================================

resource "aws_s3_bucket_versioning" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}

# ========================================
# S3バケット - 暗号化
# ========================================

resource "aws_s3_bucket_server_side_encryption_configuration" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
      # KMSを使用する場合は以下のようにする
      # sse_algorithm     = "aws:kms"
      # kms_master_key_id = aws_kms_key.sam_artifacts.arn
    }
    bucket_key_enabled = true
  }
}

# ========================================
# S3バケット - ライフサイクルポリシー
# ========================================

resource "aws_s3_bucket_lifecycle_configuration" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id

  # 古いバージョンのクリーンアップ
  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # 古いアーティファクトの削除
  rule {
    id     = "cleanup-old-artifacts"
    status = "Enabled"

    filter {
      prefix = "artifacts/"
    }

    expiration {
      days = var.s3_lifecycle_days
    }
  }

  # 一時ファイルの削除
  rule {
    id     = "cleanup-temp-files"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 7
    }
  }
}

# ========================================
# S3バケットポリシー
# ========================================

resource "aws_s3_bucket_policy" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id
  policy = data.aws_iam_policy_document.sam_artifacts_bucket_policy.json
}

data "aws_iam_policy_document" "sam_artifacts_bucket_policy" {
  # CloudFormation実行ロールからの読み取りを許可
  statement {
    sid    = "AllowCloudFormationRead"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cloudformation_execution.arn]
    }

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]

    resources = [
      "${aws_s3_bucket.sam_artifacts.arn}/*"
    ]
  }

  # SAMデプロイからの書き込みを許可（必要に応じて制限を追加）
  statement {
    sid    = "AllowSAMDeploy"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.sam_artifacts.arn}/*"
    ]

    # オプション: 特定のIAMユーザー/ロールからのみ許可
    # condition {
    #   test     = "StringEquals"
    #   variable = "aws:PrincipalArn"
    #   values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/deploy-user"]
    # }
  }

  # SSL/TLS通信の強制
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.sam_artifacts.arn,
      "${aws_s3_bucket.sam_artifacts.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ========================================
# S3バケット - ロギング（オプション）
# ========================================

# アクセスログ保存用バケット（本番環境では有効化推奨）
# resource "aws_s3_bucket" "sam_artifacts_logs" {
#   count  = var.environment == "prod" ? 1 : 0
#   bucket = "${local.sam_artifacts_bucket_name}-logs"
#
#   tags = {
#     Name    = "${local.sam_artifacts_bucket_name}-logs"
#     Purpose = "Access logs for SAM artifacts bucket"
#   }
# }
#
# resource "aws_s3_bucket_logging" "sam_artifacts" {
#   count  = var.environment == "prod" ? 1 : 0
#   bucket = aws_s3_bucket.sam_artifacts.id
#
#   target_bucket = aws_s3_bucket.sam_artifacts_logs[0].id
#   target_prefix = "access-logs/"
# }

# ========================================
# KMSキー（高度なセキュリティが必要な場合）
# ========================================

# resource "aws_kms_key" "sam_artifacts" {
#   description             = "KMS key for SAM artifacts encryption"
#   deletion_window_in_days = 10
#   enable_key_rotation     = true
#
#   tags = {
#     Name = "${local.resource_prefix}-sam-artifacts-key"
#   }
# }
#
# resource "aws_kms_alias" "sam_artifacts" {
#   name          = "alias/${local.resource_prefix}-sam-artifacts"
#   target_key_id = aws_kms_key.sam_artifacts.key_id
# }
