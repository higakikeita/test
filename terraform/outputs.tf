# ========================================
# Terraform Outputs
# SAMデプロイ時に使用する値を出力
# ========================================

# ========================================
# VPC関連
# ========================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットのIDリスト"
  value       = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  description = "Lambda用セキュリティグループID"
  value       = aws_security_group.lambda.id
}

output "vpc_endpoints_security_group_id" {
  description = "VPCエンドポイント用セキュリティグループID"
  value       = aws_security_group.vpc_endpoints.id
}

# ========================================
# IAM関連
# ========================================

output "lambda_api_role_arn" {
  description = "Lambda API Function用IAMロールARN"
  value       = aws_iam_role.lambda_api.arn
}

output "lambda_api_role_name" {
  description = "Lambda API Function用IAMロール名"
  value       = aws_iam_role.lambda_api.name
}

output "lambda_processor_role_arn" {
  description = "Lambda Processor Function用IAMロールARN"
  value       = aws_iam_role.lambda_processor.arn
}

output "lambda_processor_role_name" {
  description = "Lambda Processor Function用IAMロール名"
  value       = aws_iam_role.lambda_processor.name
}

output "cloudformation_execution_role_arn" {
  description = "CloudFormation実行ロールARN（SAMデプロイ用）"
  value       = aws_iam_role.cloudformation_execution.arn
}

# ========================================
# S3関連
# ========================================

output "sam_artifacts_bucket" {
  description = "SAMアーティファクト保存用S3バケット名"
  value       = aws_s3_bucket.sam_artifacts.id
}

output "sam_artifacts_bucket_arn" {
  description = "SAMアーティファクト保存用S3バケットARN"
  value       = aws_s3_bucket.sam_artifacts.arn
}

# ========================================
# DynamoDB関連
# ========================================

output "dynamodb_table_name" {
  description = "DynamoDBテーブル名"
  value       = aws_dynamodb_table.main.name
}

output "dynamodb_table_arn" {
  description = "DynamoDBテーブルARN"
  value       = aws_dynamodb_table.main.arn
}

output "dynamodb_stream_arn" {
  description = "DynamoDB StreamsのARN"
  value       = var.enable_dynamodb_streams ? aws_dynamodb_table.main.stream_arn : null
}

output "dynamodb_stream_label" {
  description = "DynamoDB Streamsのラベル"
  value       = var.enable_dynamodb_streams ? aws_dynamodb_table.main.stream_label : null
}

# ========================================
# CloudWatch関連
# ========================================

output "lambda_api_log_group" {
  description = "Lambda API Function用CloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.lambda_api.name
}

output "lambda_processor_log_group" {
  description = "Lambda Processor Function用CloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.lambda_processor.name
}

output "log_retention_days" {
  description = "CloudWatch Logsの保持日数"
  value       = var.log_retention_days
}

output "lambda_insights_layer_arn" {
  description = "Lambda Insights LayerのARN（有効時）"
  value       = local.lambda_insights_layer_arn
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch Dashboardの名前"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

# ========================================
# プロジェクト情報
# ========================================

output "project_name" {
  description = "プロジェクト名"
  value       = var.project_name
}

output "environment" {
  description = "環境名"
  value       = var.environment
}

output "aws_region" {
  description = "AWSリージョン"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWSアカウントID"
  value       = data.aws_caller_identity.current.account_id
}

output "resource_prefix" {
  description = "リソース名プレフィックス"
  value       = local.resource_prefix
}

# ========================================
# SAM用パラメータ（JSON形式）
# ========================================

output "sam_parameters" {
  description = "SAMデプロイ用のパラメータ（JSON形式）"
  value = jsonencode({
    Environment            = var.environment
    VpcId                  = aws_vpc.main.id
    SubnetIds              = join(",", aws_subnet.private[*].id)
    SecurityGroupId        = aws_security_group.lambda.id
    LambdaApiRoleArn       = aws_iam_role.lambda_api.arn
    LambdaProcessorRoleArn = aws_iam_role.lambda_processor.arn
    DynamoDBTableName      = aws_dynamodb_table.main.name
    DynamoDBStreamArn      = var.enable_dynamodb_streams ? aws_dynamodb_table.main.stream_arn : ""
    LogRetentionDays       = var.log_retention_days
    LambdaInsightsLayerArn = local.lambda_insights_layer_arn
  })
}

# ========================================
# デプロイコマンド例
# ========================================

output "sam_deploy_command" {
  description = "SAMデプロイコマンドの例"
  value = <<-EOT
    cd ../sam && \
    sam build && \
    sam deploy \
      --stack-name ${local.resource_prefix}-app \
      --s3-bucket ${aws_s3_bucket.sam_artifacts.id} \
      --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
      --parameter-overrides \
        Environment=${var.environment} \
        VpcId=${aws_vpc.main.id} \
        SubnetIds=${join(",", aws_subnet.private[*].id)} \
        SecurityGroupId=${aws_security_group.lambda.id} \
        LambdaApiRoleArn=${aws_iam_role.lambda_api.arn} \
        LambdaProcessorRoleArn=${aws_iam_role.lambda_processor.arn} \
        DynamoDBTableName=${aws_dynamodb_table.main.name} \
        DynamoDBStreamArn=${var.enable_dynamodb_streams ? aws_dynamodb_table.main.stream_arn : ""} \
        LogRetentionDays=${var.log_retention_days}
  EOT
}

# ========================================
# コスト見積もり（概算）
# ========================================

output "estimated_monthly_cost" {
  description = "月間推定コスト（概算、米ドル）"
  value = {
    nat_gateway      = var.enable_nat_gateway ? (var.single_nat_gateway ? 32.4 : 64.8) : 0
    lambda_baseline  = 0.2  # 100万リクエスト想定
    api_gateway      = 3.5  # 100万リクエスト想定
    dynamodb         = var.dynamodb_billing_mode == "PAY_PER_REQUEST" ? 1.25 : 0 # オンデマンド想定
    cloudwatch_logs  = 0.5  # 少量のログ想定
    total_estimated  = var.enable_nat_gateway ? (var.single_nat_gateway ? 38 : 70) : 6
    note             = "実際のコストは使用量により大きく変動します。NAT Gatewayが最大のコスト要因です。"
  }
}

# ========================================
# 次のステップ
# ========================================

output "next_steps" {
  description = "次に実行すべきステップ"
  value = <<-EOT
    ✅ Terraform インフラストラクチャのデプロイが完了しました

    次のステップ:
    1. Terraform出力値をSAMで使用できるように保存:
       terraform output -json > ../sam/terraform-outputs.json

    2. SAMアプリケーションをビルド:
       cd ../sam && sam build

    3. ローカルテスト（オプション）:
       sam local start-api

    4. SAMアプリケーションをデプロイ:
       sam deploy --guided
       または
       ${local.resource_prefix}/scripts/deploy.sh ${var.environment}

    5. CloudWatch Dashboardで監視:
       https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}
  EOT
}
