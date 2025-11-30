"""
Payment System Authorization Lambda

This Lambda function handles API key-based authorization for the payment system.
It validates API keys and returns appropriate IAM policies for API Gateway.

Author: Payment System Team
Version: 1.0.0
"""

import json
import hashlib
import time
from typing import Dict, Any, Optional


class PaymentAuthorizer:
    """Handles API key validation and policy generation for payment system"""
    
    # Valid API keys with their permissions (loaded from environment variables or Secrets Manager in production)
    # For this demo, we use environment variables with safe defaults
    
    def __init__(self):
        """Initialize the authorizer"""
        self.logger_enabled = True
        self._load_api_keys()
        
    def _load_api_keys(self):
        """Load API keys from environment variables"""
        import os
        
        # Default placeholders for demo purposes if env vars not set
        admin_key = os.environ.get('ADMIN_API_KEY', 'pk_admin_demo_key_12345')
        merchant_key = os.environ.get('MERCHANT_API_KEY', 'pk_merchant_demo_key_67890')
        analytics_key = os.environ.get('ANALYTICS_API_KEY', 'pk_analytics_demo_key_54321')
        
        self.VALID_API_KEYS = {
            # Admin API key - full access
            admin_key: {
                'permissions': ['payments:create', 'payments:read', 'payments:refund'],
                'client_id': 'admin_client',
                'rate_limit': 1000
            },
            # Merchant API key - limited access
            merchant_key: {
                'permissions': ['payments:create', 'payments:read'],
                'client_id': 'merchant_client',
                'rate_limit': 100
            },
            # Analytics API key - read only
            analytics_key: {
                'permissions': ['payments:read'],
                'client_id': 'analytics_client',
                'rate_limit': 500
            }
        }
    
    def _log(self, message: str) -> None:
        """Log message if logging is enabled"""
        if self.logger_enabled:
            print(f"[PaymentAuthorizer] {message}")
    
    def _extract_api_key(self, event: Dict[str, Any]) -> Optional[str]:
        """Extract API key from the request headers"""
        headers = event.get('headers', {})
        
        # Case-insensitive header lookup
        for key, value in headers.items():
            if key.lower() == 'x-api-key':
                return value
        
        return None
    
    def _validate_api_key(self, api_key: str) -> Optional[Dict[str, Any]]:
        """Validate API key and return associated metadata"""
        if not api_key:
            return None
            
        return self.VALID_API_KEYS.get(api_key)
    
    def _generate_policy(self, method_arn: str, effect: str = 'Allow') -> Dict[str, Any]:
        """Generate IAM policy for API Gateway"""
        return {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': method_arn
                }
            ]
        }
    
    def _extract_method_arn(self, event: Dict[str, Any]) -> str:
        """Extract method ARN from the event"""
        method_arn = event.get('methodArn')
        
        if not method_arn:
            # Try alternative locations
            request_context = event.get('requestContext', {})
            method_arn = request_context.get('methodArn')
        
        return method_arn or '*'
    
    def authorize(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Main authorization logic"""
        try:
            self._log("Processing authorization request")
            
            # Extract API key
            api_key = self._extract_api_key(event)
            if not api_key:
                self._log("No API key provided")
                return self._deny_access("Missing API key")
            
            # Validate API key
            key_metadata = self._validate_api_key(api_key)
            if not key_metadata:
                self._log("Invalid API key provided")
                return self._deny_access("Invalid API key")
            
            # Extract method ARN
            method_arn = self._extract_method_arn(event)
            
            self._log("Authorizing client")
            
            # Generate allow policy
            policy = self._generate_policy(method_arn, 'Allow')
            
            return {
                'principalId': key_metadata['client_id'],
                'policyDocument': policy,
                'context': {
                    'client_id': key_metadata['client_id'],
                    'permissions': ','.join(key_metadata['permissions']),
                    'rate_limit': str(key_metadata['rate_limit']),
                    'timestamp': str(int(time.time()))
                }
            }
            
        except Exception as e:
            self._log(f"Authorization error: {str(e)}")
            return self._deny_access(f"Authorization error: {str(e)}")
    
    def _deny_access(self, reason: str) -> Dict[str, Any]:
        """Generate deny policy"""
        return {
            'principalId': 'unauthorized',
            'policyDocument': self._generate_policy('*', 'Deny'),
            'context': {
                'reason': reason,
                'timestamp': str(int(time.time()))
            }
        }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for API Gateway custom authorizer
    
    Args:
        event: API Gateway authorizer event
        context: Lambda context
    
    Returns:
        Dict containing authorization policy
    """
    authorizer = PaymentAuthorizer()
    return authorizer.authorize(event)