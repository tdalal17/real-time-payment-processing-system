import hashlib
import secrets
import time
from typing import Dict, Any, List
import boto3
from decimal import Decimal

class APIKeyManager:
    """Enterprise API key management system"""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.api_keys_table = self.dynamodb.Table('payment-system-api-keys')
    
    def create_api_key(self, client_name: str, permissions: List[str], environment: str = "demo") -> Dict[str, Any]:
        """
        Create a new API key with specified permissions
        
        Permission examples:
        - "payments:create" - Allow creating payments
        - "payments:read" - Allow reading payment data
        - "payments:refund" - Allow processing refunds
        - "transactions:list" - Allow listing transactions
        - "*:*" - Full access (use carefully)
        """
        
        # Generate secure API key
        api_key = f"pk_{environment}_{secrets.token_urlsafe(32)}"
        
        # Hash for secure storage
        key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        
        # Generate client ID
        client_id = f"client_{secrets.token_urlsafe(16)}"
        
        # Store in DynamoDB
        timestamp = int(time.time())
        
        key_record = {
            'key_hash': key_hash,
            'client_id': client_id,
            'client_name': client_name,
            'permissions': permissions,
            'environment': environment,
            'is_active': True,
            'created_at': timestamp,
            'last_used': None,
            'usage_count': Decimal('0'),
            'rate_limit_per_minute': Decimal('100'),  # Default rate limit
            'api_key_prefix': api_key[:12] + "..."  # Store prefix for identification
        }
        
        self.api_keys_table.put_item(Item=key_record)
        
        return {
            'api_key': api_key,
            'client_id': client_id,
            'client_name': client_name,
            'permissions': permissions,
            'environment': environment,
            'created_at': timestamp,
            'rate_limit_per_minute': 100
        }
    
    def revoke_api_key(self, api_key: str) -> bool:
        """Revoke an API key by marking it inactive"""
        try:
            key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            
            self.api_keys_table.update_item(
                Key={'key_hash': key_hash},
                UpdateExpression='SET is_active = :inactive, revoked_at = :timestamp',
                ExpressionAttributeValues={
                    ':inactive': False,
                    ':timestamp': Decimal(str(int(time.time())))
                }
            )
            return True
        except Exception:
            return False
    
    def list_api_keys(self, environment: str = "demo") -> List[Dict[str, Any]]:
        """List all API keys for an environment (without exposing the actual keys)"""
        try:
            response = self.api_keys_table.scan(
                FilterExpression='environment = :env',
                ExpressionAttributeValues={':env': environment}
            )
            
            # Return safe information only
            keys = []
            for item in response.get('Items', []):
                keys.append({
                    'client_id': item['client_id'],
                    'client_name': item['client_name'],
                    'permissions': item['permissions'],
                    'is_active': item['is_active'],
                    'created_at': int(item['created_at']),
                    'api_key_prefix': item.get('api_key_prefix', 'pk_***'),
                    'usage_count': int(item.get('usage_count', 0)),
                    'last_used': int(item['last_used']) if item.get('last_used') else None
                })
            
            return keys
        except Exception:
            return []
    
    def update_permissions(self, client_id: str, permissions: List[str]) -> bool:
        """Update permissions for a client"""
        try:
            self.api_keys_table.update_item(
                Key={'client_id': client_id},
                UpdateExpression='SET permissions = :perms, updated_at = :timestamp',
                ExpressionAttributeValues={
                    ':perms': permissions,
                    ':timestamp': Decimal(str(int(time.time())))
                }
            )
            return True
        except Exception:
            return False

# CLI utility functions for key management
def create_demo_api_keys():
    """Create demo API keys for testing"""
    manager = APIKeyManager()
    
    # Full access key for admin testing
    admin_key = manager.create_api_key(
        client_name="Admin Test Client",
        permissions=["*:*"],
        environment="demo"
    )
    
    # Limited permissions key for merchant
    merchant_key = manager.create_api_key(
        client_name="Merchant Test Client", 
        permissions=["payments:create", "payments:read", "transactions:list"],
        environment="demo"
    )
    
    # Read-only key for analytics
    analytics_key = manager.create_api_key(
        client_name="Analytics Client",
        permissions=["payments:read", "transactions:list"],
        environment="demo"
    )
    
    return {
        'admin': admin_key,
        'merchant': merchant_key,
        'analytics': analytics_key
    }

if __name__ == "__main__":
    # Create demo keys
    keys = create_demo_api_keys()
    
    print("=== ENTERPRISE API KEYS CREATED ===")
    print(f"Admin Key: {keys['admin']['api_key']}")
    print(f"Merchant Key: {keys['merchant']['api_key']}")
    print(f"Analytics Key: {keys['analytics']['api_key']}")
    print("\nSave these keys securely! They cannot be retrieved again.")