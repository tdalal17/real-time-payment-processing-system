import os
import sys
import json
import uvicorn
from fastapi import FastAPI, Request, Response, HTTPException
from typing import Dict, Any

# Set environment variables for local execution
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
# This will be set by docker-compose, but good default
if not os.environ.get('DYNAMODB_ENDPOINT'):
    print("Warning: DYNAMODB_ENDPOINT not set. Lambdas might try to connect to real AWS.")

# Add src to path so we can import lambdas
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'src')))

# Import Lambda handlers
from lambdas.process_payment.lambda_function import lambda_handler as process_payment_handler
from lambdas.get_transaction.lambda_function import lambda_handler as get_transaction_handler
from lambdas.process_refund.lambda_function import lambda_handler as process_refund_handler
# We could also import the authorizer, but for simplicity we might skip it or mock it in local dev
# depending on how strict we want to be. For now, let's skip auth in local dev or just simulate it.

app = FastAPI(title="Payment System Local API")

@app.on_event("startup")
async def startup_event():
    """Initialize DynamoDB tables on startup"""
    if not os.environ.get('DYNAMODB_ENDPOINT'):
        print("Skipping local table creation (DYNAMODB_ENDPOINT not set)")
        return

    print("Initializing local database tables...")
    try:
        dynamodb = PaymentSystemUtils.get_dynamodb_resource()
        
        # Table definitions
        tables = [
            {
                'TableName': 'payment-system-transactions',
                'KeySchema': [{'AttributeName': 'transaction_id', 'KeyType': 'HASH'}],
                'AttributeDefinitions': [{'AttributeName': 'transaction_id', 'AttributeType': 'S'}],
                'ProvisionedThroughput': {'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
            },
            {
                'TableName': 'payment-system-idempotency',
                'KeySchema': [{'AttributeName': 'idempotency_key', 'KeyType': 'HASH'}],
                'AttributeDefinitions': [{'AttributeName': 'idempotency_key', 'AttributeType': 'S'}],
                'ProvisionedThroughput': {'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
            },
            {
                'TableName': 'payment-system-api-keys',
                'KeySchema': [{'AttributeName': 'key_hash', 'KeyType': 'HASH'}],
                'AttributeDefinitions': [{'AttributeName': 'key_hash', 'AttributeType': 'S'}],
                'ProvisionedThroughput': {'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
            }
        ]
        
        existing_tables = [t.name for t in dynamodb.tables.all()]
        
        for table_def in tables:
            table_name = table_def['TableName']
            if table_name not in existing_tables:
                print(f"Creating table: {table_name}")
                dynamodb.create_table(**table_def)
            else:
                print(f"Table exists: {table_name}")
                
    except Exception as e:
        print(f"Error initializing tables: {str(e)}")
        print("Is DynamoDB Local running?")

def create_api_gateway_event(request: Request, body: Any = None) -> Dict[str, Any]:
    """Create a mock API Gateway event from FastAPI request"""
    
    # Extract path parameters if any (simplified)
    path_params = request.path_params
    
    # Extract query params
    query_params = dict(request.query_params)
    
    # Headers
    headers = dict(request.headers)
    
    return {
        'body': json.dumps(body) if body else None,
        'headers': headers,
        'httpMethod': request.method,
        'path': request.url.path,
        'pathParameters': path_params,
        'queryStringParameters': query_params,
        'requestContext': {
            'identity': {
                'sourceIp': request.client.host,
                'userAgent': headers.get('user-agent')
            },
            'stage': 'local'
        }
    }

@app.post("/payments")
async def create_payment(request: Request):
    try:
        body = await request.json()
    except Exception:
        body = {}
        
    event = create_api_gateway_event(request, body)
    
    # Call Lambda
    response = process_payment_handler(event, None)
    
    return Response(
        content=response.get('body', ''),
        status_code=response.get('statusCode', 200),
        media_type="application/json",
        headers=response.get('headers', {})
    )

@app.get("/payments/{transaction_id}")
async def get_transaction(transaction_id: str, request: Request):
    event = create_api_gateway_event(request)
    # Ensure path parameters are set correctly
    event['pathParameters'] = {'transaction_id': transaction_id}
    
    response = get_transaction_handler(event, None)
    
    return Response(
        content=response.get('body', ''),
        status_code=response.get('statusCode', 200),
        media_type="application/json",
        headers=response.get('headers', {})
    )

@app.post("/payments/{transaction_id}/refund")
async def refund_transaction(transaction_id: str, request: Request):
    try:
        body = await request.json()
    except Exception:
        body = {}
        
    event = create_api_gateway_event(request, body)
    event['pathParameters'] = {'transaction_id': transaction_id}
    
    response = process_refund_handler(event, None)
    
    return Response(
        content=response.get('body', ''),
        status_code=response.get('statusCode', 200),
        media_type="application/json",
        headers=response.get('headers', {})
    )

@app.get("/health")
async def health_check():
    return {"status": "healthy", "mode": "local"}

if __name__ == "__main__":
    # Disable reload for easier process management in basic run checks
    uvicorn.run(app, host="0.0.0.0", port=8000)
