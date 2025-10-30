"""
Processor Lambda Function
DynamoDB Streams イベント処理
"""

import json
import os
import logging
from datetime import datetime
import boto3
from decimal import Decimal

# ========================================
# ロガー設定
# ========================================

logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(log_level)

# ========================================
# AWS クライアント
# ========================================

# CloudWatch Metricsへの記録用（オプション）
cloudwatch = boto3.client('cloudwatch')
environment = os.environ.get('ENVIRONMENT', 'dev')

# ========================================
# ヘルパー関数
# ========================================

class DecimalEncoder(json.JSONEncoder):
    """DynamoDB Decimal型をJSONシリアライズ可能にする"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def parse_dynamodb_image(image):
    """
    DynamoDB Streams の画像データをパース

    Args:
        image: DynamoDB画像データ

    Returns:
        dict: パースされたデータ
    """
    if not image:
        return None

    result = {}
    for key, value in image.items():
        # DynamoDB型からPython型に変換
        if 'S' in value:
            result[key] = value['S']
        elif 'N' in value:
            result[key] = Decimal(value['N'])
        elif 'BOOL' in value:
            result[key] = value['BOOL']
        elif 'M' in value:
            result[key] = parse_dynamodb_image(value['M'])
        elif 'L' in value:
            result[key] = [parse_dynamodb_image({'item': item})['item'] for item in value['L']]
        elif 'NULL' in value:
            result[key] = None

    return result


def send_metric(metric_name, value, unit='Count'):
    """
    CloudWatch Metrics に メトリクスを送信

    Args:
        metric_name: メトリクス名
        value: 値
        unit: 単位
    """
    try:
        cloudwatch.put_metric_data(
            Namespace='TerraformSAMDemo',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow(),
                    'Dimensions': [
                        {
                            'Name': 'Environment',
                            'Value': environment
                        }
                    ]
                }
            ]
        )
        logger.debug(f"Sent metric: {metric_name} = {value}")
    except Exception as e:
        logger.error(f"Failed to send metric: {str(e)}")


# ========================================
# イベント処理ハンドラー
# ========================================

def process_insert_event(record):
    """
    INSERT イベント処理

    Args:
        record: DynamoDB Streams レコード
    """
    new_image = parse_dynamodb_image(record['dynamodb'].get('NewImage', {}))

    logger.info(f"Processing INSERT event: {json.dumps(new_image, cls=DecimalEncoder)}")

    # 新規アイテムに対する処理を実装
    # 例: 通知送信、別システムへの連携、集計処理など

    entity_type = new_image.get('EntityType')

    if entity_type == 'Item':
        # アイテム作成時の処理
        logger.info(f"New item created: {new_image.get('ItemId')}")

        # メトリクス送信
        send_metric('ItemsCreated', 1)

        # 追加の処理（例: 通知、検索インデックス更新など）
        # send_notification(new_image)
        # update_search_index(new_image)

    return {
        'status': 'success',
        'event_type': 'INSERT',
        'entity_type': entity_type
    }


def process_modify_event(record):
    """
    MODIFY イベント処理

    Args:
        record: DynamoDB Streams レコード
    """
    old_image = parse_dynamodb_image(record['dynamodb'].get('OldImage', {}))
    new_image = parse_dynamodb_image(record['dynamodb'].get('NewImage', {}))

    logger.info(f"Processing MODIFY event")
    logger.debug(f"Old: {json.dumps(old_image, cls=DecimalEncoder)}")
    logger.debug(f"New: {json.dumps(new_image, cls=DecimalEncoder)}")

    # 変更内容の分析
    changed_fields = []
    for key in new_image.keys():
        if key in old_image and old_image[key] != new_image[key]:
            changed_fields.append(key)
            logger.info(f"Field changed: {key} = {old_image[key]} -> {new_image[key]}")

    entity_type = new_image.get('EntityType')

    if entity_type == 'Item':
        # アイテム更新時の処理
        logger.info(f"Item updated: {new_image.get('ItemId')}")
        logger.info(f"Changed fields: {changed_fields}")

        # メトリクス送信
        send_metric('ItemsModified', 1)

        # ステータス変更の検出
        if 'Status' in changed_fields:
            old_status = old_image.get('Status')
            new_status = new_image.get('Status')
            logger.info(f"Status changed: {old_status} -> {new_status}")

            # ステータスに応じた処理
            if new_status == 'inactive':
                logger.info("Item deactivated")
                # 非アクティブ化時の処理

    return {
        'status': 'success',
        'event_type': 'MODIFY',
        'entity_type': entity_type,
        'changed_fields': changed_fields
    }


def process_remove_event(record):
    """
    REMOVE イベント処理

    Args:
        record: DynamoDB Streams レコード
    """
    old_image = parse_dynamodb_image(record['dynamodb'].get('OldImage', {}))

    logger.info(f"Processing REMOVE event: {json.dumps(old_image, cls=DecimalEncoder)}")

    entity_type = old_image.get('EntityType')

    if entity_type == 'Item':
        # アイテム削除時の処理
        logger.info(f"Item deleted: {old_image.get('ItemId')}")

        # メトリクス送信
        send_metric('ItemsDeleted', 1)

        # 削除に伴うクリーンアップ処理
        # cleanup_related_resources(old_image)

    return {
        'status': 'success',
        'event_type': 'REMOVE',
        'entity_type': entity_type
    }


# ========================================
# Lambda Handler
# ========================================

def lambda_handler(event, context):
    """
    Lambda エントリーポイント

    Args:
        event: DynamoDB Streams イベント
        context: Lambda コンテキスト

    Returns:
        dict: 処理結果
    """
    logger.info(f"Processing {len(event['Records'])} records")

    results = []
    successful_count = 0
    failed_count = 0

    for record in event['Records']:
        try:
            event_name = record['eventName']
            logger.info(f"Processing event: {event_name}")

            # イベントタイプに応じた処理
            if event_name == 'INSERT':
                result = process_insert_event(record)
            elif event_name == 'MODIFY':
                result = process_modify_event(record)
            elif event_name == 'REMOVE':
                result = process_remove_event(record)
            else:
                logger.warning(f"Unknown event type: {event_name}")
                result = {
                    'status': 'skipped',
                    'event_type': event_name
                }

            results.append(result)
            successful_count += 1

        except Exception as e:
            logger.error(f"Error processing record: {str(e)}")
            logger.error(f"Record: {json.dumps(record)}")
            import traceback
            logger.error(traceback.format_exc())

            results.append({
                'status': 'failed',
                'error': str(e)
            })
            failed_count += 1

            # エラーをメトリクスとして記録
            send_metric('ProcessingErrors', 1)

    # 処理結果のメトリクス送信
    send_metric('RecordsProcessed', successful_count)

    logger.info(f"Processing complete: {successful_count} successful, {failed_count} failed")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Processing complete',
            'total_records': len(event['Records']),
            'successful': successful_count,
            'failed': failed_count,
            'results': results
        }, cls=DecimalEncoder)
    }


# ========================================
# 高度な処理の例
# ========================================

def send_notification(item):
    """
    通知送信の例（SNS、SQS、EventBridgeなど）

    Args:
        item: DynamoDBアイテム
    """
    # SNS通知の例
    # sns = boto3.client('sns')
    # sns.publish(
    #     TopicArn='arn:aws:sns:region:account:topic',
    #     Message=json.dumps(item, cls=DecimalEncoder),
    #     Subject='New Item Created'
    # )
    pass


def update_search_index(item):
    """
    検索インデックス更新の例（OpenSearch、Elasticsearchなど）

    Args:
        item: DynamoDBアイテム
    """
    # OpenSearch への インデックス登録例
    # from opensearchpy import OpenSearch
    # client = OpenSearch([{'host': 'localhost', 'port': 9200}])
    # client.index(index='items', id=item['ItemId'], body=item)
    pass


def cleanup_related_resources(item):
    """
    関連リソースのクリーンアップ例

    Args:
        item: 削除されたDynamoDBアイテム
    """
    # S3ファイルの削除、他テーブルのクリーンアップなど
    pass
