import os
import boto3
import pytest
from moto import mock_aws

@pytest.fixture(scope='function')
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

@pytest.fixture(scope='function')
def dynamodb(aws_credentials):
    """Mock DynamoDB client."""
    with mock_aws():
        yield boto3.resource('dynamodb', region_name='us-east-1')

@pytest.fixture(scope='function')
def transactions_table(dynamodb):
    """Create the transactions table for testing."""
    table = dynamodb.create_table(
        TableName='payment-system-transactions',
        KeySchema=[{'AttributeName': 'transaction_id', 'KeyType': 'HASH'}],
        AttributeDefinitions=[{'AttributeName': 'transaction_id', 'AttributeType': 'S'}],
        ProvisionedThroughput={'ReadCapacityUnits': 1, 'WriteCapacityUnits': 1}
    )
    return table

@pytest.fixture(scope='function')
def idempotency_table(dynamodb):
    """Create the idempotency table for testing."""
    table = dynamodb.create_table(
        TableName='payment-system-idempotency',
        KeySchema=[{'AttributeName': 'idempotency_key', 'KeyType': 'HASH'}],
        AttributeDefinitions=[{'AttributeName': 'idempotency_key', 'AttributeType': 'S'}],
        ProvisionedThroughput={'ReadCapacityUnits': 1, 'WriteCapacityUnits': 1}
    )
    return table
