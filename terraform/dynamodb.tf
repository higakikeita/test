# ========================================
# DynamoDBテーブル
# ========================================

resource "aws_dynamodb_table" "main" {
  name = local.dynamodb_table_name

  # 課金モード
  billing_mode = var.dynamodb_billing_mode

  # パーティションキー
  hash_key = "PK"

  # ソートキー
  range_key = "SK"

  # PROVISIONED モードの場合のキャパシティ設定
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null

  # ========================================
  # 属性定義
  # ========================================

  attribute {
    name = "PK"
    type = "S" # String
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # GSI用の属性
  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  attribute {
    name = "EntityType"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "N" # Number (UNIX timestamp)
  }

  # ========================================
  # グローバルセカンダリインデックス (GSI)
  # ========================================

  # GSI1: 反転インデックス（リレーションシップのクエリ用）
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"

    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # GSI2: エンティティタイプ別クエリ用
  global_secondary_index {
    name            = "EntityTypeIndex"
    hash_key        = "EntityType"
    range_key       = "CreatedAt"
    projection_type = "ALL"

    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # ========================================
  # TTL設定（有効期限管理）
  # ========================================

  ttl {
    enabled        = true
    attribute_name = "ExpiresAt"
  }

  # ========================================
  # DynamoDB Streams
  # ========================================

  stream_enabled   = var.enable_dynamodb_streams
  stream_view_type = var.enable_dynamodb_streams ? var.dynamodb_stream_view_type : null

  # ========================================
  # Point-in-Time Recovery
  # ========================================

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  # ========================================
  # サーバーサイド暗号化
  # ========================================

  server_side_encryption {
    enabled = true
    # KMSを使用する場合
    # kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # ========================================
  # テーブルクラス（コスト最適化）
  # ========================================

  # Standard: 頻繁にアクセスされるデータ用
  # Standard_IA: 不定期にアクセスされるデータ用（コスト削減）
  table_class = var.environment == "prod" ? "STANDARD" : "STANDARD"

  tags = {
    Name = local.dynamodb_table_name
  }

  # ========================================
  # ライフサイクル設定
  # ========================================

  lifecycle {
    # 本番環境では誤削除防止
    prevent_destroy = false # 本番環境では true に設定推奨

    # 属性の追加/削除は ignore_changes で無視（アプリケーション側で管理）
    ignore_changes = [
      # read_capacity,
      # write_capacity
    ]
  }
}

# ========================================
# オートスケーリング（PROVISIONEDモード時）
# ========================================

# 読み込みキャパシティのオートスケーリング
resource "aws_appautoscaling_target" "dynamodb_table_read" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  max_capacity       = 100
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.main.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  name               = "${local.dynamodb_table_name}-read-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

# 書き込みキャパシティのオートスケーリング
resource "aws_appautoscaling_target" "dynamodb_table_write" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  max_capacity       = 100
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.main.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  name               = "${local.dynamodb_table_name}-write-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}

# ========================================
# DynamoDBテーブルの使用例（コメント）
# ========================================

# シングルテーブルデザインの例:
#
# ユーザーエンティティ:
#   PK: USER#<user_id>
#   SK: METADATA
#   EntityType: User
#   Name: "John Doe"
#   Email: "john@example.com"
#   CreatedAt: 1234567890
#
# ユーザーの注文:
#   PK: USER#<user_id>
#   SK: ORDER#<order_id>
#   EntityType: Order
#   GSI1PK: ORDER#<order_id>
#   GSI1SK: USER#<user_id>
#   Amount: 1000
#   CreatedAt: 1234567890
#
# クエリ例:
#   - 特定ユーザーの全注文: PK = "USER#123" AND SK begins_with "ORDER#"
#   - 特定注文の詳細: GSI1PK = "ORDER#456"
#   - 最近の全注文: EntityType = "Order" AND CreatedAt > timestamp
