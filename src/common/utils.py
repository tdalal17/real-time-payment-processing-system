"""
Common Utilities for Payment System

Shared utility functions used across Lambda functions.

Author: Payment System Team
Version: 1.0.0
"""

import json
import os
import time
import decimal
import boto3
from typing import Dict, Any, Optional
from datetime import datetime


class PaymentSystemUtils:
    """Common utilities for payment system"""
    
    @staticmethod
    def get_dynamodb_resource():
        """Get DynamoDB resource with optional local endpoint support"""
        endpoint_url = os.environ.get('DYNAMODB_ENDPOINT')
        region = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        
        if endpoint_url:
            print(f"[Utils] Connecting to DynamoDB at {endpoint_url}")
            return boto3.resource('dynamodb', region_name=region, endpoint_url=endpoint_url)
        else:
            return boto3.resource('dynamodb', region_name=region)

    @staticmethod
    def generate_api_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
        """Generate standardized API Gateway response"""
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-store',
                'X-Payment-System': 'v1.0',
                'Access-Control-Allow-Origin': '*',  # For CORS
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-API-Key, Idempotency-Key'
            },
            'body': json.dumps(body, default=str)
        }
    
    @staticmethod
    def log_event(component: str, message: str, level: str = 'INFO') -> None:
        """Structured logging for CloudWatch"""
        timestamp = datetime.utcnow().isoformat()
        log_entry = {
            'timestamp': timestamp,
            'component': component,
            'level': level,
            'message': message
        }
        print(json.dumps(log_entry))
    
    @staticmethod
    def validate_currency(currency: str) -> bool:
        """Validate currency code"""
        supported_currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD']
        return currency in supported_currencies
    
    @staticmethod
    def validate_amount(amount_str: str, min_amount: str = '0.01', max_amount: str = '99999.99') -> Optional[str]:
        """Validate monetary amount"""
        try:
            amount = decimal.Decimal(amount_str)
            min_val = decimal.Decimal(min_amount)
            max_val = decimal.Decimal(max_amount)
            
            if amount < min_val:
                return f"Amount must be at least {min_amount}"
            if amount > max_val:
                return f"Amount must not exceed {max_amount}"
            
            # Check for too many decimal places
            if amount.as_tuple().exponent < -2:
                return "Amount cannot have more than 2 decimal places"
            
            return None  # Valid amount
            
        except (decimal.InvalidOperation, ValueError):
            return "Invalid amount format"
    
    @staticmethod
    def mask_sensitive_data(data: str, mask_char: str = '*', visible_chars: int = 4) -> str:
        """Mask sensitive data for logging"""
        if not data or len(data) <= visible_chars:
            return mask_char * len(data) if data else ''
        
        visible_part = data[-visible_chars:]
        masked_part = mask_char * (len(data) - visible_chars)
        return masked_part + visible_part
    
    @staticmethod
    def calculate_processing_fee(amount: str, fee_percentage: float = 0.029) -> str:
        """Calculate processing fee (example: 2.9% + $0.30)"""
        amount_decimal = decimal.Decimal(amount)
        percentage_fee = amount_decimal * decimal.Decimal(str(fee_percentage))
        fixed_fee = decimal.Decimal('0.30')
        total_fee = percentage_fee + fixed_fee
        
        # Round to 2 decimal places
        return str(total_fee.quantize(decimal.Decimal('0.01')))
    
    @staticmethod
    def generate_transaction_reference(transaction_id: str) -> str:
        """Generate human-readable transaction reference"""
        # Take first 8 chars of UUID and add timestamp suffix
        short_id = transaction_id.replace('-', '')[:8].upper()
        timestamp_suffix = str(int(time.time()))[-4:]  # Last 4 digits of timestamp
        return f"TXN-{short_id}-{timestamp_suffix}"
    
    @staticmethod
    def parse_json_body(event: Dict[str, Any]) -> Dict[str, Any]:
        """Safely parse JSON body from API Gateway event"""
        try:
            body = event.get('body')
            if isinstance(body, str):
                return json.loads(body)
            elif isinstance(body, dict):
                return body
            else:
                return {}
        except (json.JSONDecodeError, TypeError):
            raise ValueError("Invalid JSON in request body")


class FraudDetector:
    """Simple fraud detection utilities"""
    
    @staticmethod
    def calculate_risk_score(transaction_data: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate basic fraud risk score"""
        
        score = 0
        risk_factors = []
        
        amount = decimal.Decimal(str(transaction_data.get('amount', '0')))
        
        # High amount transactions
        if amount > decimal.Decimal('1000'):
            score += 30
            risk_factors.append('high_amount')
        
        # Very high amount transactions
        if amount > decimal.Decimal('5000'):
            score += 50
            risk_factors.append('very_high_amount')
        
        # Round amounts (potential testing)
        if amount % 100 == 0 and amount > decimal.Decimal('100'):
            score += 15
            risk_factors.append('round_amount')
        
        # Suspicious patterns in user_id
        user_id = transaction_data.get('user_id', '')
        if any(word in user_id.lower() for word in ['test', 'demo', 'fake', 'temp']):
            score += 25
            risk_factors.append('test_user')
        
        # Determine risk level
        if score >= 80:
            risk_level = 'HIGH'
            decision = 'DECLINE'
        elif score >= 50:
            risk_level = 'MEDIUM'
            decision = 'REVIEW'
        else:
            risk_level = 'LOW'
            decision = 'APPROVE'
        
        return {
            'fraud_score': score,
            'risk_level': risk_level,
            'decision': decision,
            'risk_factors': risk_factors,
            'checked_at': datetime.utcnow().isoformat()
        }


class ValidationRules:
    """Common validation rules"""
    
    @staticmethod
    def validate_user_id(user_id: str) -> Optional[str]:
        """Validate user ID format"""
        if not user_id or not user_id.strip():
            return "User ID cannot be empty"
        
        if len(user_id) < 3:
            return "User ID must be at least 3 characters"
        
        if len(user_id) > 50:
            return "User ID cannot exceed 50 characters"
        
        return None
    
    @staticmethod
    def validate_merchant_id(merchant_id: str) -> Optional[str]:
        """Validate merchant ID format"""
        if not merchant_id or not merchant_id.strip():
            return "Merchant ID cannot be empty"
        
        if len(merchant_id) < 3:
            return "Merchant ID must be at least 3 characters"
        
        if len(merchant_id) > 50:
            return "Merchant ID cannot exceed 50 characters"
        
        return None