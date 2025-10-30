# ========================================
# VPC
# ========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.resource_prefix}-vpc"
  }
}

# ========================================
# インターネットゲートウェイ
# ========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.resource_prefix}-igw"
  }
}

# ========================================
# パブリックサブネット
# ========================================

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_prefix}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# ========================================
# プライベートサブネット
# ========================================

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.resource_prefix}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# ========================================
# Elastic IP for NAT Gateway
# ========================================

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  domain = "vpc"

  tags = {
    Name = "${local.resource_prefix}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ========================================
# NAT Gateway
# ========================================

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.resource_prefix}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ========================================
# ルートテーブル - パブリック
# ========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.resource_prefix}-public-rt"
    Type = "Public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ========================================
# ルートテーブル - プライベート
# ========================================

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 1

  vpc_id = aws_vpc.main.id

  # NAT Gateway が有効な場合のみルートを追加
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }

  tags = {
    Name = "${local.resource_prefix}-private-rt-${count.index + 1}"
    Type = "Private"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id = aws_subnet.private[count.index].id
  # single_nat_gateway が true の場合は全て同じルートテーブルを使用
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# ========================================
# VPCエンドポイント（コスト削減のため）
# ========================================

# S3 VPCエンドポイント（Gateway型、無料）
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = {
    Name = "${local.resource_prefix}-s3-endpoint"
  }
}

# DynamoDB VPCエンドポイント（Gateway型、無料）
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = {
    Name = "${local.resource_prefix}-dynamodb-endpoint"
  }
}

# ========================================
# セキュリティグループ - Lambda用
# ========================================

resource "aws_security_group" "lambda" {
  name_prefix = "${local.resource_prefix}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  # アウトバウンド: すべて許可（外部APIコール、AWS サービスへのアクセス用）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # インバウンド: VPC内からのHTTPS通信を許可
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  # Lambda間通信用（必要に応じて）
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Allow communication between Lambda functions"
  }

  tags = {
    Name = "${local.resource_prefix}-lambda-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# セキュリティグループ - VPCエンドポイント用（将来の拡張用）
# ========================================

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.resource_prefix}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${local.resource_prefix}-vpc-endpoints-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
