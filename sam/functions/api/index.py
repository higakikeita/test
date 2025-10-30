"""
API Lambda Function
REST API エンドポイントハンドラー
"""

import json
import os
import logging
from datetime import datetime
from decimal import Decimal
import boto3
from boto3.dynamodb.conditions import Key
import traceback

# ========================================
# ロガー設定
# ========================================

logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(log_level)

# ========================================
# AWS クライアント
# ========================================

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE')
table = dynamodb.Table(table_name)

# ========================================
# ヘルパー関数
# ========================================

class DecimalEncoder(json.JSONEncoder):
    """DynamoDB Decimal型をJSONシリアライズ可能にする"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def create_response(status_code, body, headers=None):
    """
    API Gateway レスポンスを作成

    Args:
        status_code: HTTPステータスコード
        body: レスポンスボディ（dict）
        headers: 追加ヘッダー（dict）

    Returns:
        dict: API Gateway レスポンス形式
    """
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }

    if headers:
        default_headers.update(headers)

    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body, cls=DecimalEncoder, ensure_ascii=False)
    }


def get_current_timestamp():
    """現在のUNIXタイムスタンプを取得"""
    return int(datetime.utcnow().timestamp())


# ========================================
# CRUD操作
# ========================================

def get_items(event):
    """
    GET /items - アイテム一覧取得
    """
    try:
        # クエリパラメータから制限を取得
        query_params = event.get('queryStringParameters') or {}
        limit = int(query_params.get('limit', 20))

        # EntityType でクエリ（GSI使用）
        response = table.query(
            IndexName='EntityTypeIndex',
            KeyConditionExpression=Key('EntityType').eq('Item'),
            ScanIndexForward=False,  # CreatedAt の降順
            Limit=limit
        )

        items = response.get('Items', [])

        logger.info(f"Retrieved {len(items)} items")

        return create_response(200, {
            'items': items,
            'count': len(items)
        })

    except Exception as e:
        logger.error(f"Error getting items: {str(e)}")
        logger.error(traceback.format_exc())
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def get_item(event):
    """
    GET /items/{id} - 特定アイテム取得
    """
    try:
        item_id = event['pathParameters']['id']

        response = table.get_item(
            Key={
                'PK': f'ITEM#{item_id}',
                'SK': 'METADATA'
            }
        )

        if 'Item' not in response:
            return create_response(404, {
                'error': 'Not found',
                'message': f'Item {item_id} not found'
            })

        item = response['Item']
        logger.info(f"Retrieved item: {item_id}")

        return create_response(200, {
            'item': item
        })

    except Exception as e:
        logger.error(f"Error getting item: {str(e)}")
        logger.error(traceback.format_exc())
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def create_item(event):
    """
    POST /items - アイテム作成
    """
    try:
        body = json.loads(event['body'])

        # バリデーション
        if 'name' not in body:
            return create_response(400, {
                'error': 'Bad request',
                'message': 'name is required'
            })

        # アイテムID生成（簡易版、本番ではUUIDなどを使用）
        import uuid
        item_id = str(uuid.uuid4())

        current_time = get_current_timestamp()

        # DynamoDBアイテム作成
        item = {
            'PK': f'ITEM#{item_id}',
            'SK': 'METADATA',
            'EntityType': 'Item',
            'ItemId': item_id,
            'Name': body['name'],
            'Description': body.get('description', ''),
            'Status': body.get('status', 'active'),
            'CreatedAt': current_time,
            'UpdatedAt': current_time,
            'GSI1PK': f'ITEM#{item_id}',
            'GSI1SK': f'CREATED#{current_time}'
        }

        # 有効期限（TTL）の設定例（30日後）
        # item['ExpiresAt'] = current_time + (30 * 24 * 60 * 60)

        table.put_item(Item=item)

        logger.info(f"Created item: {item_id}")

        return create_response(201, {
            'message': 'Item created successfully',
            'item': item
        })

    except json.JSONDecodeError:
        return create_response(400, {
            'error': 'Bad request',
            'message': 'Invalid JSON'
        })
    except Exception as e:
        logger.error(f"Error creating item: {str(e)}")
        logger.error(traceback.format_exc())
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def update_item(event):
    """
    PUT /items/{id} - アイテム更新
    """
    try:
        item_id = event['pathParameters']['id']
        body = json.loads(event['body'])

        # 存在確認
        response = table.get_item(
            Key={
                'PK': f'ITEM#{item_id}',
                'SK': 'METADATA'
            }
        )

        if 'Item' not in response:
            return create_response(404, {
                'error': 'Not found',
                'message': f'Item {item_id} not found'
            })

        current_time = get_current_timestamp()

        # 更新式の構築
        update_expression_parts = []
        expression_attribute_values = {}
        expression_attribute_names = {}

        if 'name' in body:
            update_expression_parts.append('#name = :name')
            expression_attribute_values[':name'] = body['name']
            expression_attribute_names['#name'] = 'Name'

        if 'description' in body:
            update_expression_parts.append('#description = :description')
            expression_attribute_values[':description'] = body['description']
            expression_attribute_names['#description'] = 'Description'

        if 'status' in body:
            update_expression_parts.append('#status = :status')
            expression_attribute_values[':status'] = body['status']
            expression_attribute_names['#status'] = 'Status'

        # UpdatedAt は常に更新
        update_expression_parts.append('UpdatedAt = :updated_at')
        expression_attribute_values[':updated_at'] = current_time

        if not update_expression_parts:
            return create_response(400, {
                'error': 'Bad request',
                'message': 'No fields to update'
            })

        update_expression = 'SET ' + ', '.join(update_expression_parts)

        # 更新実行
        response = table.update_item(
            Key={
                'PK': f'ITEM#{item_id}',
                'SK': 'METADATA'
            },
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_attribute_values,
            ExpressionAttributeNames=expression_attribute_names if expression_attribute_names else None,
            ReturnValues='ALL_NEW'
        )

        logger.info(f"Updated item: {item_id}")

        return create_response(200, {
            'message': 'Item updated successfully',
            'item': response['Attributes']
        })

    except json.JSONDecodeError:
        return create_response(400, {
            'error': 'Bad request',
            'message': 'Invalid JSON'
        })
    except Exception as e:
        logger.error(f"Error updating item: {str(e)}")
        logger.error(traceback.format_exc())
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def delete_item(event):
    """
    DELETE /items/{id} - アイテム削除
    """
    try:
        item_id = event['pathParameters']['id']

        # 存在確認
        response = table.get_item(
            Key={
                'PK': f'ITEM#{item_id}',
                'SK': 'METADATA'
            }
        )

        if 'Item' not in response:
            return create_response(404, {
                'error': 'Not found',
                'message': f'Item {item_id} not found'
            })

        # 削除実行
        table.delete_item(
            Key={
                'PK': f'ITEM#{item_id}',
                'SK': 'METADATA'
            }
        )

        logger.info(f"Deleted item: {item_id}")

        return create_response(200, {
            'message': 'Item deleted successfully'
        })

    except Exception as e:
        logger.error(f"Error deleting item: {str(e)}")
        logger.error(traceback.format_exc())
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def health_check(event):
    """
    GET /health - ヘルスチェック
    """
    try:
        # DynamoDB接続確認
        table.table_status

        return create_response(200, {
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'environment': os.environ.get('ENVIRONMENT'),
            'version': os.environ.get('API_VERSION', 'v1')
        })
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return create_response(503, {
            'status': 'unhealthy',
            'error': str(e)
        })


# ========================================
# Lambda Handler
# ========================================

def lambda_handler(event, context):
    """
    Lambda エントリーポイント

    Args:
        event: API Gateway イベント
        context: Lambda コンテキスト

    Returns:
        dict: API Gateway レスポンス
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        http_method = event['httpMethod']
        path = event['path']

        # ルーティング
        if path == '/health' and http_method == 'GET':
            return health_check(event)
        elif path == '/items' and http_method == 'GET':
            return get_items(event)
        elif path == '/items' and http_method == 'POST':
            return create_item(event)
        elif path.startswith('/items/') and http_method == 'GET':
            return get_item(event)
        elif path.startswith('/items/') and http_method == 'PUT':
            return update_item(event)
        elif path.startswith('/items/') and http_method == 'DELETE':
            return delete_item(event)
        else:
            return create_response(404, {
                'error': 'Not found',
                'message': f'Route not found: {http_method} {path}'
            })

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        logger.error(traceback.format_exc())
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })
