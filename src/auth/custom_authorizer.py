# Custom authorizer for API Gateway

import json
import time
import hashlib
import re
import os
import sys
from typing import Dict, Any, Optional, Tuple, List
import boto3
from decimal import Decimal

# Ensure common modules can be imported
try:
    from common.utils import PaymentSystemUtils
except ImportError:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))
    from common.utils import PaymentSystemUtils

class AdvancedAuthorizer:
    # PBKDF2 parameters for API key hashing
    API_KEY_HASH_SALT = b'your_unique_server_salt_here'    # Replace with secure, random value from config/env
    API_KEY_HASH_ITERATIONS = 100_000                      # Adjust iteration count per your security requirements

    def __init__(self):
        self.dynamodb = PaymentSystemUtils.get_dynamodb_resource()
        self.api_keys_table = self.dynamodb.Table('payment-system-api-keys')
        self.audit_table = self.dynamodb.Table('payment-system-audit-log')
        self.threat_intel_table = self.dynamodb.Table('payment-system-threat-intel')
    
    def _hash_api_key_pbkdf2(self, api_key: str) -> str:
        """Generate API key hash using PBKDF2-HMAC-SHA256."""
        dk = hashlib.pbkdf2_hmac(
            'sha256',
            api_key.encode(),
            self.API_KEY_HASH_SALT,
            self.API_KEY_HASH_ITERATIONS
        )
        return dk.hex()
    def authorize_request(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Authorize API request based on API key and permissions"""

        # Extract request context
        method_arn = event['methodArn']
        headers = event.get('headers', {})
        
        # For REQUEST authorizers, identity info is in requestContext
        request_context = event.get('requestContext', {})
        identity = request_context.get('identity', {})
        source_ip = identity.get('sourceIp', '0.0.0.0')
        user_agent = identity.get('userAgent', 'Unknown')
        
        # Extract and validate API key
        api_key = headers.get('X-API-Key') or headers.get('x-api-key')

        is_valid, client_info, error_reason = self._validate_api_key(api_key, event)
        if not is_valid:
            self._log_auth_failure(source_ip, user_agent, error_reason)
            return self._generate_deny_policy(method_arn, error_reason)

        # Check for suspicious activity
        threat_score, threat_reasons = self._calculate_threat_score(client_info, event)
        if threat_score > 0.7:
            self._log_security_threat(client_info, event, threat_score, threat_reasons)
            return self._generate_deny_policy(method_arn, "HIGH_THREAT_SCORE")

        # Verify permissions
        is_authorized, auth_error = self._check_business_authorization(client_info, event)
        if not is_authorized:
            return self._generate_deny_policy(method_arn, auth_error)

        # Check rate limits
        rate_limit_ok, rate_error = self._validate_rate_limits(client_info, event)
        if not rate_limit_ok:
            return self._generate_deny_policy(method_arn, rate_error)

        return self._generate_allow_policy(method_arn, client_info, threat_score)
    
    def _validate_api_key(self, api_key: str, event: Dict[str, Any]) -> Tuple[bool, Optional[Dict], str]:
        """Validate API key format and lookup in DynamoDB"""
        
        if not api_key:
            return False, None, "MISSING_API_KEY"
        
        # Validate API key format
        if not re.match(r'^pk_[a-z]+_[A-Za-z0-9_-]{43}$', api_key):
            return False, None, "INVALID_API_KEY_FORMAT"
        
        try:
            # Hash for lookup
            key_hash = self._hash_api_key_pbkdf2(api_key)
            
            response = self.api_keys_table.get_item(Key={'key_hash': key_hash})
            
            if 'Item' not in response:
                return False, None, "API_KEY_NOT_FOUND"
            
            client_info = response['Item']
            
            # Check if key is active
            if not client_info.get('is_active', False):
                return False, None, "API_KEY_INACTIVE"
            
            # Check expiration
            if 'expires_at' in client_info:
                if int(time.time()) > int(client_info['expires_at']):
                    return False, None, "API_KEY_EXPIRED"
            
            # Update usage statistics
            self._update_key_usage(key_hash, event)
            
            return True, client_info, "VALID"
            
        except Exception as e:
            return False, None, f"VALIDATION_ERROR: {str(e)}"
    
    def _calculate_threat_score(self, client_info: Dict[str, Any], event: Dict[str, Any]) -> Tuple[float, List[str]]:
        # Basic threat detection - TODO: add rate limiting and geolocation checks
        threat_score = 0.0
        threat_reasons = []

        request_context = event.get('requestContext', {})
        identity = request_context.get('identity', {})
        source_ip = identity.get('sourceIp', '0.0.0.0')
        user_agent = identity.get('userAgent', 'Unknown')

        # Check against known bad IPs
        if self._is_known_bad_ip(source_ip):
            threat_score += 0.8
            threat_reasons.append("KNOWN_BAD_IP")

        # Check for suspicious user agent patterns (bots, scrapers, etc)
        if self._is_suspicious_user_agent(user_agent):
            threat_score += 0.3
            threat_reasons.append("SUSPICIOUS_USER_AGENT")

        return min(threat_score, 1.0), threat_reasons
    
    def _check_business_authorization(self, client_info: Dict[str, Any], event: Dict[str, Any]) -> Tuple[bool, str]:
        """Check business-specific authorization rules"""
        
        # Extract request info safely for REQUEST authorizer
        request_context = event.get('requestContext', {})
        resource_path = request_context.get('resourcePath', '')
        http_method = request_context.get('httpMethod', 'GET')
        
        # Map API paths to permissions
        permission_map = {
            ('/payments', 'POST'): 'payments:create',
            ('/payments/{transaction_id}', 'GET'): 'payments:read',
            ('/payments', 'GET'): 'transactions:list',
            ('/payments/{transaction_id}/refund', 'POST'): 'payments:refund'
        }
        
        required_permission = permission_map.get((resource_path, http_method))
        if not required_permission:
            return False, "UNKNOWN_ENDPOINT"
        
        permissions = client_info.get('permissions', [])
        
        # Check specific permission
        if required_permission in permissions or '*:*' in permissions:
            return True, "AUTHORIZED"
        
        # Check wildcard permissions
        resource, action = required_permission.split(':')
        if f"{resource}:*" in permissions or f"*:{action}" in permissions:
            return True, "AUTHORIZED"
        
        return False, "INSUFFICIENT_PERMISSIONS"
    
    def _validate_rate_limits(self, client_info: Dict[str, Any], event: Dict[str, Any]) -> Tuple[bool, str]:
        # TODO: implement actual rate limiting using DynamoDB or ElastiCache
        # For now, rely on API Gateway's built-in rate limiting
        return True, "RATE_LIMIT_OK"

    def _is_known_bad_ip(self, ip_address: str) -> bool:
        """Check if IP is in threat intelligence database"""
        try:
            response = self.threat_intel_table.get_item(
                Key={'ip_address': ip_address}
            )
            return 'Item' in response and response['Item'].get('is_malicious', False)
        except Exception:
            return False
    
    def _is_suspicious_user_agent(self, user_agent: str) -> bool:
        """Check for suspicious user agent patterns"""
        suspicious_patterns = [
            r'.*bot.*', r'.*crawler.*', r'.*spider.*', r'.*scraper.*',
            r'.*scanner.*', r'.*curl.*', r'.*wget.*', r'.*python.*',
            r'.*java.*', r'.*go-http.*', r'.*okhttp.*'
        ]
        
        user_agent_lower = user_agent.lower()
        for pattern in suspicious_patterns:
            if re.match(pattern, user_agent_lower):
                return True
        
        return False
    
    def _update_key_usage(self, key_hash: str, event: Dict[str, Any]):
        """Update API key usage statistics"""
        try:
            self.api_keys_table.update_item(
                Key={'key_hash': key_hash},
                UpdateExpression='SET last_used = :timestamp, usage_count = usage_count + :inc',
                ExpressionAttributeValues={
                    ':timestamp': Decimal(str(int(time.time()))),
                    ':inc': Decimal('1')
                }
            )
        except Exception:
            pass  # Don't fail auth if usage update fails
    
    def _log_auth_failure(self, source_ip: str, user_agent: str, reason: str):
        """Log authentication failure for security analysis"""
        try:
            self.audit_table.put_item(
                Item={
                    'event_id': f"auth_fail_{int(time.time() * 1000)}",
                    'timestamp': Decimal(str(int(time.time()))),
                    'event_type': 'AUTHENTICATION_FAILED',
                    'details': json.dumps({
                        'source_ip': source_ip,
                        'user_agent': user_agent,
                        'reason': reason
                    }),
                    'ttl': int(time.time()) + (30 * 24 * 3600)  # 30 days
                }
            )
        except Exception:
            pass
    
    def _log_security_threat(self, client_info: Dict[str, Any], event: Dict[str, Any], 
                           threat_score: float, threat_reasons: List[str]):
        """Log security threat for investigation"""
        try:
            self.audit_table.put_item(
                Item={
                    'event_id': f"threat_{int(time.time() * 1000)}",
                    'timestamp': Decimal(str(int(time.time()))),
                    'event_type': 'SECURITY_THREAT_DETECTED',
                    'details': json.dumps({
                        'client_id': client_info['client_id'],
                        'threat_score': threat_score,
                        'threat_reasons': threat_reasons,
                        'source_ip': event.get('requestContext', {}).get('identity', {}).get('sourceIp', '0.0.0.0'),
                        'user_agent': event.get('requestContext', {}).get('identity', {}).get('userAgent', 'Unknown')
                    }),
                    'ttl': int(time.time()) + (365 * 24 * 3600)  # 1 year
                }
            )
        except Exception:
            pass
    
    def _generate_allow_policy(self, method_arn: str, client_info: Dict[str, Any], 
                              threat_score: float) -> Dict[str, Any]:
        """Generate IAM policy allowing access with context"""
        
        return {
            'principalId': client_info['client_id'],
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Effect': 'Allow',
                        'Resource': method_arn
                    }
                ]
            },
            'context': {
                'client_id': client_info['client_id'],
                'client_name': client_info['client_name'],
                'permissions': ','.join(client_info.get('permissions', [])),
                'threat_score': str(threat_score),
                'rate_limit': str(client_info.get('rate_limit_per_minute', 100)),
                'auth_time': str(int(time.time()))
            }
        }
    
    def _generate_deny_policy(self, method_arn: str, reason: str) -> Dict[str, Any]:
        """Generate IAM policy denying access"""
        
        return {
            'principalId': 'unauthorized',
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Effect': 'Deny',
                        'Resource': method_arn
                    }
                ]
            },
            'context': {
                'error': reason,
                'timestamp': str(int(time.time()))
            }
        }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for custom authorization"""

    try:
        authorizer = AdvancedAuthorizer()
        return authorizer.authorize_request(event)

    except Exception as e:
        print(f"Authorizer error: {e}")

        return {
            'principalId': 'error',
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Effect': 'Deny',
                        'Resource': event.get('methodArn', '*')
                    }
                ]
            },
            'context': {
                'error': 'AUTHORIZER_ERROR',
                'timestamp': str(int(time.time()))
            }
        }