#!/bin/bash

# ========================================
# デプロイスクリプト
# Terraform + SAM の一括デプロイ
# ========================================

set -e  # エラーで停止

# 色付きログ
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ========================================
# 引数チェック
# ========================================

if [ $# -lt 1 ]; then
    log_error "Usage: $0 <environment> [--tf-only|--sam-only]"
    echo ""
    echo "Arguments:"
    echo "  environment : dev, staging, or prod"
    echo "  --tf-only   : Deploy only Terraform infrastructure"
    echo "  --sam-only  : Deploy only SAM application"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --tf-only"
    echo "  $0 staging --sam-only"
    exit 1
fi

ENVIRONMENT=$1
DEPLOY_MODE="all"

if [ $# -ge 2 ]; then
    case $2 in
        --tf-only)
            DEPLOY_MODE="terraform"
            ;;
        --sam-only)
            DEPLOY_MODE="sam"
            ;;
        *)
            log_error "Invalid option: $2"
            exit 1
            ;;
    esac
fi

# 環境の検証
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    log_error "Must be one of: dev, staging, prod"
    exit 1
fi

# ========================================
# ディレクトリ
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SAM_DIR="$PROJECT_ROOT/sam"

log_info "Project root: $PROJECT_ROOT"
log_info "Environment: $ENVIRONMENT"
log_info "Deploy mode: $DEPLOY_MODE"

# ========================================
# AWS CLI チェック
# ========================================

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

# AWS認証情報の確認
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "ap-northeast-1")

log_info "AWS Account ID: $AWS_ACCOUNT_ID"
log_info "AWS Region: $AWS_REGION"

# ========================================
# Terraform デプロイ
# ========================================

deploy_terraform() {
    log_info "=========================================="
    log_info "Deploying Terraform infrastructure"
    log_info "=========================================="

    cd "$TERRAFORM_DIR"

    # Terraform バージョン確認
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi

    log_info "Terraform version: $(terraform version -json | jq -r '.terraform_version')"

    # Terraform init
    log_info "Running: terraform init"
    terraform init

    # Terraform plan
    log_info "Running: terraform plan"
    terraform plan -var-file="environments/${ENVIRONMENT}.tfvars" -out=tfplan

    # 確認プロンプト（本番環境のみ）
    if [ "$ENVIRONMENT" = "prod" ]; then
        log_warn "You are about to deploy to PRODUCTION environment"
        read -p "Do you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi

    # Terraform apply
    log_info "Running: terraform apply"
    terraform apply tfplan

    # Outputの保存
    log_info "Saving Terraform outputs"
    terraform output -json > "$SAM_DIR/terraform-outputs.json"

    log_success "Terraform deployment completed"
}

# ========================================
# SAM デプロイ
# ========================================

deploy_sam() {
    log_info "=========================================="
    log_info "Deploying SAM application"
    log_info "=========================================="

    cd "$SAM_DIR"

    # SAM CLI バージョン確認
    if ! command -v sam &> /dev/null; then
        log_error "SAM CLI is not installed"
        exit 1
    fi

    log_info "SAM CLI version: $(sam --version)"

    # Terraform outputs の読み込み
    if [ ! -f "terraform-outputs.json" ]; then
        log_error "terraform-outputs.json not found"
        log_error "Run terraform deployment first or run: terraform output -json > $SAM_DIR/terraform-outputs.json"
        exit 1
    fi

    # パラメータの取得
    S3_BUCKET=$(jq -r '.sam_artifacts_bucket.value' terraform-outputs.json)
    VPC_ID=$(jq -r '.vpc_id.value' terraform-outputs.json)
    SUBNET_IDS=$(jq -r '.private_subnet_ids.value | join(",")' terraform-outputs.json)
    SECURITY_GROUP_ID=$(jq -r '.lambda_security_group_id.value' terraform-outputs.json)
    LAMBDA_API_ROLE_ARN=$(jq -r '.lambda_api_role_arn.value' terraform-outputs.json)
    LAMBDA_PROCESSOR_ROLE_ARN=$(jq -r '.lambda_processor_role_arn.value' terraform-outputs.json)
    DYNAMODB_TABLE_NAME=$(jq -r '.dynamodb_table_name.value' terraform-outputs.json)
    DYNAMODB_STREAM_ARN=$(jq -r '.dynamodb_stream_arn.value // ""' terraform-outputs.json)
    LOG_RETENTION_DAYS=$(jq -r '.log_retention_days.value' terraform-outputs.json)
    LAMBDA_INSIGHTS_LAYER_ARN=$(jq -r '.lambda_insights_layer_arn.value // ""' terraform-outputs.json)

    log_info "S3 Bucket: $S3_BUCKET"
    log_info "VPC ID: $VPC_ID"
    log_info "DynamoDB Table: $DYNAMODB_TABLE_NAME"

    # SAM build
    log_info "Running: sam build"
    sam build

    # SAM deploy
    log_info "Running: sam deploy"
    sam deploy \
        --stack-name "terraform-sam-demo-${ENVIRONMENT}-app" \
        --s3-bucket "$S3_BUCKET" \
        --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
        --no-fail-on-empty-changeset \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            VpcId="$VPC_ID" \
            SubnetIds="$SUBNET_IDS" \
            SecurityGroupId="$SECURITY_GROUP_ID" \
            LambdaApiRoleArn="$LAMBDA_API_ROLE_ARN" \
            LambdaProcessorRoleArn="$LAMBDA_PROCESSOR_ROLE_ARN" \
            DynamoDBTableName="$DYNAMODB_TABLE_NAME" \
            DynamoDBStreamArn="$DYNAMODB_STREAM_ARN" \
            LogRetentionDays="$LOG_RETENTION_DAYS" \
            LambdaInsightsLayerArn="$LAMBDA_INSIGHTS_LAYER_ARN"

    # API Endpoint の取得
    API_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "terraform-sam-demo-${ENVIRONMENT}-app" \
        --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
        --output text)

    log_success "SAM deployment completed"
    log_success "API Endpoint: $API_ENDPOINT"
}

# ========================================
# デプロイ実行
# ========================================

case $DEPLOY_MODE in
    all)
        deploy_terraform
        deploy_sam
        ;;
    terraform)
        deploy_terraform
        ;;
    sam)
        deploy_sam
        ;;
esac

# ========================================
# デプロイ完了
# ========================================

log_success "=========================================="
log_success "Deployment completed successfully!"
log_success "=========================================="

if [ "$DEPLOY_MODE" = "all" ] || [ "$DEPLOY_MODE" = "sam" ]; then
    log_info ""
    log_info "Next steps:"
    log_info "  1. Test the API:"
    log_info "     curl ${API_ENDPOINT}/health"
    log_info ""
    log_info "  2. View CloudWatch Dashboard:"
    log_info "     https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:"
    log_info ""
    log_info "  3. View Lambda functions:"
    log_info "     https://console.aws.amazon.com/lambda/home?region=${AWS_REGION}"
fi
