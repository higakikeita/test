#!/bin/bash

# ========================================
# 検証スクリプト
# Terraform と SAM のコード検証
# ========================================

set -e

# 色付きログ
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ========================================
# ディレクトリ
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SAM_DIR="$PROJECT_ROOT/sam"

ENVIRONMENT=${1:-dev}

log_info "Validating project for environment: $ENVIRONMENT"

# ========================================
# Terraform 検証
# ========================================

log_info "=========================================="
log_info "Validating Terraform code"
log_info "=========================================="

cd "$TERRAFORM_DIR"

# Terraform fmt
log_info "Running: terraform fmt -check"
if terraform fmt -check -recursive; then
    log_success "Terraform formatting is correct"
else
    log_error "Terraform formatting issues found. Run: terraform fmt -recursive"
    exit 1
fi

# Terraform init
log_info "Running: terraform init"
terraform init -backend=false

# Terraform validate
log_info "Running: terraform validate"
if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform validation failed"
    exit 1
fi

# Terraform plan (dry-run)
log_info "Running: terraform plan"
if terraform plan -var-file="environments/${ENVIRONMENT}.tfvars" -out=/dev/null; then
    log_success "Terraform plan succeeded"
else
    log_error "Terraform plan failed"
    exit 1
fi

# ========================================
# SAM 検証
# ========================================

log_info "=========================================="
log_info "Validating SAM template"
log_info "=========================================="

cd "$SAM_DIR"

# SAM validate
log_info "Running: sam validate"
if sam validate; then
    log_success "SAM template is valid"
else
    log_error "SAM template validation failed"
    exit 1
fi

# SAM build
log_info "Running: sam build"
if sam build; then
    log_success "SAM build succeeded"
else
    log_error "SAM build failed"
    exit 1
fi

# ========================================
# Python コード検証
# ========================================

log_info "=========================================="
log_info "Validating Python code"
log_info "=========================================="

# Python構文チェック
log_info "Checking Python syntax"
find "$SAM_DIR" -name "*.py" -type f | while read -r file; do
    if python3 -m py_compile "$file"; then
        log_info "  ✓ $file"
    else
        log_error "  ✗ $file"
        exit 1
    fi
done

log_success "Python syntax is correct"

# ========================================
# 完了
# ========================================

log_success "=========================================="
log_success "All validations passed!"
log_success "=========================================="
