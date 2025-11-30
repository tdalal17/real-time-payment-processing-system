"""
Simple Test Authorizer - Allow All Requests
This is for debugging the REQUEST authorizer flow
"""

import json
import time
from typing import Dict, Any

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Simple authorizer that allows all requests with debug logging"""
    
    try:
        print("=== SIMPLE AUTHORIZER DEBUG ===")
        print(f"Event received: {json.dumps(event, indent=2, default=str)}")
        print("===============================")
        
        # Extract method ARN - try multiple possible locations
        method_arn = event.get('methodArn')
        if not method_arn:
            method_arn = event.get('requestContext', {}).get('methodArn') 
        if not method_arn:
            method_arn = '*'
        
        print(f"Using methodArn: {method_arn}")
        
        # Always allow - for testing
        allow_policy = {
            'principalId': 'test-user-v2',
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Effect': 'Allow',  # Always allow for testing
                        'Resource': method_arn
                    }
                ]
            },
            'context': {
                'test': 'simple-authorizer-working-v2',
                'timestamp': str(int(time.time())),
                'api_key': event.get('headers', {}).get('X-API-Key', 'none')[:10]  # First 10 chars for debugging
            }
        }
        
        print(f"Returning ALLOW policy: {json.dumps(allow_policy, indent=2)}")
        return allow_policy
        
    except Exception as e:
        print(f"Simple authorizer error: {e}")
        print(f"Error type: {type(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        
        # Even on error, allow for debugging
        fallback_policy = {
            'principalId': 'error-but-allow',
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Effect': 'Allow',
                        'Resource': '*'
                    }
                ]
            },
            'context': {
                'error': str(e),
                'timestamp': str(int(time.time()))
            }
        }
        print(f"Returning ERROR fallback policy: {json.dumps(fallback_policy, indent=2)}")
        return fallback_policy