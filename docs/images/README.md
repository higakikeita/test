# アーキテクチャ図

このディレクトリには、AWS公式アイコンを使用したアーキテクチャ図が含まれています。

## 📊 生成された図

### 1. architecture_simple.png
シンプルな概要図。README向けの簡潔なアーキテクチャ表示。

- ユーザー → API Gateway → Lambda → DynamoDB → CloudWatch
- 基本的なデータフローを表示

### 2. architecture.png
詳細なアーキテクチャ図。技術仕様書向け。

- VPC構成（2つのAZ、Public/Private Subnet）
- NAT Gateway、VPC Endpoints
- Lambda関数（API、Processor）
- DynamoDB、CloudWatch、S3、EventBridge
- すべてのコンポーネント間の接続

### 3. dataflow.png
データフロー詳細図。

- CRUD操作フロー（番号付き）
- DynamoDB Streams処理
- スケジュール実行（EventBridge）
- ロギングフロー

## 🔧 図の再生成方法

### 前提条件

```bash
# Python 3.11以上
python3 --version

# Graphvizのインストール
brew install graphviz

# diagrams ライブラリのインストール
pip3 install diagrams
```

### 生成コマンド

```bash
# プロジェクトルートから実行
python3 scripts/generate_diagrams.py
```

実行すると、このディレクトリに以下のPNGファイルが生成されます：
- `architecture.png`
- `architecture_simple.png`
- `dataflow.png`

## 📝 図のカスタマイズ

`scripts/generate_diagrams.py` を編集することで、図をカスタマイズできます：

- **コンポーネントの追加**: 新しいAWSサービスのアイコンを追加
- **レイアウトの変更**: `direction="TB"` (上から下) または `direction="LR"` (左から右)
- **スタイルの変更**: `graph_attr` でフォントサイズ、背景色などを調整

### 利用可能なAWSアイコン

```python
# Compute
from diagrams.aws.compute import Lambda, EC2, ECS, Fargate

# Database
from diagrams.aws.database import Dynamodb, RDS, Aurora, ElastiCache

# Network
from diagrams.aws.network import APIGateway, ELB, ALB, NLB, CloudFront

# Storage
from diagrams.aws.storage import S3, EFS, FSx

# Management
from diagrams.aws.management import Cloudwatch, CloudFormation, SystemsManager

# Integration
from diagrams.aws.integration import Eventbridge, SQS, SNS, StepFunctions
```

詳細は [diagrams公式ドキュメント](https://diagrams.mingrammer.com/docs/nodes/aws) を参照してください。

## 🎨 その他の図形式

### Draw.io形式
編集可能な図は `docs/architecture.drawio` にあります。VS CodeのDraw.io拡張機能で開けます。

### Mermaid形式
README.mdとQIITA_ARTICLE.mdに、GitHubでインタラクティブに表示されるMermaid図も含まれています。

## 📚 参考リンク

- [diagrams - Python diagram as code](https://diagrams.mingrammer.com/)
- [Graphviz](https://graphviz.org/)
- [AWS Architecture Icons](https://aws.amazon.com/jp/architecture/icons/)
