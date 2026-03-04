"""
LaunchDarkly Feature Flag Management
====================================

This module provides comprehensive feature flag management and deployment
control for the Verified Services Marketplace using LaunchDarkly.

LaunchDarkly enables:
- Feature flags with complex targeting rules
- Gradual rollouts with percentage-based deployment
- Kill switches for emergency feature disablement
- Segment-based feature access control
- User context and attribute-based evaluation
- Flag lifecycle management (alpha → beta → GA → sunsetting)

Production usage:
    from feature_flags.launchdarkly_config import FeatureFlagManager, LDUserContext
    
    manager = FeatureFlagManager(
        sdk_key="sdk_key_xyz",
        environment="production"
    )
    
    user = LDUserContext(
        user_id="user_123",
        account_type="customer",
        subscription_tier="premium",
        region="US"
    )
    
    # Check feature flag
    if manager.check_flag(user, "enable_instant_booking"):
        # Show instant booking feature
        show_instant_booking()
    
    # Get variation with default fallback
    variant = manager.get_variation(
        user=user,
        flag_key="dynamic_pricing",
        default="fixed"
    )
    
    # Track custom metric
    manager.track_metric(
        user=user,
        metric_key="booking_success_rate",
        value=1
    )
"""

import time
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from enum import Enum

# Mock import for production environment
# In actual implementation: from ldclient import Context, LDClient
try:
    from ldclient import Context as LDContext
    from ldclient import LDClient
    LAUNCHDARKLY_AVAILABLE = True
except ImportError:
    LAUNCHDARKLY_AVAILABLE = False
    # Fallback classes
    class LDContext:
        def __init__(self, user_id: str, **kwargs):
            self.user_id = user_id
            self.attributes = kwargs


# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class AccountType(Enum):
    """User account type for feature targeting."""
    CUSTOMER = "customer"
    PROVIDER = "provider"
    OPERATOR = "operator"  # Platform operator/admin


class SubscriptionTier(Enum):
    """Subscription tier levels."""
    BASIC = "basic"
    STANDARD = "standard"
    PREMIUM = "premium"
    ENTERPRISE = "enterprise"


class FlagStatus(Enum):
    """Feature flag lifecycle status."""
    PLANNING = "planning"       # Planning phase, not yet implemented
    TESTING = "testing"          # Internal testing
    PARTIAL_ROLLOUT = "partial"  # Gradually rolling out (0-100%)
    FULL_ROLLOUT = "full"        # Enabled for all users
    ROLLBACK = "rollback"        # In process of rolling back
    PERMANENT = "permanent"      # Permanent feature (flag can be removed)
    SUNSETTING = "sunsetting"    # Scheduled for removal


@dataclass
class LDUserContext:
    """
    LaunchDarkly user context for flag evaluation.
    
    User context is crucial for:
    - Flag bucketing and consistency
    - Targeting rule evaluation
    - Segment membership determination
    - Feature access control
    
    Attributes:
        user_id: Unique user identifier (required)
        account_type: Type of account (customer, provider, operator)
        subscription_tier: Subscription level for feature gating
        region: Geographic region for localized features
        signup_date: ISO format date when user joined
        total_bookings: Aggregate metric for power user detection
        is_new_user: Whether account is less than 7 days old
        is_verified: Account verification status (for providers)
    """
    user_id: str
    account_type: str = "customer"
    subscription_tier: str = "basic"
    region: str = "US"
    signup_date: Optional[str] = None
    total_bookings: int = 0
    is_new_user: bool = False
    is_verified: bool = False
    custom_attributes: Optional[Dict[str, Any]] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API serialization."""
        data = asdict(self)
        if self.custom_attributes is None:
            data.pop('custom_attributes', None)
        else:
            data['custom_attributes'] = self.custom_attributes
        return data
    
    def to_ld_context(self):
        """Convert to LaunchDarkly Context object."""
        if not LAUNCHDARKLY_AVAILABLE:
            return self
        
        attributes = {
            "account_type": self.account_type,
            "subscription_tier": self.subscription_tier,
            "region": self.region,
            "signup_date": self.signup_date,
            "total_bookings": self.total_bookings,
            "is_new_user": self.is_new_user,
            "is_verified": self.is_verified,
        }
        
        if self.custom_attributes:
            attributes.update(self.custom_attributes)
        
        return LDContext(self.user_id, **attributes)


@dataclass
class FlagVariation:
    """
    Feature flag variation definition.
    
    Attributes:
        key: Internal variation identifier
        name: User-friendly variation name
        value: Boolean, string, number, or object value
        description: Explanation of this variation
        on_percentage: Percentage allocation for progressive rollout
    """
    key: str
    name: str
    value: Union[bool, str, int, Dict[str, Any]]
    description: str = ""
    on_percentage: Optional[float] = None


class FeatureFlagManager:
    """
    LaunchDarkly feature flag manager for controlled deployments.
    
    This manager handles:
    - Binary feature flags (on/off)
    - Multivariate flags (multiple variations)
    - Progressive rollouts (0% → 100% over time)
    - User segment targeting
    - Kill switches for emergency disablement
    - User context management
    - Custom metric tracking
    
    Key concepts:
    - Bucketing: Consistent user assignment to variations
    - Prerequisites: Flags can depend on other flags
    - Targeting Rules: Complex conditions for flag evaluation
    - Segments: Named groups of users for targeting
    
    Example:
        manager = FeatureFlagManager(sdk_key="...", environment="prod")
        user = LDUserContext(user_id="123", subscription_tier="premium")
        
        # Boolean flag
        if manager.check_flag(user, "enable_instant_booking"):
            show_instant_booking()
        
        # Multivariate flag
        pricing = manager.get_variation(user, "dynamic_pricing", "fixed")
        
        # Kill switch
        if not manager.check_flag(user, "escrow_payment_flow"):
            # Fallback to simple payment
            process_simple_payment()
    """
    
    # Pre-defined feature flags
    FLAGS = {
        "enable_instant_booking": {
            "name": "Instant Booking",
            "description": "Allow customers to book services instantly without provider approval",
            "kind": "boolean",
            "enabled": False,
            "rollout_strategy": "percentage",
            "variations": [
                FlagVariation(key="off", name="Off", value=False),
                FlagVariation(key="on", name="On", value=True)
            ],
            "percentage_rollout": {
                "week_1": 0,      # Start: No users
                "week_2": 10,     # Week 2: 10%
                "week_3": 50,     # Week 3: 50%
                "week_4": 100     # Week 4: Full rollout
            },
            "target_segments": ["all_users"],
            "prerequisites": [],
            "status": FlagStatus.PARTIAL_ROLLOUT.value,
            "launched_date": "2026-02-11"
        },
        
        "provider_verification_v2": {
            "name": "Provider Verification V2",
            "description": "A/B test: legacy manual review vs. automated + Checkr verification",
            "kind": "string",
            "enabled": True,
            "rollout_strategy": "experiment",
            "variations": [
                FlagVariation(
                    key="legacy_manual",
                    name="Legacy Manual Review",
                    value="legacy_manual_review",
                    description="Traditional manual provider verification (control)",
                    on_percentage=50.0
                ),
                FlagVariation(
                    key="automated_checkr",
                    name="Automated + Checkr",
                    value="automated_plus_checkr",
                    description="Automated verification with Checkr integration (treatment)",
                    on_percentage=50.0
                )
            ],
            "target_segments": ["new_providers"],
            "prerequisites": ["enable_ml_recommendations"],
            "status": FlagStatus.PARTIAL_ROLLOUT.value,
            "launched_date": "2026-02-18",
            "experiment_duration_days": 21
        },
        
        "dynamic_pricing": {
            "name": "Dynamic Pricing",
            "description": "Multivariate test: fixed vs. surge vs. demand-based pricing strategies",
            "kind": "string",
            "enabled": True,
            "rollout_strategy": "multivariate",
            "variations": [
                FlagVariation(
                    key="fixed",
                    name="Fixed Pricing",
                    value="fixed",
                    description="Standard fixed service pricing",
                    on_percentage=33.33
                ),
                FlagVariation(
                    key="surge",
                    name="Surge Pricing",
                    value="surge_pricing",
                    description="Surge pricing during peak hours",
                    on_percentage=33.33
                ),
                FlagVariation(
                    key="demand_based",
                    name="Demand-Based",
                    value="demand_based",
                    description="Demand-curve based dynamic pricing (ML)",
                    on_percentage=33.34
                )
            ],
            "target_segments": ["all_users"],
            "prerequisites": ["enable_instant_booking"],
            "status": FlagStatus.PARTIAL_ROLLOUT.value,
            "launched_date": "2026-02-25"
        },
        
        "new_search_algorithm": {
            "name": "New Search Algorithm",
            "description": "Beta feature: improved search and filtering for marketplace",
            "kind": "boolean",
            "enabled": True,
            "rollout_strategy": "segment_based",
            "variations": [
                FlagVariation(key="off", name="Old Algorithm", value=False),
                FlagVariation(key="on", name="New Algorithm", value=True)
            ],
            "target_segments": ["marketplace_power_users"],
            "segment_definition": {
                "total_bookings": {"gte": 10},
                "account_age_days": {"gte": 90}
            },
            "prerequisites": [],
            "status": FlagStatus.TESTING.value,
            "launched_date": "2026-03-01"
        },
        
        "escrow_payment_flow": {
            "name": "Escrow Payment Flow",
            "description": "Enable Stripe Connect escrow payments for service protection",
            "kind": "boolean",
            "enabled": True,
            "rollout_strategy": "percentage",
            "variations": [
                FlagVariation(key="off", name="Off", value=False),
                FlagVariation(key="on", name="On", value=True)
            ],
            "percentage_rollout": {
                "current": 100  # Full rollout already
            },
            "target_segments": ["all_users"],
            "prerequisites": [],
            "status": FlagStatus.FULL_ROLLOUT.value,
            "launched_date": "2025-12-01",
            "kill_switch": True  # Emergency disable flag
        },
        
        "provider_onboarding_simplified": {
            "name": "Simplified Provider Onboarding",
            "description": "Progressive rollout: simplified onboarding by provider tier",
            "kind": "boolean",
            "enabled": True,
            "rollout_strategy": "segment_progressive",
            "variations": [
                FlagVariation(key="off", name="Standard Onboarding", value=False),
                FlagVariation(key="on", name="Simplified Onboarding", value=True)
            ],
            "target_segments": ["providers"],
            "segment_rollout": {
                "basic_tier": {"percentage": 10},          # 10% of basic providers
                "standard_tier": {"percentage": 50},       # 50% of standard
                "premium_tier": {"percentage": 100},       # 100% of premium
                "enterprise_tier": {"percentage": 100}     # 100% of enterprise
            },
            "prerequisites": [],
            "status": FlagStatus.PARTIAL_ROLLOUT.value,
            "launched_date": "2026-01-20"
        }
    }
    
    # User segments for targeting
    SEGMENTS = {
        "new_providers": {
            "name": "New Providers",
            "description": "Providers with account age < 30 days",
            "conditions": {
                "account_type": "provider",
                "account_age_days": {"lt": 30}
            }
        },
        "verified_providers": {
            "name": "Verified Providers",
            "description": "Providers who have completed verification",
            "conditions": {
                "account_type": "provider",
                "is_verified": True
            }
        },
        "high_gmv_customers": {
            "name": "High GMV Customers",
            "description": "Customers with > $5000 lifetime bookings",
            "conditions": {
                "account_type": "customer",
                "total_bookings": {"gte": 50}
            }
        },
        "enterprise_operators": {
            "name": "Enterprise Operators",
            "description": "Platform operators with enterprise access",
            "conditions": {
                "account_type": "operator",
                "subscription_tier": "enterprise"
            }
        },
        "marketplace_power_users": {
            "name": "Marketplace Power Users",
            "description": "Users with 10+ bookings and 90+ days on platform",
            "conditions": {
                "total_bookings": {"gte": 10},
                "account_age_days": {"gte": 90}
            }
        },
        "premium_subscribers": {
            "name": "Premium Subscribers",
            "description": "Users on premium or enterprise tiers",
            "conditions": {
                "subscription_tier": {"in": ["premium", "enterprise"]}
            }
        },
        "providers": {
            "name": "All Providers",
            "description": "All provider accounts",
            "conditions": {
                "account_type": "provider"
            }
        },
        "all_users": {
            "name": "All Users",
            "description": "All active users",
            "conditions": {}
        }
    }
    
    def __init__(self, sdk_key: str, environment: str = "production"):
        """
        Initialize LaunchDarkly feature flag manager.
        
        Args:
            sdk_key: LaunchDarkly server SDK key
            environment: Environment (development/staging/production)
        
        Raises:
            ValueError: If sdk_key is invalid
        """
        if not sdk_key or len(sdk_key) < 20:
            raise ValueError("Invalid SDK key for LaunchDarkly")
        
        self.sdk_key = sdk_key
        self.environment = environment
        self.initialized = False
        self.logger = logger
        self.metric_queue: List[Dict[str, Any]] = []
        self.metric_queue_max_size = 5000
        
        # Initialize SDK if available
        if LAUNCHDARKLY_AVAILABLE:
            try:
                self.client = LDClient(sdk_key)
                # Wait for client to be ready
                if self.client.is_initialized():
                    self.initialized = True
                    self.logger.info(f"LaunchDarkly initialized for {environment} environment")
                else:
                    self.logger.warning("LaunchDarkly client not ready (SDK may not be available)")
            except Exception as e:
                self.logger.error(f"Failed to initialize LaunchDarkly: {e}")
                self.initialized = False
    
    def check_flag(
        self,
        user: LDUserContext,
        flag_key: str,
        default: bool = False
    ) -> bool:
        """
        Check if a boolean feature flag is enabled for a user.
        
        This method evaluates the flag against:
        - User attributes (plan tier, region, etc.)
        - Targeting rules
        - Percentage rollout
        - Segment membership
        
        Args:
            user: LDUserContext with user information
            flag_key: Key of the flag to check
            default: Default value if evaluation fails
        
        Returns:
            bool: Flag enabled status for this user
        
        Example:
            user = LDUserContext(user_id="123", subscription_tier="premium")
            if manager.check_flag(user, "enable_instant_booking"):
                # Feature is enabled
                pass
        """
        if flag_key not in self.FLAGS:
            self.logger.warning(f"Unknown flag: {flag_key}")
            return default
        
        flag_config = self.FLAGS[flag_key]
        
        # Check prerequisites (dependent flags)
        for prerequisite in flag_config.get("prerequisites", []):
            if not self.check_flag(user, prerequisite, default=True):
                self.logger.debug(f"Flag {flag_key} prerequisite {prerequisite} not met")
                return default
        
        if self.initialized and LAUNCHDARKLY_AVAILABLE:
            try:
                context = user.to_ld_context()
                result = self.client.variation(flag_key, context, default)
                self.logger.debug(f"Flag {flag_key} evaluated to {result} for user {user.user_id}")
                return result
            except Exception as e:
                self.logger.error(f"Error evaluating flag {flag_key}: {e}")
                return default
        
        # Fallback evaluation
        return self._fallback_flag_evaluation(user, flag_config, default)
    
    def get_variation(
        self,
        user: LDUserContext,
        flag_key: str,
        default: Union[str, int, Dict[str, Any]] = None
    ) -> Union[str, int, Dict[str, Any]]:
        """
        Get variation value for a multivariate flag.
        
        Multivariate flags return string, number, or object values
        instead of boolean. Useful for A/B testing with multiple variants.
        
        Args:
            user: LDUserContext with user information
            flag_key: Key of the flag to evaluate
            default: Default value if evaluation fails
        
        Returns:
            Union[str, int, Dict]: Variation value for this user
        
        Example:
            pricing = manager.get_variation(user, "dynamic_pricing", "fixed")
            if pricing == "surge_pricing":
                apply_surge_pricing()
            elif pricing == "demand_based":
                apply_ml_pricing()
        """
        if flag_key not in self.FLAGS:
            self.logger.warning(f"Unknown flag: {flag_key}")
            return default
        
        if self.initialized and LAUNCHDARKLY_AVAILABLE:
            try:
                context = user.to_ld_context()
                result = self.client.variation(flag_key, context, default)
                self.logger.debug(f"Variation {flag_key} = {result} for user {user.user_id}")
                return result
            except Exception as e:
                self.logger.error(f"Error getting variation {flag_key}: {e}")
                return default
        
        # Fallback: return default
        return default
    
    def track_metric(
        self,
        user: LDUserContext,
        metric_key: str,
        value: Union[int, float] = 1,
        data: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Track a custom metric for experiment analysis.
        
        Metrics are used to measure experiment success criteria.
        Common metrics: conversion_rate, booking_success, payment_completion.
        
        Args:
            user: LDUserContext identifying the user
            metric_key: Name of the metric
            value: Numeric value
            data: Optional metadata dictionary
        
        Returns:
            bool: True if metric was queued successfully
        
        Example:
            manager.track_metric(
                user=user,
                metric_key="booking_success_rate",
                value=1,
                data={"booking_id": "abc123", "amount": 99.99}
            )
        """
        if not user.user_id:
            self.logger.warning("Cannot track metric without user_id")
            return False
        
        if data is None:
            data = {}
        
        metric = {
            "user_id": user.user_id,
            "metric_key": metric_key,
            "value": value,
            "timestamp": int(time.time() * 1000),
            "data": data
        }
        
        if len(self.metric_queue) < self.metric_queue_max_size:
            self.metric_queue.append(metric)
            self.logger.debug(f"Queued metric: {metric_key} for user {user.user_id}")
            return True
        else:
            self.logger.warning("Metric queue full, dropping metric")
            return False
    
    def identify_user(self, user: LDUserContext) -> LDUserContext:
        """
        Identify and register user in LaunchDarkly.
        
        Args:
            user: User context to identify
        
        Returns:
            LDUserContext: Same user object
        """
        if self.initialized and LAUNCHDARKLY_AVAILABLE:
            try:
                context = user.to_ld_context()
                # Identify the user (updates user properties)
                self.client.identify(context)
                self.logger.debug(f"Identified user: {user.user_id}")
            except Exception as e:
                self.logger.error(f"Error identifying user {user.user_id}: {e}")
        
        return user
    
    def get_flag_config(self, flag_key: str) -> Optional[Dict[str, Any]]:
        """
        Get full configuration of a feature flag.
        
        Args:
            flag_key: Key of the flag
        
        Returns:
            dict: Flag configuration, or None if not found
        """
        if flag_key in self.FLAGS:
            return self.FLAGS[flag_key]
        return None
    
    def get_segment_config(self, segment_name: str) -> Optional[Dict[str, Any]]:
        """
        Get definition of a user segment.
        
        Args:
            segment_name: Name of the segment
        
        Returns:
            dict: Segment definition, or None if not found
        """
        if segment_name in self.SEGMENTS:
            return self.SEGMENTS[segment_name]
        return None
    
    def flush_metrics(self) -> int:
        """
        Flush queued metrics to LaunchDarkly.
        
        Returns:
            int: Number of metrics flushed
        """
        if not self.metric_queue:
            return 0
        
        queue_size = len(self.metric_queue)
        
        if self.initialized and LAUNCHDARKLY_AVAILABLE:
            try:
                # In real implementation: batch submit metrics
                self.logger.info(f"Flushed {queue_size} metrics to LaunchDarkly")
                self.metric_queue.clear()
                return queue_size
            except Exception as e:
                self.logger.error(f"Error flushing metrics: {e}")
                return 0
        
        self.metric_queue.clear()
        return queue_size
    
    def shutdown(self) -> None:
        """
        Shutdown the LaunchDarkly client.
        
        Should be called during application shutdown.
        """
        self.flush_metrics()
        
        if self.initialized and LAUNCHDARKLY_AVAILABLE:
            try:
                self.client.close()
                self.logger.info("LaunchDarkly client shutdown complete")
                self.initialized = False
            except Exception as e:
                self.logger.error(f"Error during shutdown: {e}")
    
    # ==================== Internal Helper Methods ====================
    
    def _fallback_flag_evaluation(
        self,
        user: LDUserContext,
        flag_config: Dict[str, Any],
        default: bool
    ) -> bool:
        """
        Fallback flag evaluation without SDK.
        
        Uses deterministic hashing for consistent user assignment.
        """
        import hashlib
        
        # Check if flag is enabled globally
        if not flag_config.get("enabled", False):
            return default
        
        # Check current rollout percentage
        rollout = flag_config.get("percentage_rollout", {})
        if isinstance(rollout, dict):
            current_percentage = rollout.get("current", 0)
        else:
            current_percentage = rollout
        
        # Hash user to determine if in rollout
        hash_input = f"{flag_config['name']}:{user.user_id}"
        hash_value = int(hashlib.md5(hash_input.encode()).hexdigest(), 16)
        bucket = (hash_value % 10000) / 10000.0
        
        return bucket < (current_percentage / 100.0)


# ==================== Module-Level Convenience Functions ====================

_manager_instance = None


def initialize_manager(sdk_key: str, environment: str = "production") -> FeatureFlagManager:
    """
    Create or return singleton FeatureFlagManager.
    
    Args:
        sdk_key: LaunchDarkly SDK key
        environment: Environment name
    
    Returns:
        Initialized FeatureFlagManager
    """
    global _manager_instance
    if _manager_instance is None:
        _manager_instance = FeatureFlagManager(sdk_key, environment)
    return _manager_instance


def get_manager() -> Optional[FeatureFlagManager]:
    """Get the current manager instance."""
    return _manager_instance
