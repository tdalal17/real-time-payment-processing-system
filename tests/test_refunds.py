import sys
import os
import json
import time
import pytest
from decimal import Decimal
from unittest.mock import patch

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

@pytest.fixture
def refund_processor(transactions_table, idempotency_table):
    from lambdas.process_refund import lambda_function
    import importlib
    importlib.reload(lambda_function)
    
    # Patch the global tables
    with patch.object(lambda_function, 'transactions_table', transactions_table), \
         patch.object(lambda_function, 'idempotency_table', idempotency_table):
        return lambda_function.RefundProcessor()

@pytest.fixture
def seed_transaction(transactions_table):
    tx_id = "tx_12345_completed"
    transactions_table.put_item(Item={
        'transaction_id': tx_id,
        'status': 'completed',
        'amount': Decimal('100.00'),
        'currency': 'USD',
        'user_id': 'user_1',
        'merchant_id': 'merchant_1',
        'timestamp': int(time.time() * 1000)
    })
    return tx_id

def test_full_refund(refund_processor, seed_transaction):
    event = {
        'pathParameters': {'transaction_id': seed_transaction},
        'body': json.dumps({
            'amount': 100.00,
            'reason': 'Customer requested refund'
        })
    }
    
    response = refund_processor.process_refund(event)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['status'] == 'fully_refunded'
    # Decimal conversion to string can vary (100.0 vs 100.00), compare as floats or Decimals
    assert float(body['total_refunded']) == 100.00

def test_partial_refund(refund_processor, seed_transaction):
    event = {
        'pathParameters': {'transaction_id': seed_transaction},
        'body': json.dumps({
            'amount': 25.50,
            'reason': 'Partial refund'
        })
    }
    
    response = refund_processor.process_refund(event)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['status'] == 'partially_refunded'
    assert float(body['total_refunded']) == 25.50

def test_refund_exceeds_amount(refund_processor, seed_transaction):
    event = {
        'pathParameters': {'transaction_id': seed_transaction},
        'body': json.dumps({
            'amount': 150.00,  # Original is 100.00
            'reason': 'Fraud'
        })
    }
    
    response = refund_processor.process_refund(event)
    
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'exceeds original transaction amount' in body['error']

def test_refund_invalid_transaction_state(refund_processor, transactions_table):
    tx_id = "tx_failed_1"
    transactions_table.put_item(Item={
        'transaction_id': tx_id,
        'status': 'declined',  # Cannot refund this
        'amount': Decimal('100.00'),
        'currency': 'USD'
    })
    
    event = {
        'pathParameters': {'transaction_id': tx_id},
        'body': json.dumps({
            'amount': 100.00
        })
    }
    
    response = refund_processor.process_refund(event)
    
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'Cannot refund transaction with status' in body['error']
