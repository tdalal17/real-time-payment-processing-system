"""
Enterprise Security Configuration for Payment Processing System
PCI-DSS Level 1 Compliant Settings
"""

import os
from typing import Dict, List, Any

class SecurityConfig:
    """Centralized security configuration"""
    
    # PCI-DSS Compliance Settings
    PCI_COMPLIANT_HEADERS = {
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
        "Cache-Control": "no-store, no-cache, must-revalidate, private",
        "Pragma": "no-cache",
        "Expires": "0"
    }
    
    # Rate Limiting Configuration
    RATE_LIMITS = {
        "default": {
            "requests_per_minute": 100,
            "burst_limit": 20,
            "window_size": 60  # seconds
        },
        "premium": {
            "requests_per_minute": 500,
            "burst_limit": 100,
            "window_size": 60
        },
        "enterprise": {
            "requests_per_minute": 2000,
            "burst_limit": 500,
            "window_size": 60
        }
    }
    
    # Input Validation Rules
    VALIDATION_RULES = {
        "amount": {
            "min": 0.01,
            "max": 999999.99,
            "decimal_places": 2
        },
        "currency": {
            "allowed": ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "SEK", "NOK", "DKK"],
            "regex": r"^[A-Z]{3}$"
        },
        "user_id": {
            "regex": r"^[a-zA-Z0-9_-]{1,50}$",
            "max_length": 50
        },
        "merchant_id": {
            "regex": r"^[a-zA-Z0-9_-]{1,50}$",
            "max_length": 50
        },
        "card_number": {
            "regex": r"^\d{13,19}$",
            "luhn_check": True
        },
        "cvv": {
            "regex": r"^\d{3,4}$"
        },
        "transaction_id": {
            "regex": r"^[a-fA-F0-9-]{36}$"  # UUID format
        }
    }
    
    # Encryption Settings
    ENCRYPTION_CONFIG = {
        "algorithm": "AES-256-GCM",
        "key_rotation_days": 90,
        "kms_key_alias": f"alias/payment-system-{os.getenv('ENVIRONMENT', 'demo')}",
        "encrypted_fields": ["card_number", "cvv", "card_holder_name", "bank_account"]
    }
    
    # Audit Logging Configuration
    AUDIT_CONFIG = {
        "retention_days": 2555,  # 7 years for PCI-DSS compliance
        "high_priority_events": [
            "AUTHENTICATION_FAILED",
            "AUTHORIZATION_FAILED", 
            "RATE_LIMIT_EXCEEDED",
            "PAYMENT_DECLINED",
            "REFUND_PROCESSED",
            "SUSPICIOUS_ACTIVITY",
            "DATA_BREACH_ATTEMPT"
        ],
        "log_sensitive_data": False,  # Never log actual sensitive data
        "alert_thresholds": {
            "failed_auth_per_minute": 10,
            "rate_limit_violations_per_hour": 50,
            "suspicious_payments_per_hour": 5
        }
    }
    
    # Fraud Detection Thresholds
    FRAUD_DETECTION = {
        "max_amount_single_transaction": 10000.00,
        "max_daily_amount_per_user": 50000.00,
        "max_transactions_per_minute": 5,
        "suspicious_patterns": [
            "rapid_successive_payments",
            "round_number_amounts",
            "foreign_ip_high_amount",
            "new_card_high_amount"
        ],
        "country_restrictions": {
            "blocked_countries": ["XX", "YY"],  # ISO country codes to block
            "high_risk_countries": ["ZZ"]  # Countries requiring additional verification
        }
    }
    
    # API Security Settings
    API_SECURITY = {
        "require_https": True,
        "min_tls_version": "1.2",
        "cors_origins": ["https://secure-merchant.com", "https://dashboard.payment-system.com"],
        "max_request_size": 1048576,  # 1MB
        "request_timeout": 30,  # seconds
        "require_idempotency_key": True,
        "api_key_format": r"^pk_[a-z]+_[A-Za-z0-9_-]{43}$"
    }
    
    # WAF Rules Configuration
    WAF_RULES = {
        "rate_limit_per_ip": 2000,  # requests per 5-minute window
        "enable_geo_blocking": True,
        "blocked_countries": ["CN", "RU", "KP"],  # Example blocked countries
        "enable_ip_reputation": True,
        "enable_managed_rules": [
            "AWSManagedRulesCommonRuleSet",
            "AWSManagedRulesKnownBadInputsRuleSet",
            "AWSManagedRulesSQLiRuleSet",
            "AWSManagedRulesLinuxRuleSet",
            "AWSManagedRulesAmazonIpReputationList"
        ]
    }
    
    # Monitoring and Alerting
    MONITORING_CONFIG = {
        "enable_cloudwatch_detailed_monitoring": True,
        "custom_metrics": [
            "payment_success_rate",
            "authentication_failure_rate", 
            "fraud_detection_rate",
            "api_response_time",
            "error_rate_by_type"
        ],
        "alert_sns_topic": f"payment-system-security-alerts-{os.getenv('ENVIRONMENT', 'demo')}",
        "slack_webhook_enabled": False,  # Configure if needed
        "email_alerts": ["security@company.com", "devops@company.com"]
    }
    
    @classmethod
    def get_environment_config(cls) -> Dict[str, Any]:
        """Get environment-specific security configuration"""
        env = os.getenv('ENVIRONMENT', 'demo')
        
        if env == 'production':
            return cls._get_production_config()
        elif env == 'staging':
            return cls._get_staging_config()
        else:
            return cls._get_demo_config()
    
    @classmethod
    def _get_production_config(cls) -> Dict[str, Any]:
        """Production security configuration - maximum security"""
        return {
            "encryption_enabled": True,
            "audit_level": "verbose",
            "rate_limit_tier": "enterprise",
            "fraud_detection_sensitivity": "high",
            "require_mfa": True,
            "session_timeout": 900,  # 15 minutes
            "log_retention_days": 2555,  # 7 years
            "enable_waf": True,
            "require_client_certificates": True
        }
    
    @classmethod
    def _get_staging_config(cls) -> Dict[str, Any]:
        """Staging security configuration - production-like with some flexibility"""
        return {
            "encryption_enabled": True,
            "audit_level": "standard",
            "rate_limit_tier": "premium", 
            "fraud_detection_sensitivity": "medium",
            "require_mfa": False,
            "session_timeout": 1800,  # 30 minutes
            "log_retention_days": 90,
            "enable_waf": True,
            "require_client_certificates": False
        }
    
    @classmethod
    def _get_demo_config(cls) -> Dict[str, Any]:
        """Demo security configuration - secure but developer-friendly"""
        return {
            "encryption_enabled": True,
            "audit_level": "basic",
            "rate_limit_tier": "default",
            "fraud_detection_sensitivity": "low",
            "require_mfa": False,
            "session_timeout": 3600,  # 1 hour
            "log_retention_days": 30,
            "enable_waf": True,
            "require_client_certificates": False
        }

# Common permission sets for different client types
PERMISSION_SETS = {
    "merchant_basic": [
        "payments:create",
        "payments:read", 
        "transactions:list"
    ],
    "merchant_advanced": [
        "payments:create",
        "payments:read",
        "payments:refund", 
        "transactions:list",
        "webhooks:manage"
    ],
    "analytics_readonly": [
        "payments:read",
        "transactions:list",
        "reports:read"
    ],
    "support_agent": [
        "payments:read",
        "transactions:list",
        "payments:refund"
    ],
    "admin": [
        "*:*"
    ]
}

# Security event severity levels
SECURITY_EVENT_SEVERITY = {
    "CRITICAL": [
        "MULTIPLE_AUTH_FAILURES",
        "SUSPECTED_BREACH", 
        "FRAUD_CONFIRMED",
        "UNAUTHORIZED_ACCESS_ATTEMPT"
    ],
    "HIGH": [
        "RATE_LIMIT_EXCEEDED",
        "SUSPICIOUS_PAYMENT_PATTERN",
        "GEOLOCATION_ANOMALY",
        "API_KEY_BRUTEFORCE"
    ],
    "MEDIUM": [
        "AUTHENTICATION_FAILED",
        "AUTHORIZATION_FAILED",
        "INPUT_VALIDATION_FAILED"
    ],
    "LOW": [
        "API_KEY_VALID",
        "PAYMENT_PROCESSED",
        "ROUTINE_ACCESS"
    ]
}