import json
import os
from typing import Any, Dict


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body),
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    path = event.get("rawPath") or event.get("path") or "/"

    if path == "/health":
        return _response(200, {"status": "ok", "env": os.getenv("APP_ENV", "demo")})

    # Default: echo request (useful during early integration testing)
    return _response(200, {
        "message": "payments handler",
        "path": path,
    })


