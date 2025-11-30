import json
import uuid
import time
import decimal
import boto3
import os
import sys
from typing import Dict, Any, Optional
from datetime import datetime

try:
    from common.utils import PaymentSystemUtils
except ImportError:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))
    from common.utils import PaymentSystemUtils

dynamodb = PaymentSystemUtils.get_dynamodb_resource()
transactions_table = dynamodb.Table('payment-system-transactions')
idempotency_table = dynamodb.Table('payment-system-idempotency')


class PaymentProcessor:
    SUPPORTED_CURRENCIES = ['USD', 'EUR', 'GBP']
    MIN_AMOUNT = decimal.Decimal('0.01')
    MAX_AMOUNT = decimal.Decimal('99999.99')

    def __init__(self):
        self.logger_enabled = True

    def _log(self, message: str) -> None:
        if self.logger_enabled:
            print(f"[PaymentProcessor] {message}")
    
    def _response(self, status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-store',
                'X-Payment-System': 'v1.0'
            },
            'body': json.dumps(body, default=str)
        }
    
    def _validate_payment_request(self, data: Dict[str, Any]) -> Optional[str]:
        required_fields = ['amount', 'currency', 'user_id', 'merchant_id']
        for field in required_fields:
            if field not in data:
                return f"Missing required field: {field}"

        # Validate amount
        try:
            amount = decimal.Decimal(str(data['amount']))
            if amount < self.MIN_AMOUNT:
                return f"Amount must be at least {self.MIN_AMOUNT}"
            if amount > self.MAX_AMOUNT:
                return f"Amount must not exceed {self.MAX_AMOUNT}"
        except (decimal.InvalidOperation, ValueError):
            return "Invalid amount format"
        
        # Validate currency
        if data['currency'] not in self.SUPPORTED_CURRENCIES:
            return f"Unsupported currency. Supported: {', '.join(self.SUPPORTED_CURRENCIES)}"

        # FIXME: should add regex validation for user_id and merchant_id
        if not data['user_id'].strip():
            return "user_id cannot be empty"
        if not data['merchant_id'].strip():
            return "merchant_id cannot be empty"

        return None
    
    def _check_idempotency(self, idempotency_key: str) -> Optional[Dict[str, Any]]:
        if not idempotency_key:
            return None
        
        try:
            response = idempotency_table.get_item(
                Key={'idempotency_key': idempotency_key}
            )
            
            if 'Item' in response:
                self._log(f"Duplicate request detected: {idempotency_key}")
                return response['Item']
            
        except Exception as e:
            self._log(f"Error checking idempotency: {str(e)}")
        
        return None
    
    def _store_idempotency(self, idempotency_key: str, transaction_data: Dict[str, Any]) -> None:
        if not idempotency_key:
            return
        
        try:
            idempotency_table.put_item(
                Item={
                    'idempotency_key': idempotency_key,
                    'transaction_id': transaction_data['transaction_id'],
                    'response_data': transaction_data,
                    'created_at': int(time.time()),
                    'ttl': int(time.time()) + 86400  # 24 hours TTL
                }
            )
        except Exception as e:
            self._log(f"Error storing idempotency record: {str(e)}")
    
    def _perform_fraud_check(self, payment_data: Dict[str, Any]) -> Dict[str, Any]:
        # TODO: integrate with actual fraud detection service (Stripe Radar, Sift, etc.)
        fraud_score = 0
        risk_factors = []

        amount = decimal.Decimal(str(payment_data['amount']))

        if amount > decimal.Decimal('1000.00'):
            fraud_score += 50
            risk_factors.append('high_amount')

        if amount > decimal.Decimal('5000.00'):
            fraud_score += 50
            risk_factors.append('very_high_amount')

        if amount % 1 == 0 and amount >= decimal.Decimal('100.00'):
            fraud_score += 10
            risk_factors.append('round_amount')
        if fraud_score >= 80:
            risk_level = 'HIGH'
            decision = 'DECLINE'
        elif fraud_score >= 50:
            risk_level = 'MEDIUM'
            decision = 'REVIEW'
        else:
            risk_level = 'LOW'
            decision = 'APPROVE'
        
        return {
            'fraud_score': fraud_score,
            'risk_level': risk_level,
            'decision': decision,
            'risk_factors': risk_factors
        }
    
    def _store_transaction(self, transaction_data: Dict[str, Any]) -> None:
        try:
            transactions_table.put_item(Item=transaction_data)
            self._log(f"Transaction stored: {transaction_data['transaction_id']}")
        except Exception as e:
            self._log(f"Error storing transaction: {str(e)}")
            raise
    
    def process_payment(self, event: Dict[str, Any]) -> Dict[str, Any]:
        try:
            # Parse request body
            try:
                if isinstance(event.get('body'), str):
                    body = json.loads(event['body'])
                else:
                    body = event.get('body', {})
            except json.JSONDecodeError:
                return self._response(400, {'error': 'Invalid JSON in request body'})
            
            self._log(f"Processing payment request: {json.dumps(body, default=str)}")
            
            # Validate request
            validation_error = self._validate_payment_request(body)
            if validation_error:
                return self._response(400, {'error': validation_error})
            
            # Check idempotency
            idempotency_key = event.get('headers', {}).get('Idempotency-Key')
            if idempotency_key:
                existing_transaction = self._check_idempotency(idempotency_key)
                if existing_transaction:
                    return self._response(200, existing_transaction['response_data'])
            
            # Generate transaction ID
            transaction_id = str(uuid.uuid4())
            timestamp = int(time.time() * 1000)  # milliseconds
            
            # Perform fraud check
            fraud_result = self._perform_fraud_check(body)
            
            # Determine final status based on fraud check
            if fraud_result['decision'] == 'DECLINE':
                status = 'declined'
                message = 'Payment declined due to risk assessment'
            elif fraud_result['decision'] == 'REVIEW':
                status = 'pending_review'
                message = 'Payment requires manual review'
            else:
                status = 'completed'
                message = 'Payment processed successfully'
            
            # Prepare transaction data
            transaction_data = {
                'transaction_id': transaction_id,
                'user_id': body['user_id'],
                'merchant_id': body['merchant_id'],
                'amount': str(body['amount']),
                'currency': body['currency'],
                'status': status,
                'timestamp': timestamp,
                'created_at': datetime.utcnow().isoformat(),
                'fraud_check': fraud_result,
                'message': message
            }
            
            # Store transaction
            self._store_transaction(transaction_data)
            
            # Store idempotency record
            if idempotency_key:
                self._store_idempotency(idempotency_key, transaction_data)
            
            # Prepare response
            response_data = {
                'transaction_id': transaction_id,
                'status': status,
                'amount': str(body['amount']),
                'currency': body['currency'],
                'timestamp': timestamp,
                'message': message
            }
            
            # Include fraud info for all transactions (for demo purposes)
            response_data['fraud_check'] = {
                'risk_level': fraud_result['risk_level'],
                'fraud_score': fraud_result['fraud_score']
            }
            
            status_code = 200 if status in ['completed', 'pending_review'] else 402
            return self._response(status_code, response_data)
            
        except Exception as e:
            self._log(f"Payment processing error: {str(e)}")
            return self._response(500, {
                'error': 'Internal server error',
                'message': 'Payment processing failed'
            })


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    processor = PaymentProcessor()
    return processor.process_payment(event)