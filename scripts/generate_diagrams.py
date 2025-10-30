#!/usr/bin/env python3
"""
AWSアーキテクチャ図を自動生成するスクリプト
diagrams ライブラリを使用してAWS公式アイコン付きの図を作成
"""

import os
from pathlib import Path
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import Lambda
from diagrams.aws.database import Dynamodb
from diagrams.aws.network import APIGateway, VPC, PrivateSubnet, PublicSubnet, NATGateway, Endpoint
from diagrams.aws.management import Cloudwatch
from diagrams.aws.storage import S3
from diagrams.aws.integration import Eventbridge
from diagrams.onprem.client import Users

# 出力ディレクトリの設定
script_dir = Path(__file__).parent
output_dir = script_dir.parent / "docs" / "images"
output_dir.mkdir(parents=True, exist_ok=True)

# 図の設定
graph_attr = {
    "fontsize": "16",
    "bgcolor": "white",
    "pad": "0.8",
    "splines": "ortho",  # 直角の線
    "nodesep": "0.8",    # ノード間の間隔
    "ranksep": "1.0",    # ランク間の間隔
}

node_attr = {
    "fontsize": "13",
    "fontname": "Sans-Serif",
}

edge_attr = {
    "fontsize": "11",
}

# メインアーキテクチャ図 - Terraform/SAM管理範囲を明示
with Diagram(
    "Terraform + SAM アーキテクチャ（管理範囲明示）",
    filename=str(output_dir / "architecture"),
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    show=False,
    outformat="png"
):
    with Cluster("クライアント"):
        users = Users("ユーザー")

    with Cluster("🔷 SAM管理範囲"):
        with Cluster("API層"):
            apigw = APIGateway("API Gateway\n※SAM")

        with Cluster("Lambda Functions"):
            lambda_api = Lambda("API Function\n(ARM64, 256MB)\n※SAM")
            lambda_processor = Lambda("Stream Processor\n(ARM64, 256MB)\n※SAM")
            lambda_scheduled = Lambda("Scheduled Task\n(ARM64, 256MB)\n※SAM")

        with Cluster("イベント"):
            eventbridge = Eventbridge("EventBridge\nCron Trigger\n※SAM")

    with Cluster("🟦 Terraform管理範囲"):
        with Cluster("VPC: 10.0.0.0/16"):
            with Cluster("Public Subnet - NAT"):
                nat_gw = NATGateway("NAT Gateway\n(Multi-AZ)\n※Terraform")

            with Cluster("VPC Endpoints"):
                vpc_ddb = Endpoint("DynamoDB\nEndpoint\n※Terraform")
                vpc_s3 = Endpoint("S3\nEndpoint\n※Terraform")

        with Cluster("データ層"):
            dynamodb = Dynamodb("DynamoDB\nSingle Table\n※Terraform")

        with Cluster("ストレージ"):
            s3 = S3("S3 Bucket\nArtifacts\n※Terraform")

        with Cluster("監視基盤"):
            cloudwatch = Cloudwatch("CloudWatch\nLogs & Metrics\n※Terraform")

    # メインフロー
    users >> Edge(color="darkblue", style="bold", label="HTTPS") >> apigw
    apigw >> Edge(color="darkgreen", style="bold", label="Invoke") >> lambda_api
    lambda_api >> Edge(color="purple", style="dashed") >> vpc_ddb >> dynamodb

    # Stream処理
    dynamodb >> Edge(color="orange", style="bold", label="Streams") >> lambda_processor
    lambda_processor >> Edge(color="purple", style="dashed") >> dynamodb

    # スケジュール実行
    eventbridge >> Edge(color="red", label="Cron") >> lambda_scheduled
    lambda_scheduled >> Edge(color="purple", style="dashed") >> dynamodb

    # ロギング
    lambda_api >> Edge(color="gray", style="dotted") >> cloudwatch
    lambda_processor >> Edge(color="gray", style="dotted") >> cloudwatch
    lambda_scheduled >> Edge(color="gray", style="dotted") >> cloudwatch

    # S3アクセス
    vpc_s3 >> Edge(style="dashed") >> s3
    nat_gw >> Edge(color="gray", style="dotted", label="Internet") >> cloudwatch

# シンプルな図（README用） - 管理範囲を明示
with Diagram(
    "システム概要（管理範囲別）",
    filename=str(output_dir / "architecture_simple"),
    direction="LR",
    graph_attr={**graph_attr, "splines": "spline", "ranksep": "1.5"},
    node_attr=node_attr,
    edge_attr=edge_attr,
    show=False,
    outformat="png"
):
    users = Users("ユーザー")

    with Cluster("🔷 SAM管理"):
        apigw = APIGateway("API Gateway")

        with Cluster("VPC"):
            lambdas = Lambda("Lambda Functions\n(Python 3.11)")

    with Cluster("🟦 Terraform管理"):
        dynamodb = Dynamodb("DynamoDB\nTable")
        cloudwatch = Cloudwatch("CloudWatch\nMonitoring")

    users >> Edge(label="1. HTTPS") >> apigw
    apigw >> Edge(label="2. Invoke") >> lambdas
    lambdas >> Edge(label="3. CRUD") >> dynamodb
    lambdas >> Edge(label="4. Logs", style="dotted") >> cloudwatch

# 詳細なデータフロー図 - 管理範囲を明示
with Diagram(
    "データフロー詳細（管理範囲別）",
    filename=str(output_dir / "dataflow"),
    direction="TB",
    graph_attr={**graph_attr, "splines": "ortho", "ranksep": "1.2"},
    node_attr=node_attr,
    edge_attr=edge_attr,
    show=False,
    outformat="png"
):
    with Cluster("① クライアント層"):
        users = Users("ユーザー")

    with Cluster("🔷 SAM管理範囲"):
        with Cluster("② API層"):
            apigw = APIGateway("API Gateway\nREST API\n※SAM")

        with Cluster("③ Lambda層"):
            lambda_api = Lambda("API Lambda\nCRUD Operations\n※SAM")
            lambda_processor = Lambda("Stream Processor\nEvent Driven\n※SAM")
            lambda_scheduled = Lambda("Scheduled Job\nBatch Process\n※SAM")

        with Cluster("⑤ イベント層"):
            eventbridge = Eventbridge("EventBridge\nScheduler\n※SAM")

    with Cluster("🟦 Terraform管理範囲"):
        with Cluster("④ データ層"):
            dynamodb = Dynamodb("DynamoDB\nSingle Table Design\n※Terraform")

        with Cluster("⑥ 監視層"):
            cloudwatch = Cloudwatch("CloudWatch\nLogs & Alarms\n※Terraform")

    # メインAPI フロー
    users >> Edge(color="#1a73e8", style="bold", label="HTTPS Request") >> apigw
    apigw >> Edge(color="#34a853", style="bold", label="Invoke") >> lambda_api
    lambda_api >> Edge(color="#ea4335", style="bold", label="Query/Put") >> dynamodb
    dynamodb >> Edge(color="#34a853", style="dashed", label="Response") >> lambda_api
    lambda_api >> Edge(color="#1a73e8", style="dashed", label="JSON") >> apigw
    apigw >> Edge(color="#1a73e8", style="dashed", label="HTTP 200") >> users

    # Stream処理フロー
    dynamodb >> Edge(color="#fbbc04", style="bold", label="DynamoDB Streams") >> lambda_processor
    lambda_processor >> Edge(color="#ea4335", style="dashed", label="Update") >> dynamodb

    # スケジュール処理
    eventbridge >> Edge(color="#9334e6", style="bold", label="Cron: 0 0 * * ?") >> lambda_scheduled
    lambda_scheduled >> Edge(color="#ea4335", style="bold", label="Batch Update") >> dynamodb

    # ロギング（全Lambda）
    lambda_api >> Edge(color="#5f6368", style="dotted", label="Logs") >> cloudwatch
    lambda_processor >> Edge(color="#5f6368", style="dotted", label="Logs") >> cloudwatch
    lambda_scheduled >> Edge(color="#5f6368", style="dotted", label="Logs") >> cloudwatch

print("✅ アーキテクチャ図を生成しました:")
print("   - docs/images/architecture.png (詳細版)")
print("   - docs/images/architecture_simple.png (シンプル版)")
print("   - docs/images/dataflow.png (データフロー)")
