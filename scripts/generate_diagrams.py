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
    "pad": "0.5",
}

# メインアーキテクチャ図
with Diagram(
    "Terraform + SAM アーキテクチャ",
    filename=str(output_dir / "architecture"),
    direction="TB",
    graph_attr=graph_attr,
    show=False,
    outformat="png"
):
    users = Users("ユーザー")
    apigw = APIGateway("API Gateway\nREST API")

    with Cluster("VPC (10.0.0.0/16)"):
        with Cluster("ap-northeast-1a"):
            with Cluster("Public Subnet 1a"):
                nat1 = NATGateway("NAT Gateway 1a")

            with Cluster("Private Subnet 1a"):
                lambda_api_1 = Lambda("API Function\n256MB ARM64")

        with Cluster("ap-northeast-1c"):
            with Cluster("Public Subnet 1c"):
                nat2 = NATGateway("NAT Gateway 1c")

            with Cluster("Private Subnet 1c"):
                lambda_processor = Lambda("Processor\n256MB ARM64")

        with Cluster("VPC Endpoints"):
            vpc_ep_s3 = Endpoint("S3 Endpoint")
            vpc_ep_ddb = Endpoint("DynamoDB Endpoint")

    dynamodb = Dynamodb("DynamoDB Table\nSingle Table Design\nStreams enabled")
    cloudwatch = Cloudwatch("CloudWatch\nLogs/Metrics/Alarms")
    s3 = S3("S3 Bucket\nSAM Artifacts")
    eventbridge = Eventbridge("EventBridge\nCron: 0 0 * * ?")

    # データフロー
    users >> Edge(label="HTTPS") >> apigw
    apigw >> Edge(label="Invoke") >> lambda_api_1

    lambda_api_1 >> Edge(style="dashed") >> vpc_ep_ddb
    vpc_ep_ddb >> dynamodb

    dynamodb >> Edge(label="Stream Events") >> lambda_processor
    lambda_processor >> Edge(style="dashed") >> dynamodb

    eventbridge >> Edge(label="Trigger") >> lambda_processor

    lambda_api_1 >> Edge(style="dotted", label="Logs") >> cloudwatch
    lambda_processor >> Edge(style="dotted", label="Logs") >> cloudwatch

    vpc_ep_s3 >> Edge(style="dashed") >> s3

# シンプルな図（README用）
with Diagram(
    "アーキテクチャ概要",
    filename=str(output_dir / "architecture_simple"),
    direction="LR",
    graph_attr=graph_attr,
    show=False,
    outformat="png"
):
    users = Users("ユーザー")
    apigw = APIGateway("API Gateway")

    with Cluster("VPC"):
        lambda_api = Lambda("Lambda\nFunctions")

    dynamodb = Dynamodb("DynamoDB")
    cloudwatch = Cloudwatch("CloudWatch")

    users >> apigw >> lambda_api >> dynamodb >> cloudwatch

# 詳細なデータフロー図
with Diagram(
    "データフロー詳細",
    filename=str(output_dir / "dataflow"),
    direction="TB",
    graph_attr=graph_attr,
    show=False,
    outformat="png"
):
    with Cluster("クライアント"):
        users = Users("ユーザー")

    with Cluster("API層"):
        apigw = APIGateway("API Gateway")

    with Cluster("アプリケーション層"):
        with Cluster("VPC Private Subnet"):
            lambda_api = Lambda("API Lambda")
            lambda_processor = Lambda("Processor Lambda")
            lambda_scheduled = Lambda("Scheduled Lambda")

    with Cluster("データ層"):
        dynamodb = Dynamodb("DynamoDB\nSingle Table")

    with Cluster("監視層"):
        cloudwatch = Cloudwatch("CloudWatch")

    with Cluster("スケジューラー"):
        eventbridge = Eventbridge("EventBridge")

    # CRUD操作フロー
    users >> Edge(label="1. GET/POST/PUT/DELETE") >> apigw
    apigw >> Edge(label="2. Invoke") >> lambda_api
    lambda_api >> Edge(label="3. CRUD") >> dynamodb
    dynamodb >> Edge(label="4. Response") >> lambda_api
    lambda_api >> Edge(label="5. Response") >> apigw
    apigw >> Edge(label="6. Response") >> users

    # Stream処理フロー
    dynamodb >> Edge(label="Stream Events", style="dashed") >> lambda_processor
    lambda_processor >> Edge(label="Process", style="dashed") >> dynamodb

    # スケジュール処理フロー
    eventbridge >> Edge(label="Cron Trigger", style="dotted") >> lambda_scheduled
    lambda_scheduled >> Edge(label="Batch Process", style="dotted") >> dynamodb

    # ロギング
    [lambda_api, lambda_processor, lambda_scheduled] >> Edge(label="Logs", color="gray") >> cloudwatch

print("✅ アーキテクチャ図を生成しました:")
print("   - docs/images/architecture.png (詳細版)")
print("   - docs/images/architecture_simple.png (シンプル版)")
print("   - docs/images/dataflow.png (データフロー)")
