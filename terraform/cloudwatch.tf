# ========================================
# CloudWatch Logs - Lambda用ロググループ
# ========================================

# APIFunction用ロググループ
resource "aws_cloudwatch_log_group" "lambda_api" {
  name              = "${local.log_group_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name     = "${local.resource_prefix}-lambda-api-logs"
    Function = "api"
  }
}

# ProcessorFunction用ロググループ
resource "aws_cloudwatch_log_group" "lambda_processor" {
  name              = "${local.log_group_prefix}-processor"
  retention_in_days = var.log_retention_days

  tags = {
    Name     = "${local.resource_prefix}-lambda-processor-logs"
    Function = "processor"
  }
}

# ========================================
# CloudWatch Alarms - Lambda
# ========================================

# Lambda エラーアラーム（API Function）
resource "aws_cloudwatch_metric_alarm" "lambda_api_errors" {
  alarm_name          = "${local.resource_prefix}-lambda-api-errors"
  alarm_description   = "Alert when Lambda API function has errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300 # 5分
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.lambda_function_prefix}-api"
  }

  # アラーム通知先（SNSトピック）
  # alarm_actions = [aws_sns_topic.alerts[0].arn]

  tags = {
    Name = "${local.resource_prefix}-lambda-api-errors-alarm"
  }
}

# Lambda スロットルアラーム（API Function）
resource "aws_cloudwatch_metric_alarm" "lambda_api_throttles" {
  alarm_name          = "${local.resource_prefix}-lambda-api-throttles"
  alarm_description   = "Alert when Lambda API function is throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.lambda_function_prefix}-api"
  }

  tags = {
    Name = "${local.resource_prefix}-lambda-api-throttles-alarm"
  }
}

# Lambda 実行時間アラーム（API Function）
resource "aws_cloudwatch_metric_alarm" "lambda_api_duration" {
  alarm_name          = "${local.resource_prefix}-lambda-api-duration"
  alarm_description   = "Alert when Lambda API function duration is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 5000 # 5秒
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.lambda_function_prefix}-api"
  }

  tags = {
    Name = "${local.resource_prefix}-lambda-api-duration-alarm"
  }
}

# ========================================
# CloudWatch Alarms - DynamoDB
# ========================================

# DynamoDB 読み取りスロットルアラーム
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  alarm_name          = "${local.resource_prefix}-dynamodb-read-throttles"
  alarm_description   = "Alert when DynamoDB table has read throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.main.name
  }

  tags = {
    Name = "${local.resource_prefix}-dynamodb-read-throttles-alarm"
  }
}

# DynamoDB 書き込みスロットルアラーム
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttles" {
  alarm_name          = "${local.resource_prefix}-dynamodb-write-throttles"
  alarm_description   = "Alert when DynamoDB table has write throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.main.name
  }

  tags = {
    Name = "${local.resource_prefix}-dynamodb-write-throttles-alarm"
  }
}

# DynamoDB システムエラーアラーム
resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  alarm_name          = "${local.resource_prefix}-dynamodb-system-errors"
  alarm_description   = "Alert when DynamoDB table has system errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.main.name
  }

  tags = {
    Name = "${local.resource_prefix}-dynamodb-system-errors-alarm"
  }
}

# ========================================
# CloudWatch Alarms - API Gateway（SAMで作成されるAPI用）
# ========================================

# API Gateway 5XXエラーアラーム
# 注: API Gateway は SAM で作成されるため、API IDは動的
# この例では Terraform で作成できないため、コメントアウト
# 実際には SAM template.yaml 内で定義するか、デプロイ後に手動で作成

# resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
#   alarm_name          = "${local.resource_prefix}-api-5xx-errors"
#   alarm_description   = "Alert when API Gateway has 5XX errors"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "5XXError"
#   namespace           = "AWS/ApiGateway"
#   period              = 300
#   statistic           = "Sum"
#   threshold           = 10
#   treat_missing_data  = "notBreaching"
#
#   dimensions = {
#     ApiName = "${local.resource_prefix}-api"
#   }
# }

# ========================================
# SNS トピック - アラート通知用（オプション）
# ========================================

# resource "aws_sns_topic" "alerts" {
#   count = var.environment == "prod" ? 1 : 0
#   name  = "${local.resource_prefix}-alerts"
#
#   tags = {
#     Name = "${local.resource_prefix}-alerts"
#   }
# }
#
# resource "aws_sns_topic_subscription" "alerts_email" {
#   count     = var.environment == "prod" ? 1 : 0
#   topic_arn = aws_sns_topic.alerts[0].arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }

# ========================================
# CloudWatch Dashboards
# ========================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.resource_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Lambda API メトリクス
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }],
            [".", "Duration", { stat = "Average", label = "Duration (avg)" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda API Function Metrics"
          yAxis = {
            left = {
              label = "Count"
            }
            right = {
              label = "Milliseconds"
            }
          }
        }
      },
      # DynamoDB メトリクス
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }],
            [".", "UserErrors", { stat = "Sum" }],
            [".", "SystemErrors", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "DynamoDB Metrics"
        }
      },
      # Lambda Concurrent Executions
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", { stat = "Maximum" }]
          ]
          period = 300
          stat   = "Maximum"
          region = var.aws_region
          title  = "Lambda Concurrent Executions"
        }
      }
    ]
  })
}

# ========================================
# CloudWatch Logs Insights - クエリ例
# ========================================

# クエリの保存例（実際には手動で作成することが多い）
resource "aws_cloudwatch_query_definition" "lambda_errors" {
  name = "${local.resource_prefix}-lambda-errors"

  log_group_names = [
    aws_cloudwatch_log_group.lambda_api.name,
    aws_cloudwatch_log_group.lambda_processor.name
  ]

  query_string = <<-QUERY
    fields @timestamp, @message, @logStream
    | filter @message like /ERROR/
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "lambda_performance" {
  name = "${local.resource_prefix}-lambda-performance"

  log_group_names = [
    aws_cloudwatch_log_group.lambda_api.name
  ]

  query_string = <<-QUERY
    filter @type = "REPORT"
    | fields @timestamp, @requestId, @duration, @billedDuration, @maxMemoryUsed
    | sort @duration desc
    | limit 100
  QUERY
}

# ========================================
# Lambda Insights Layer ARN（有効時）
# ========================================

# Lambda Insights を有効にする場合のレイヤーARN
# SAM template.yaml で参照できるように出力する
locals {
  lambda_insights_layer_arn = var.enable_lambda_insights ? (
    # リージョンごとに異なるARNが必要
    var.aws_region == "ap-northeast-1" ? "arn:aws:lambda:ap-northeast-1:580247275435:layer:LambdaInsightsExtension:21" :
    var.aws_region == "us-east-1" ? "arn:aws:lambda:us-east-1:580247275435:layer:LambdaInsightsExtension:21" :
    var.aws_region == "us-west-2" ? "arn:aws:lambda:us-west-2:580247275435:layer:LambdaInsightsExtension:21" :
    var.aws_region == "eu-west-1" ? "arn:aws:lambda:eu-west-1:580247275435:layer:LambdaInsightsExtension:21" :
    ""
  ) : ""
}
