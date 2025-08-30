import json
import uuid
import time
import re
from typing import Any, Dict, Optional
from decimal import Decimal
import boto3
from src.auth.security import authenticate_request, authorize_request, SecurityManager

class SecurePaymentProcessor:
    """Enterprise-grade secure payment processor with PCI-DSS compliance"""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.transactions_table = self.dynamodb.Table('payment-system-transactions')
        self.idempotency_table = self.dynamodb.Table('payment-system-idempotency')
        self.security_manager = SecurityManager()
        
        # PCI-DSS sensitive fields that need special handling
        self.sensitive_fields = {'card_number', 'cvv', 'card_holder_name'}
    
    def _mask_sensitive_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Mask sensitive data for logging compliance"""
        masked_data = data.copy()
        
        if 'card_number' in masked_data:
            card_number = str(masked_data['card_number'])
            # Show only first 6 and last 4 digits (PCI-DSS compliant)
            if len(card_number) >= 10:
                masked_data['card_number'] = f"{card_number[:6]}****{card_number[-4:]}"
            else:
                masked_data['card_number'] = "****"
                
        if 'cvv' in masked_data:
            masked_data['cvv'] = "***"
            
        if 'card_holder_name' in masked_data:
            name = str(masked_data['card_holder_name'])
            if len(name) > 2:
                masked_data['card_holder_name'] = name[0] + "*" * (len(name) - 2) + name[-1]
            else:
                masked_data['card_holder_name'] = "***"
                
        return masked_data
    
    def _validate_payment_data(self, payment_data: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
        """Comprehensive input validation with security focus"""
        
        # Required fields validation
        required_fields = ['amount', 'currency', 'user_id', 'merchant_id']
        for field in required_fields:
            if field not in payment_data or not payment_data[field]:
                return False, f"Missing required field: {field}"
        
        # Amount validation (prevent negative amounts, overflow attacks)
        try:
            amount = Decimal(str(payment_data['amount']))
            if amount <= 0:
                return False, "Amount must be positive"
            if amount > Decimal('999999.99'):  # Reasonable max limit
                return False, "Amount exceeds maximum allowed"
        except (TypeError, ValueError):
            return False, "Invalid amount format"
        
        # Currency validation (ISO 4217)
        valid_currencies = {'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY'}
        if payment_data['currency'] not in valid_currencies:
            return False, f"Unsupported currency: {payment_data['currency']}"
        
        # User ID validation (prevent injection attacks)
        user_id = str(payment_data['user_id'])
        if not re.match(r'^[a-zA-Z0-9_-]{1,50}$', user_id):
            return False, "Invalid user_id format"
        
        # Merchant ID validation
        merchant_id = str(payment_data['merchant_id'])
        if not re.match(r'^[a-zA-Z0-9_-]{1,50}$', merchant_id):
            return False, "Invalid merchant_id format"
        
        # Optional card data validation (if present)
        if 'card_number' in payment_data:
            card_number = str(payment_data['card_number']).replace(' ', '').replace('-', '')
            if not re.match(r'^\d{13,19}$', card_number):
                return False, "Invalid card number format"
            
            # Basic Luhn algorithm check
            if not self._luhn_check(card_number):
                return False, "Invalid card number"
        
        if 'cvv' in payment_data:
            cvv = str(payment_data['cvv'])
            if not re.match(r'^\d{3,4}$', cvv):
                return False, "Invalid CVV format"
        
        return True, None
    
    def _luhn_check(self, card_number: str) -> bool:
        """Implement Luhn algorithm for card number validation"""
        def luhn_digit(n):
            return sum(divmod(int(d) * 2, 10)) if n % 2 else int(d)
        
        return sum(luhn_digit(i) for i, d in enumerate(reversed(card_number))) % 10 == 0
    
    def _check_idempotency(self, idempotency_key: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Check if request has been processed before"""
        try:
            response = self.idempotency_table.get_item(
                Key={'idempotency_key': idempotency_key}
            )
            
            if 'Item' in response:
                # Request already processed
                existing_response = json.loads(response['Item']['response_body'])
                return True, existing_response
                
            return False, None
            
        except Exception as e:
            # If idempotency check fails, allow request to proceed
            self.security_manager._log_security_event('IDEMPOTENCY_CHECK_ERROR', {
                'idempotency_key': idempotency_key,
                'error': str(e)
            })
            return False, None
    
    def process_payment(self, event: Dict[str, Any], client_info: Dict[str, Any]) -> Dict[str, Any]:
        """Process payment with enterprise security"""
        try:
            # Parse request body
            try:
                if isinstance(event.get('body'), str):
                    payment_data = json.loads(event['body'])
                else:
                    payment_data = event.get('body', {})
            except json.JSONDecodeError:
                return self._security_response(400, "INVALID_JSON", "Request body must be valid JSON")
            
            # Input validation
            is_valid, error_message = self._validate_payment_data(payment_data)
            if not is_valid:
                self.security_manager._log_security_event('VALIDATION_FAILED', {
                    'client_id': client_info.get('client_id'),
                    'error': error_message,
                    'data': self._mask_sensitive_data(payment_data)
                })
                return self._security_response(400, "VALIDATION_ERROR", error_message)
            
            # Check idempotency
            idempotency_key = event.get('headers', {}).get('Idempotency-Key')
            if idempotency_key:
                is_duplicate, existing_response = self._check_idempotency(idempotency_key)
                if is_duplicate:
                    return existing_response
            
            # Generate transaction ID
            transaction_id = str(uuid.uuid4())
            timestamp = int(time.time())
            
            # Create transaction record (with encrypted sensitive data)
            transaction = {
                'transaction_id': transaction_id,
                'timestamp': timestamp,
                'amount': Decimal(str(payment_data['amount'])),
                'currency': payment_data['currency'],
                'user_id': payment_data['user_id'],
                'merchant_id': payment_data['merchant_id'],
                'client_id': client_info['client_id'],
                'status': 'pending',
                'created_at': timestamp,
                'updated_at': timestamp
            }
            
            # Store transaction
            self.transactions_table.put_item(Item=transaction)
            
            # Store idempotency record if key provided
            response_body = {
                'transaction_id': transaction_id,
                'status': 'pending',
                'amount': float(payment_data['amount']),
                'currency': payment_data['currency'],
                'timestamp': timestamp
            }
            
            if idempotency_key:
                self.idempotency_table.put_item(
                    Item={
                        'idempotency_key': idempotency_key,
                        'transaction_id': transaction_id,
                        'response_body': json.dumps(response_body),
                        'ttl': timestamp + 86400  # 24 hour TTL
                    }
                )
            
            # Log successful payment processing
            self.security_manager._log_security_event('PAYMENT_PROCESSED', {
                'client_id': client_info['client_id'],
                'transaction_id': transaction_id,
                'amount': float(payment_data['amount']),
                'currency': payment_data['currency'],
                'merchant_id': payment_data['merchant_id']
            })
            
            return self._security_response(201, "SUCCESS", "Payment processed successfully", response_body)
            
        except Exception as e:
            # Log security incident
            self.security_manager._log_security_event('PAYMENT_PROCESSING_ERROR', {
                'client_id': client_info.get('client_id'),
                'error': str(e),
                'data': self._mask_sensitive_data(payment_data) if 'payment_data' in locals() else {}
            })
            
            return self._security_response(500, "INTERNAL_ERROR", "Payment processing failed")
    
    def _security_response(self, status_code: int, error_code: str, message: str, data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Generate security-compliant API responses"""
        response_body = {
            'error_code': error_code,
            'message': message,
            'timestamp': int(time.time())
        }
        
        if data:
            response_body.update(data)
        
        return {
            "statusCode": status_code,
            "headers": {
                "Content-Type": "application/json",
                "Cache-Control": "no-store, no-cache, must-revalidate",
                "Pragma": "no-cache",
                "X-Content-Type-Options": "nosniff",
                "X-Frame-Options": "DENY",
                "X-XSS-Protection": "1; mode=block",
                "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
                "Content-Security-Policy": "default-src 'none'"
            },
            "body": json.dumps(response_body)
        }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Secure Lambda handler with enterprise authentication"""
    
    # Security headers check
    if event.get('httpMethod') != 'POST':
        return {
            "statusCode": 405,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "METHOD_NOT_ALLOWED", "message": "Only POST method allowed"})
        }
    
    # Authentication
    is_authenticated, client_info, auth_error = authenticate_request(event)
    if not is_authenticated:
        return auth_error
    
    # Authorization
    is_authorized, auth_error = authorize_request(client_info, 'payments', 'create')
    if not is_authorized:
        return auth_error
    
    # Process payment with security
    processor = SecurePaymentProcessor()
    return processor.process_payment(event, client_info)