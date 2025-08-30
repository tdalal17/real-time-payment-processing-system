import hashlib
import hmac
import json
import time
from typing import Dict, Any, Optional, Tuple
import boto3
from decimal import Decimal

class SecurityManager:
    """Enterprise security layer for payment processing system"""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.api_keys_table = self.dynamodb.Table('payment-system-api-keys')
        self.audit_table = self.dynamodb.Table('payment-system-audit-log')
        
    def validate_api_key(self, api_key: str, event: Dict[str, Any]) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """
        Validate API key and return client information
        Returns: (is_valid, client_info)
        """
        if not api_key or not api_key.startswith('pk_'):
            return False, None
            
        try:
            # Hash the API key for secure lookup
            key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            
            response = self.api_keys_table.get_item(
                Key={'key_hash': key_hash}
            )
            
            if 'Item' not in response:
                self._log_security_event('API_KEY_INVALID', {
                    'ip': self._get_client_ip(event),
                    'user_agent': event.get('headers', {}).get('User-Agent'),
                    'attempted_key': api_key[:8] + '...'  # Log only prefix
                })
                return False, None
            
            client_info = response['Item']
            
            # Check if API key is active
            if not client_info.get('is_active', False):
                self._log_security_event('API_KEY_INACTIVE', {
                    'client_id': client_info.get('client_id'),
                    'ip': self._get_client_ip(event)
                })
                return False, None
            
            # Check rate limits
            if not self._check_rate_limit(client_info['client_id'], event):
                return False, None
                
            # Log successful authentication
            self._log_security_event('API_KEY_VALID', {
                'client_id': client_info.get('client_id'),
                'ip': self._get_client_ip(event)
            })
            
            return True, client_info
            
        except Exception as e:
            self._log_security_event('API_KEY_VALIDATION_ERROR', {
                'error': str(e),
                'ip': self._get_client_ip(event)
            })
            return False, None
    
    def validate_permissions(self, client_info: Dict[str, Any], resource: str, action: str) -> bool:
        """
        Check if client has permission for specific resource and action
        """
        permissions = client_info.get('permissions', [])
        
        # Check for specific permission
        required_permission = f"{resource}:{action}"
        if required_permission in permissions:
            return True
            
        # Check for wildcard permissions
        wildcard_resource = f"{resource}:*"
        wildcard_action = f"*:{action}"
        
        if wildcard_resource in permissions or wildcard_action in permissions or "*:*" in permissions:
            return True
            
        self._log_security_event('PERMISSION_DENIED', {
            'client_id': client_info.get('client_id'),
            'resource': resource,
            'action': action,
            'permissions': permissions
        })
        
        return False
    
    def _check_rate_limit(self, client_id: str, event: Dict[str, Any]) -> bool:
        """
        Implement token bucket rate limiting
        """
        try:
            current_time = int(time.time())
            rate_limit_key = f"rate_limit:{client_id}"
            
            # Get current rate limit state
            response = self.dynamodb.Table('payment-system-rate-limits').get_item(
                Key={'client_id': rate_limit_key}
            )
            
            if 'Item' not in response:
                # First request - initialize bucket
                self.dynamodb.Table('payment-system-rate-limits').put_item(
                    Item={
                        'client_id': rate_limit_key,
                        'tokens': Decimal('99'),  # 100 requests per minute - 1
                        'last_refill': Decimal(str(current_time)),
                        'ttl': current_time + 3600  # Cleanup after 1 hour
                    }
                )
                return True
            
            bucket = response['Item']
            time_passed = current_time - float(bucket['last_refill'])
            
            # Refill tokens (100 tokens per minute = 1.67 tokens per second)
            tokens_to_add = min(100, time_passed * 1.67)
            current_tokens = float(bucket['tokens']) + tokens_to_add
            
            if current_tokens < 1:
                self._log_security_event('RATE_LIMIT_EXCEEDED', {
                    'client_id': client_id,
                    'ip': self._get_client_ip(event),
                    'current_tokens': current_tokens
                })
                return False
            
            # Update bucket
            self.dynamodb.Table('payment-system-rate-limits').put_item(
                Item={
                    'client_id': rate_limit_key,
                    'tokens': Decimal(str(current_tokens - 1)),
                    'last_refill': Decimal(str(current_time)),
                    'ttl': current_time + 3600
                }
            )
            
            return True
            
        except Exception as e:
            # In case of error, allow request but log the issue
            self._log_security_event('RATE_LIMIT_ERROR', {
                'client_id': client_id,
                'error': str(e)
            })
            return True
    
    def _get_client_ip(self, event: Dict[str, Any]) -> str:
        """Extract client IP from event"""
        headers = event.get('headers', {})
        
        # Check for load balancer headers first
        forwarded_for = headers.get('X-Forwarded-For', '')
        if forwarded_for:
            return forwarded_for.split(',')[0].strip()
            
        return event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'unknown')
    
    def _log_security_event(self, event_type: str, details: Dict[str, Any]):
        """Log security events to audit table"""
        try:
            self.audit_table.put_item(
                Item={
                    'event_id': f"{event_type}_{int(time.time() * 1000)}",
                    'timestamp': Decimal(str(int(time.time()))),
                    'event_type': event_type,
                    'details': json.dumps(details),
                    'ttl': int(time.time()) + (365 * 24 * 3600)  # Keep for 1 year
                }
            )
        except Exception as e:
            # Don't fail the main request if audit logging fails
            print(f"Audit logging failed: {e}")

def authenticate_request(event: Dict[str, Any]) -> Tuple[bool, Optional[Dict[str, Any]], Dict[str, Any]]:
    """
    Main authentication function for Lambda handlers
    Returns: (is_authenticated, client_info, error_response)
    """
    security_manager = SecurityManager()
    
    # Extract API key from headers
    headers = event.get('headers', {})
    api_key = headers.get('X-API-Key') or headers.get('x-api-key')
    
    if not api_key:
        return False, None, {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "error": "AUTHENTICATION_REQUIRED",
                "message": "API key required. Include X-API-Key header."
            })
        }
    
    # Validate API key
    is_valid, client_info = security_manager.validate_api_key(api_key, event)
    
    if not is_valid:
        return False, None, {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "error": "AUTHENTICATION_FAILED",
                "message": "Invalid or inactive API key."
            })
        }
    
    return True, client_info, {}

def authorize_request(client_info: Dict[str, Any], resource: str, action: str) -> Tuple[bool, Dict[str, Any]]:
    """
    Check authorization for specific resource and action
    Returns: (is_authorized, error_response)
    """
    security_manager = SecurityManager()
    
    if not security_manager.validate_permissions(client_info, resource, action):
        return False, {
            "statusCode": 403,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "error": "AUTHORIZATION_FAILED",
                "message": f"Insufficient permissions for {resource}:{action}"
            })
        }
    
    return True, {}