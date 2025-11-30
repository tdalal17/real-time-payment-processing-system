import sys
import os
import json
import pytest
from decimal import Decimal
from unittest.mock import patch

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

@pytest.fixture
def processor(transactions_table, idempotency_table):
    # Import here to ensure it uses the mocked environment/boto3
    from lambdas.process_payment import lambda_function
    import importlib
    importlib.reload(lambda_function)
    
    # Patch the global tables in the module to use our mocked tables
    with patch.object(lambda_function, 'transactions_table', transactions_table), \
         patch.object(lambda_function, 'idempotency_table', idempotency_table):
        return lambda_function.PaymentProcessor()

def test_successful_payment(processor):
    event = {
        'body': json.dumps({
            'amount': 100.00,
            'currency': 'USD',
            'user_id': 'test_user_1',
            'merchant_id': 'test_merchant_1'
        })
    }
    
    response = processor.process_payment(event)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['status'] == 'completed'
    assert body['amount'] == '100.0'
    assert 'transaction_id' in body

def test_high_risk_payment_review(processor):
    event = {
        'body': json.dumps({
            'amount': 1500.00,
            'currency': 'USD',
            'user_id': 'test_user_2',
            'merchant_id': 'test_merchant_1'
        })
    }
    
    response = processor.process_payment(event)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['status'] == 'pending_review'
    assert body['fraud_check']['risk_level'] == 'MEDIUM'

def test_very_high_risk_payment_decline(processor):
    event = {
        'body': json.dumps({
            'amount': 6000.00,
            'currency': 'USD',
            'user_id': 'test_user_3',
            'merchant_id': 'test_merchant_1'
        })
    }
    
    response = processor.process_payment(event)
    
    assert response['statusCode'] == 402
    body = json.loads(response['body'])
    assert body['status'] == 'declined'
    assert body['fraud_check']['risk_level'] == 'HIGH'

def test_idempotency_duplicate_request(processor):
    event = {
        'body': json.dumps({
            'amount': 50.00,
            'currency': 'USD',
            'user_id': 'test_user_4',
            'merchant_id': 'test_merchant_1'
        }),
        'headers': {
            'Idempotency-Key': 'unique-key-123'
        }
    }
    
    # First request
    response1 = processor.process_payment(event)
    assert response1['statusCode'] == 200
    body1 = json.loads(response1['body'])
    tx_id1 = body1['transaction_id']
    
    # Second request (same key)
    response2 = processor.process_payment(event)
    assert response2['statusCode'] == 200
    body2 = json.loads(response2['body'])
    tx_id2 = body2['transaction_id']
    
    # Should be exact same transaction ID
    assert tx_id1 == tx_id2

def test_missing_fields_validation(processor):
    event = {
        'body': json.dumps({
            'amount': 100.00,
            # Missing currency, user_id, merchant_id
        })
    }
    
    response = processor.process_payment(event)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'Missing required field' in body['error']
