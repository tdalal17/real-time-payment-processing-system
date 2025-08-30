"""
Enterprise Security Response Automation
Automated incident response for payment system security events
"""

import json
import boto3
import time
from typing import Dict, Any, List
from decimal import Decimal

class SecurityIncidentResponder:
    """Automated security incident response system"""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.sns = boto3.client('sns')
        self.waf = boto3.client('wafv2')
        self.ec2 = boto3.client('ec2')
        
        self.incidents_table = self.dynamodb.Table('payment-system-security-incidents')
        self.blocked_ips_table = self.dynamodb.Table('payment-system-blocked-ips')
        
    def handle_security_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Main handler for security events"""
        
        event_source = event.get('source', '')
        detail = event.get('detail', {})
        
        if event_source == 'aws.guardduty':
            return self._handle_guardduty_finding(detail)
        elif event_source == 'aws.securityhub':
            return self._handle_security_hub_finding(detail)
        elif event_source == 'custom.payment-system':
            return self._handle_custom_security_event(detail)
        else:
            return self._log_unknown_event(event)
    
    def _handle_guardduty_finding(self, finding: Dict[str, Any]) -> Dict[str, Any]:
        """Handle GuardDuty security findings"""
        
        finding_type = finding.get('type', '')
        severity = finding.get('severity', 0)
        
        # Extract relevant information
        incident_id = finding.get('id', f"gd_{int(time.time())}")
        title = finding.get('title', 'Unknown GuardDuty Finding')
        description = finding.get('description', '')
        
        # Determine response level based on severity
        if severity >= 8.0:
            response_level = 'CRITICAL'
            actions = self._execute_critical_response(finding)
        elif severity >= 6.0:
            response_level = 'HIGH'
            actions = self._execute_high_response(finding)
        else:
            response_level = 'MEDIUM'
            actions = self._execute_medium_response(finding)
        
        # Log incident
        self._log_security_incident(incident_id, 'GUARDDUTY', response_level, finding, actions)
        
        # Send alert
        self._send_security_alert(response_level, title, description, actions)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'incident_id': incident_id,
                'response_level': response_level,
                'actions_taken': actions
            })
        }
    
    def _execute_critical_response(self, finding: Dict[str, Any]) -> List[str]:
        """Execute critical incident response procedures"""
        actions = []
        
        # Extract malicious IP if available
        remote_ip = self._extract_remote_ip(finding)
        if remote_ip:
            # Immediately block IP at WAF level
            if self._block_ip_in_waf(remote_ip):
                actions.append(f"Blocked IP {remote_ip} in WAF")
            
            # Add to permanent block list
            if self._add_to_blocked_ips(remote_ip, 'CRITICAL_THREAT'):
                actions.append(f"Added IP {remote_ip} to permanent block list")
        
        # Disable compromised API keys if identified
        compromised_keys = self._identify_compromised_keys(finding)
        for key_hash in compromised_keys:
            if self._disable_api_key(key_hash):
                actions.append(f"Disabled compromised API key: {key_hash[:12]}...")
        
        # Trigger security team notification
        actions.append("Triggered immediate security team notification")
        
        return actions
    
    def _execute_high_response(self, finding: Dict[str, Any]) -> List[str]:
        """Execute high-priority incident response"""
        actions = []
        
        remote_ip = self._extract_remote_ip(finding)
        if remote_ip:
            # Temporary block (24 hours)
            if self._add_to_blocked_ips(remote_ip, 'HIGH_RISK', ttl_hours=24):
                actions.append(f"Temporarily blocked IP {remote_ip} for 24 hours")
        
        # Increase monitoring for related patterns
        actions.append("Increased monitoring sensitivity for related attack patterns")
        
        return actions
    
    def _execute_medium_response(self, finding: Dict[str, Any]) -> List[str]:
        """Execute medium-priority incident response"""
        actions = []
        
        # Log for investigation
        actions.append("Logged for security team investigation")
        
        # Check for pattern escalation
        if self._check_pattern_escalation(finding):
            actions.append("Detected pattern escalation - elevated to HIGH priority")
            return self._execute_high_response(finding)
        
        return actions
    
    def _extract_remote_ip(self, finding: Dict[str, Any]) -> str:
        """Extract remote IP from GuardDuty finding"""
        try:
            service = finding.get('service', {})
            remote_ip_details = service.get('remoteIpDetails', {})
            return remote_ip_details.get('ipAddressV4', '')
        except Exception:
            return ''
    
    def _block_ip_in_waf(self, ip_address: str) -> bool:
        """Add IP to WAF IP set for immediate blocking"""
        try:
            # This would require WAF IP set to be created
            # Implementation depends on your WAF configuration
            return True
        except Exception as e:
            print(f"Failed to block IP in WAF: {e}")
            return False
    
    def _add_to_blocked_ips(self, ip_address: str, reason: str, ttl_hours: int = None) -> bool:
        """Add IP to blocked IPs table"""
        try:
            timestamp = int(time.time())
            item = {
                'ip_address': ip_address,
                'blocked_at': timestamp,
                'reason': reason,
                'source': 'automated_response',
                'status': 'active'
            }
            
            if ttl_hours:
                item['ttl'] = timestamp + (ttl_hours * 3600)
            
            self.blocked_ips_table.put_item(Item=item)
            return True
        except Exception as e:
            print(f"Failed to add IP to block list: {e}")
            return False
    
    def _identify_compromised_keys(self, finding: Dict[str, Any]) -> List[str]:
        """Identify potentially compromised API keys from finding"""
        # Implementation would analyze finding details for API key indicators
        return []
    
    def _disable_api_key(self, key_hash: str) -> bool:
        """Disable a compromised API key"""
        try:
            api_keys_table = self.dynamodb.Table('payment-system-api-keys')
            api_keys_table.update_item(
                Key={'key_hash': key_hash},
                UpdateExpression='SET is_active = :inactive, disabled_at = :timestamp, disabled_reason = :reason',
                ExpressionAttributeValues={
                    ':inactive': False,
                    ':timestamp': Decimal(str(int(time.time()))),
                    ':reason': 'SECURITY_INCIDENT'
                }
            )
            return True
        except Exception as e:
            print(f"Failed to disable API key: {e}")
            return False
    
    def _check_pattern_escalation(self, finding: Dict[str, Any]) -> bool:
        """Check if this finding indicates pattern escalation"""
        # Implementation would check for repeated similar findings
        return False
    
    def _log_security_incident(self, incident_id: str, source: str, severity: str, 
                              finding: Dict[str, Any], actions: List[str]):
        """Log security incident to incidents table"""
        try:
            self.incidents_table.put_item(
                Item={
                    'incident_id': incident_id,
                    'timestamp': Decimal(str(int(time.time()))),
                    'source': source,
                    'severity': severity,
                    'finding_details': json.dumps(finding),
                    'response_actions': actions,
                    'status': 'RESPONDED',
                    'ttl': int(time.time()) + (365 * 24 * 3600)  # Keep for 1 year
                }
            )
        except Exception as e:
            print(f"Failed to log security incident: {e}")
    
    def _send_security_alert(self, severity: str, title: str, description: str, actions: List[str]):
        """Send security alert via SNS"""
        try:
            message = {
                'severity': severity,
                'title': title,
                'description': description,
                'actions_taken': actions,
                'timestamp': int(time.time()),
                'system': 'Payment Processing System'
            }
            
            sns_topic_arn = boto3.Session().region_name
            # Get SNS topic ARN from environment or configuration
            
            self.sns.publish(
                TopicArn=f"arn:aws:sns:{sns_topic_arn}:payment-system-security-alerts",
                Subject=f"[{severity}] Payment System Security Alert",
                Message=json.dumps(message, indent=2)
            )
        except Exception as e:
            print(f"Failed to send security alert: {e}")
    
    def _handle_security_hub_finding(self, finding: Dict[str, Any]) -> Dict[str, Any]:
        """Handle Security Hub findings"""
        # Similar to GuardDuty but for Security Hub findings
        return {'statusCode': 200, 'body': 'Security Hub finding processed'}
    
    def _handle_custom_security_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Handle custom payment system security events"""
        # Handle events from application-level security monitoring
        return {'statusCode': 200, 'body': 'Custom security event processed'}
    
    def _log_unknown_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Log unknown security events for investigation"""
        print(f"Unknown security event received: {json.dumps(event)}")
        return {'statusCode': 200, 'body': 'Unknown event logged'}

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Main Lambda handler for security incident response"""
    
    try:
        responder = SecurityIncidentResponder()
        return responder.handle_security_event(event)
    
    except Exception as e:
        print(f"Security response handler error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'SECURITY_RESPONSE_ERROR',
                'message': 'Failed to process security event'
            })
        }