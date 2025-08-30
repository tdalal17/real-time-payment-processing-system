"""
Enterprise Custom Authorizer for API Gateway
Advanced authentication and authorization with threat detection
"""

import json
import time
import hashlib
import re
from typing import Dict, Any, Optional, Tuple, List
import boto3
from decimal import Decimal

class AdvancedAuthorizer:
    """Enterprise-grade API Gateway custom authorizer"""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.api_keys_table = self.dynamodb.Table('payment-system-api-keys')
        self.audit_table = self.dynamodb.Table('payment-system-audit-log')
        self.threat_intel_table = self.dynamodb.Table('payment-system-threat-intel')
        
        # Threat detection thresholds
        self.suspicious_patterns = {
            'rapid_requests': 10,  # More than 10 requests in 1 minute
            'geographic_anomaly': 3,  # Requests from 3+ countries in 1 hour
            'user_agent_rotation': 5,  # More than 5 different user agents
            'api_key_sharing': 2,  # Same key from 2+ different IPs simultaneously
        }
    
    def authorize_request(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Main authorization logic with advanced threat detection"""
        
        # Extract request context - REQUEST authorizer format
        method_arn = event['methodArn']
        headers = event.get('headers', {})
        
        # For REQUEST authorizers, identity info is in requestContext
        request_context = event.get('requestContext', {})
        identity = request_context.get('identity', {})
        source_ip = identity.get('sourceIp', '0.0.0.0')
        user_agent = identity.get('userAgent', 'Unknown')
        
        # Extract API key
        api_key = headers.get('X-API-Key') or headers.get('x-api-key')
        
        # Step 1: Basic API key validation
        is_valid, client_info, error_reason = self._validate_api_key(api_key, event)
        if not is_valid:
            self._log_auth_failure(source_ip, user_agent, error_reason)
            return self._generate_deny_policy(method_arn, error_reason)
        
        # Step 2: Advanced threat detection
        threat_score, threat_reasons = self._calculate_threat_score(client_info, event)
        if threat_score > 0.7:  # High threat score
            self._log_security_threat(client_info, event, threat_score, threat_reasons)
            return self._generate_deny_policy(method_arn, "HIGH_THREAT_SCORE")
        
        # Step 3: Business logic authorization
        is_authorized, auth_error = self._check_business_authorization(client_info, event)
        if not is_authorized:
            return self._generate_deny_policy(method_arn, auth_error)
        
        # Step 4: Rate limiting validation
        rate_limit_ok, rate_error = self._validate_rate_limits(client_info, event)
        if not rate_limit_ok:
            return self._generate_deny_policy(method_arn, rate_error)
        
        # Step 5: Generate allow policy with context
        return self._generate_allow_policy(method_arn, client_info, threat_score)
    
    def _validate_api_key(self, api_key: str, event: Dict[str, Any]) -> Tuple[bool, Optional[Dict], str]:
        """Advanced API key validation with pattern analysis"""
        
        if not api_key:
            return False, None, "MISSING_API_KEY"
        
        # Validate API key format
        if not re.match(r'^pk_[a-z]+_[A-Za-z0-9_-]{43}$', api_key):
            return False, None, "INVALID_API_KEY_FORMAT"
        
        try:
            # Hash for lookup
            key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            
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
        """Calculate threat score based on behavioral analysis"""
        
        threat_score = 0.0
        threat_reasons = []
        
        # Extract identity info safely for REQUEST authorizer
        request_context = event.get('requestContext', {})
        identity = request_context.get('identity', {})
        source_ip = identity.get('sourceIp', '0.0.0.0')
        user_agent = identity.get('userAgent', 'Unknown')
        client_id = client_info['client_id']
        
        # Check for rapid requests
        recent_requests = self._get_recent_requests(client_id, 60)  # Last minute
        if recent_requests > self.suspicious_patterns['rapid_requests']:
            threat_score += 0.3
            threat_reasons.append("RAPID_REQUESTS")
        
        # Check for geographic anomalies
        unique_countries = self._get_unique_countries_last_hour(client_id)
        if unique_countries > self.suspicious_patterns['geographic_anomaly']:
            threat_score += 0.4
            threat_reasons.append("GEOGRAPHIC_ANOMALY")
        
        # Check user agent rotation
        unique_user_agents = self._get_unique_user_agents_last_hour(client_id)
        if unique_user_agents > self.suspicious_patterns['user_agent_rotation']:
            threat_score += 0.2
            threat_reasons.append("USER_AGENT_ROTATION")
        
        # Check for API key sharing
        concurrent_ips = self._get_concurrent_ips(client_id)
        if concurrent_ips > self.suspicious_patterns['api_key_sharing']:
            threat_score += 0.5
            threat_reasons.append("API_KEY_SHARING")
        
        # Check against known bad IPs
        if self._is_known_bad_ip(source_ip):
            threat_score += 0.8
            threat_reasons.append("KNOWN_BAD_IP")
        
        # Check for suspicious user agent patterns
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
        """Advanced rate limiting with burst detection"""
        
        client_id = client_info['client_id']
        current_time = int(time.time())
        
        # Get rate limit configuration
        rate_limit = int(client_info.get('rate_limit_per_minute', 100))
        
        # Check burst pattern (more than 50% of limit in 10 seconds)
        recent_requests_10s = self._get_recent_requests(client_id, 10)
        burst_threshold = rate_limit * 0.5
        
        if recent_requests_10s > burst_threshold:
            return False, "BURST_RATE_EXCEEDED"
        
        # Check standard rate limit
        recent_requests_60s = self._get_recent_requests(client_id, 60)
        if recent_requests_60s >= rate_limit:
            return False, "RATE_LIMIT_EXCEEDED"
        
        return True, "RATE_LIMIT_OK"
    
    def _get_recent_requests(self, client_id: str, seconds: int) -> int:
        """Get number of requests in the last N seconds"""
        # Implementation would query audit logs or rate limiting table
        return 0  # Placeholder
    
    def _get_unique_countries_last_hour(self, client_id: str) -> int:
        """Get number of unique countries in the last hour"""
        # Implementation would analyze IP geolocation data
        return 1  # Placeholder
    
    def _get_unique_user_agents_last_hour(self, client_id: str) -> int:
        """Get number of unique user agents in the last hour"""
        # Implementation would analyze user agent patterns
        return 1  # Placeholder
    
    def _get_concurrent_ips(self, client_id: str) -> int:
        """Get number of concurrent IP addresses using the same API key"""
        # Implementation would check active sessions
        return 1  # Placeholder
    
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
        # DEBUG: Log the entire event structure
        print("=== REQUEST AUTHORIZER DEBUG ===")
        print(f"Full Event: {json.dumps(event, indent=2, default=str)}")
        print(f"Event Keys: {list(event.keys())}")
        if 'requestContext' in event:
            print(f"RequestContext: {json.dumps(event['requestContext'], indent=2, default=str)}")
        print("================================")
        
        authorizer = AdvancedAuthorizer()
        return authorizer.authorize_request(event)
    
    except Exception as e:
        # On error, deny access and log the issue
        print(f"Authorizer error: {e}")
        print(f"Event that caused error: {json.dumps(event, indent=2, default=str)}")
        
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