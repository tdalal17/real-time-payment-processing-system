"""
Process Refund Lambda

Handles refund processing for existing transactions.

Author: Payment System Team
Version: 1.0.0
"""

import json
import uuid
import time
import decimal
import boto3
import os
import sys
from typing import Dict, Any, Optional
from datetime import datetime
from botocore.exceptions import ClientError

# Ensure common modules can be imported
try:
    from common.utils import PaymentSystemUtils
except ImportError:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))
    from common.utils import PaymentSystemUtils

# Initialize AWS clients using common utility
dynamodb = PaymentSystemUtils.get_dynamodb_resource()
transactions_table = dynamodb.Table('payment-system-transactions')
idempotency_table = dynamodb.Table('payment-system-idempotency')


class RefundProcessor:
    """Handles refund processing logic"""
    
    def __init__(self):
        """Initialize refund processor"""
        self.logger_enabled = True
    
    def _log(self, message: str) -> None:
        """Log message if logging is enabled"""
        if self.logger_enabled:
            print(f"[RefundProcessor] {message}")
    
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
    
    def _validate_refund_request(self, data: Dict[str, Any], original_transaction: Dict[str, Any]) -> Optional[str]:
        """Validate refund request data"""
        
        # Check if refund amount is provided
        if 'amount' not in data:
            return "Refund amount is required"
        
        # Validate refund amount
        try:
            refund_amount = decimal.Decimal(str(data['amount']))
            original_amount = decimal.Decimal(str(original_transaction['amount']))
            
            if refund_amount <= 0:
                return "Refund amount must be positive"
            
            # Check for partial refunds
            already_refunded = decimal.Decimal('0')
            if 'refund_info' in original_transaction:
                refund_info = original_transaction['refund_info']
                if isinstance(refund_info, dict):
                    already_refunded = decimal.Decimal(str(refund_info.get('total_refunded', '0')))
            
            total_refund = already_refunded + refund_amount
            if total_refund > original_amount:
                return f"Refund amount ({total_refund}) exceeds original transaction amount ({original_amount})"
            
        except (decimal.InvalidOperation, ValueError):
            return "Invalid refund amount format"
        
        return None  # No validation errors
    
    def _get_original_transaction(self, transaction_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve original transaction"""
        try:
            response = transactions_table.get_item(
                Key={'transaction_id': transaction_id}
            )
            
            return response.get('Item')
            
        except ClientError as e:
            self._log(f"Error retrieving transaction {transaction_id}: {str(e)}")
            return None
    
    def _check_refund_eligibility(self, transaction: Dict[str, Any]) -> Optional[str]:
        """Check if transaction is eligible for refund"""
        
        status = transaction.get('status')
        if status != 'completed':
            return f"Cannot refund transaction with status '{status}'. Only completed transactions can be refunded."
        
        # Check if transaction is too old (optional business rule)
        transaction_timestamp = transaction.get('timestamp', 0)
        current_timestamp = int(time.time() * 1000)
        age_days = (current_timestamp - transaction_timestamp) / (1000 * 60 * 60 * 24)
        
        if age_days > 180:  # 6 months
            return "Transaction is too old to refund (over 180 days)"
        
        return None  # Eligible for refund
    
    def _process_refund_transaction(self, original_transaction: Dict[str, Any], refund_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process the refund and update original transaction"""
        
        refund_id = str(uuid.uuid4())
        timestamp = int(time.time() * 1000)
        
        refund_amount = decimal.Decimal(str(refund_data['amount']))
        original_amount = decimal.Decimal(str(original_transaction['amount']))
        
        # Calculate total refunded amount
        current_refunded = decimal.Decimal('0')
        refund_history = []
        
        if 'refund_info' in original_transaction:
            refund_info = original_transaction['refund_info']
            if isinstance(refund_info, dict):
                current_refunded = decimal.Decimal(str(refund_info.get('total_refunded', '0')))
                refund_history = refund_info.get('refunds', [])
        
        new_total_refunded = current_refunded + refund_amount
        
        # Create refund record
        refund_record = {
            'refund_id': refund_id,
            'amount': str(refund_amount),
            'timestamp': timestamp,
            'reason': refund_data.get('reason', 'Refund requested'),
            'processed_at': datetime.utcnow().isoformat()
        }
        
        refund_history.append(refund_record)
        
        # Determine new transaction status
        if new_total_refunded >= original_amount:
            new_status = 'fully_refunded'
        else:
            new_status = 'partially_refunded'
        
        # Update transaction with refund info
        updated_refund_info = {
            'total_refunded': str(new_total_refunded),
            'refund_count': len(refund_history),
            'last_refund_at': timestamp,
            'refunds': refund_history
        }
        
        try:
            # Update the original transaction
            transactions_table.update_item(
                Key={'transaction_id': original_transaction['transaction_id']},
                UpdateExpression='SET #status = :status, refund_info = :refund_info, updated_at = :updated_at',
                ExpressionAttributeNames={
                    '#status': 'status'
                },
                ExpressionAttributeValues={
                    ':status': new_status,
                    ':refund_info': updated_refund_info,
                    ':updated_at': datetime.utcnow().isoformat()
                }
            )
            
            self._log(f"Refund processed: {refund_id} for transaction {original_transaction['transaction_id']}")
            
            return {
                'refund_id': refund_id,
                'transaction_id': original_transaction['transaction_id'],
                'refund_amount': str(refund_amount),
                'original_amount': str(original_amount),
                'total_refunded': str(new_total_refunded),
                'status': new_status,
                'timestamp': timestamp,
                'message': 'Refund processed successfully'
            }
            
        except ClientError as e:
            self._log(f"Error updating transaction: {str(e)}")
            raise
    
    def process_refund(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Main refund processing logic"""
        
        try:
            # Extract transaction ID from path parameters
            path_parameters = event.get('pathParameters', {})
            transaction_id = path_parameters.get('transaction_id')
            
            if not transaction_id:
                return self._response(400, {
                    'error': 'Missing transaction_id in path parameters'
                })
            
            # Parse request body
            try:
                if isinstance(event.get('body'), str):
                    body = json.loads(event['body'])
                else:
                    body = event.get('body', {})
            except json.JSONDecodeError:
                return self._response(400, {'error': 'Invalid JSON in request body'})
            
            self._log(f"Processing refund for transaction: {transaction_id}")
            
            # Get original transaction
            original_transaction = self._get_original_transaction(transaction_id)
            if not original_transaction:
                return self._response(404, {
                    'error': 'Transaction not found',
                    'transaction_id': transaction_id
                })
            
            # Check refund eligibility
            eligibility_error = self._check_refund_eligibility(original_transaction)
            if eligibility_error:
                return self._response(400, {'error': eligibility_error})
            
            # Validate refund request
            validation_error = self._validate_refund_request(body, original_transaction)
            if validation_error:
                return self._response(400, {'error': validation_error})
            
            # Process the refund
            refund_result = self._process_refund_transaction(original_transaction, body)
            
            return self._response(200, refund_result)
            
        except Exception as e:
            self._log(f"Refund processing error: {str(e)}")
            return self._response(500, {
                'error': 'Internal server error',
                'message': 'Refund processing failed'
            })


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for refund processing
    
    Args:
        event: API Gateway event
        context: Lambda context
    
    Returns:
        Dict containing API response
    """
    processor = RefundProcessor()
    return processor.process_refund(event)