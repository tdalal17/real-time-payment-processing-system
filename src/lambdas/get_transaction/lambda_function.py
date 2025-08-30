"""
Get Transaction Lambda

Retrieves individual transaction details by transaction ID.

Author: Payment System Team  
Version: 1.0.0
"""

import json
import boto3
from typing import Dict, Any
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
transactions_table = dynamodb.Table('payment-system-transactions')


class TransactionRetriever:
    """Handles transaction retrieval logic"""
    
    def __init__(self):
        """Initialize transaction retriever"""
        self.logger_enabled = True
    
    def _log(self, message: str) -> None:
        """Log message if logging is enabled"""
        if self.logger_enabled:
            print(f"[TransactionRetriever] {message}")
    
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
    
    def get_transaction(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Retrieve transaction by ID"""
        
        try:
            # Extract transaction ID from path parameters
            path_parameters = event.get('pathParameters', {})
            transaction_id = path_parameters.get('transaction_id')
            
            if not transaction_id:
                return self._response(400, {
                    'error': 'Missing transaction_id in path parameters'
                })
            
            self._log(f"Retrieving transaction: {transaction_id}")
            
            # Get transaction from DynamoDB
            try:
                response = transactions_table.get_item(
                    Key={'transaction_id': transaction_id}
                )
                
                if 'Item' not in response:
                    return self._response(404, {
                        'error': 'Transaction not found',
                        'transaction_id': transaction_id
                    })
                
                transaction = response['Item']
                
                # Remove sensitive internal fields
                safe_transaction = {
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
                
                # Include fraud check info if present (for demo purposes)
                if 'fraud_check' in transaction:
                    safe_transaction['fraud_check'] = {
                        'risk_level': transaction['fraud_check'].get('risk_level'),
                        'fraud_score': transaction['fraud_check'].get('fraud_score')
                    }
                
                # Include refund info if present
                if 'refund_info' in transaction:
                    safe_transaction['refund_info'] = transaction['refund_info']
                
                return self._response(200, safe_transaction)
                
            except ClientError as e:
                self._log(f"DynamoDB error: {str(e)}")
                return self._response(500, {
                    'error': 'Database error',
                    'message': 'Failed to retrieve transaction'
                })
            
        except Exception as e:
            self._log(f"Transaction retrieval error: {str(e)}")
            return self._response(500, {
                'error': 'Internal server error',
                'message': 'Transaction retrieval failed'
            })


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for transaction retrieval
    
    Args:
        event: API Gateway event
        context: Lambda context
    
    Returns:
        Dict containing API response
    """
    retriever = TransactionRetriever()
    return retriever.get_transaction(event)