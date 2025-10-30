# ========================================
# Lambda実行ロール - API Function用
# ========================================

resource "aws_iam_role" "lambda_api" {
  name               = "${local.resource_prefix}-lambda-api-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${local.resource_prefix}-lambda-api-role"
  }
}

# Lambda基本実行ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_api_basic" {
  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC アクセス用ポリシー
resource "aws_iam_role_policy_attachment" "lambda_api_vpc" {
  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Insights（有効時）
resource "aws_iam_role_policy_attachment" "lambda_api_insights" {
  count = var.enable_lambda_insights ? 1 : 0

  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}

# DynamoDB アクセス用カスタムポリシー
resource "aws_iam_role_policy" "lambda_api_dynamodb" {
  name   = "${local.resource_prefix}-lambda-api-dynamodb-policy"
  role   = aws_iam_role.lambda_api.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_access.json
}

# X-Ray トレーシング用
resource "aws_iam_role_policy_attachment" "lambda_api_xray" {
  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ========================================
# Lambda実行ロール - Processor Function用
# ========================================

resource "aws_iam_role" "lambda_processor" {
  name               = "${local.resource_prefix}-lambda-processor-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${local.resource_prefix}-lambda-processor-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_processor_basic" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_processor_vpc" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_processor_insights" {
  count = var.enable_lambda_insights ? 1 : 0

  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}

# DynamoDB Streams読み取り権限
resource "aws_iam_role_policy" "lambda_processor_streams" {
  name   = "${local.resource_prefix}-lambda-processor-streams-policy"
  role   = aws_iam_role.lambda_processor.id
  policy = data.aws_iam_policy_document.lambda_streams_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_processor_xray" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ========================================
# IAMポリシードキュメント
# ========================================

# Lambda Assume Role ポリシー
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# DynamoDB アクセスポリシー（最小権限の原則）
data "aws_iam_policy_document" "lambda_dynamodb_access" {
  # 読み取り権限
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem"
    ]
    resources = [
      aws_dynamodb_table.main.arn,
      "${aws_dynamodb_table.main.arn}/index/*"
    ]
  }

  # 書き込み権限
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem"
    ]
    resources = [
      aws_dynamodb_table.main.arn
    ]
  }

  # 条件付きアクセスの例（必要に応じてコメント解除）
  # statement {
  #   effect = "Allow"
  #   actions = [
  #     "dynamodb:PutItem",
  #     "dynamodb:UpdateItem"
  #   ]
  #   resources = [
  #     aws_dynamodb_table.main.arn
  #   ]
  #   condition {
  #     test     = "ForAllValues:StringEquals"
  #     variable = "dynamodb:LeadingKeys"
  #     values   = ["$${aws:username}"]
  #   }
  # }
}

# DynamoDB Streams アクセスポリシー
data "aws_iam_policy_document" "lambda_streams_access" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams"
    ]
    resources = [
      aws_dynamodb_table.main.stream_arn
    ]
  }

  # DynamoDBテーブル情報の読み取り（Streamsに必要）
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable"
    ]
    resources = [
      aws_dynamodb_table.main.arn
    ]
  }
}

# ========================================
# CloudFormation実行ロール（SAM用）
# ========================================

resource "aws_iam_role" "cloudformation_execution" {
  name               = "${local.resource_prefix}-cfn-execution-role"
  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role.json

  tags = {
    Name = "${local.resource_prefix}-cfn-execution-role"
  }
}

data "aws_iam_policy_document" "cloudformation_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# CloudFormation に必要な権限（SAMデプロイ用）
resource "aws_iam_role_policy" "cloudformation_execution" {
  name   = "${local.resource_prefix}-cfn-execution-policy"
  role   = aws_iam_role.cloudformation_execution.id
  policy = data.aws_iam_policy_document.cloudformation_execution.json
}

data "aws_iam_policy_document" "cloudformation_execution" {
  # Lambda関数の作成・更新権限
  statement {
    effect = "Allow"
    actions = [
      "lambda:*"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.lambda_function_prefix}-*"
    ]
  }

  # API Gateway権限
  statement {
    effect = "Allow"
    actions = [
      "apigateway:*"
    ]
    resources = [
      "arn:aws:apigateway:${data.aws_region.current.name}::/*"
    ]
  }

  # IAM PassRole権限（LambdaにIAMロールを渡すため）
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.lambda_api.arn,
      aws_iam_role.lambda_processor.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  # IAMロールの取得権限
  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy"
    ]
    resources = [
      aws_iam_role.lambda_api.arn,
      aws_iam_role.lambda_processor.arn
    ]
  }

  # S3権限（SAMアーティファクト取得用）
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "${aws_s3_bucket.sam_artifacts.arn}/*"
    ]
  }

  # CloudWatch Logs権限
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_prefix}*"
    ]
  }

  # EventBridge権限
  statement {
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:DeleteRule",
      "events:DescribeRule"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${local.resource_prefix}-*"
    ]
  }

  # CloudFormationスタック操作権限
  statement {
    effect = "Allow"
    actions = [
      "cloudformation:CreateChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/${local.resource_prefix}-*/*"
    ]
  }
}
