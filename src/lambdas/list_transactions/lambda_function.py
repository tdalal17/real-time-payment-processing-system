"""
List Transactions Lambda

Retrieves transaction history with filtering and pagination support.

Author: Payment System Team
Version: 1.0.0
"""

import json
import boto3
from typing import Dict, Any, List
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
transactions_table = dynamodb.Table('payment-system-transactions')


class TransactionLister:
    """Handles transaction listing logic"""
    
    def __init__(self):
        """Initialize transaction lister"""
        self.logger_enabled = True
        self.max_page_size = 50
        self.default_page_size = 20
    
    def _log(self, message: str) -> None:
        """Log message if logging is enabled"""
        if self.logger_enabled:
            print(f"[TransactionLister] {message}")
    
    def _response(self, status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
        """Generate standardized API response"""
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-store',
                'X-Payment-System': 'v1.0'
            },
            'body': json.dumps(body, default=str)
        }
    
    def _sanitize_transaction(self, transaction: Dict[str, Any]) -> Dict[str, Any]:
        """Remove sensitive fields from transaction data"""
        return {
            'transaction_id': transaction['transaction_id'],
            'user_id': transaction.get('user_id'),
            'merchant_id': transaction.get('merchant_id'),
            'amount': transaction['amount'],
            'currency': transaction['currency'],
            'status': transaction['status'],
            'timestamp': transaction['timestamp'],
            'created_at': transaction.get('created_at'),
            'message': transaction.get('message', '')
        }
    
    def _parse_query_parameters(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Parse and validate query parameters"""
        query_params = event.get('queryStringParameters') or {}
        
        # Parse pagination parameters
        try:
            limit = min(int(query_params.get('limit', self.default_page_size)), self.max_page_size)
        except ValueError:
            limit = self.default_page_size
        
        # Parse filters
        filters = {}
        if 'user_id' in query_params:
            filters['user_id'] = query_params['user_id']
        if 'merchant_id' in query_params:
            filters['merchant_id'] = query_params['merchant_id']
        if 'status' in query_params:
            filters['status'] = query_params['status']
        
        return {
            'limit': limit,
            'filters': filters,
            'cursor': query_params.get('cursor')
        }
    
    def list_transactions(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """List transactions with optional filtering"""
        
        try:
            self._log("Listing transactions")
            
            # Parse query parameters
            params = self._parse_query_parameters(event)
            
            # For demo purposes, we'll do a scan since we don't have GSIs set up
            # In production, you'd want GSIs for efficient filtering
            scan_kwargs = {
                'Limit': params['limit']
            }
            
            # Add cursor for pagination
            if params['cursor']:
                try:
                    # In production, you'd properly encode/decode the cursor
                    scan_kwargs['ExclusiveStartKey'] = json.loads(params['cursor'])
                except (json.JSONDecodeError, ValueError):
                    self._log("Invalid cursor provided")
            
            try:
                response = transactions_table.scan(**scan_kwargs)
                
                transactions = response.get('Items', [])
                
                # Apply filters (in production, use GSI queries instead)
                if params['filters']:
                    filtered_transactions = []
                    for transaction in transactions:
                        include = True
                        
                        for filter_key, filter_value in params['filters'].items():
                            if transaction.get(filter_key) != filter_value:
                                include = False
                                break
                        
                        if include:
                            filtered_transactions.append(transaction)
                    
                    transactions = filtered_transactions
                
                # Sort by timestamp (newest first)
                transactions.sort(key=lambda x: x.get('timestamp', 0), reverse=True)
                
                # Sanitize transaction data
                safe_transactions = [self._sanitize_transaction(t) for t in transactions]
                
                # Prepare response
                response_data = {
                    'transactions': safe_transactions,
                    'count': len(safe_transactions),
                    'limit': params['limit']
                }
                
                # Add pagination cursor if there are more results
                if 'LastEvaluatedKey' in response:
                    response_data['next_cursor'] = json.dumps(response['LastEvaluatedKey'], default=str)
                
                # Add filter info
                if params['filters']:
                    response_data['filters'] = params['filters']
                
                return self._response(200, response_data)
                
            except ClientError as e:
                self._log(f"DynamoDB error: {str(e)}")
                return self._response(500, {
                    'error': 'Database error',
                    'message': 'Failed to retrieve transactions'
                })
            
        except Exception as e:
            self._log(f"Transaction listing error: {str(e)}")
            return self._response(500, {
                'error': 'Internal server error',
                'message': 'Transaction listing failed'
            })


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for transaction listing
    
    Args:
        event: API Gateway event
        context: Lambda context
    
    Returns:
        Dict containing API response
    """
    lister = TransactionLister()
    return lister.list_transactions(event)