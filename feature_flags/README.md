# LaunchDarkly Feature Flags

Comprehensive feature flag management for the Verified Services Marketplace using LaunchDarkly.

## Overview

LaunchDarkly provides:
- **Feature Flags**: Binary, multivariate, and percentage-based flags
- **Kill Switches**: Emergency disable for critical features
- **Progressive Rollouts**: Gradual deployment (0% → 100%)
- **Segment Targeting**: Feature access by user segments
- **Experiment Flags**: A/B and multivariate testing
- **Prerequisite Management**: Flags that depend on other flags

## Installation

```bash
# Install LaunchDarkly Python SDK
pip install launchdarkly-server-sdk

# Verify installation
python -c "from ldclient import LDClient; print('Success')"
```

## Quick Start

```python
from feature_flags.launchdarkly_config import FeatureFlagManager, LDUserContext

# Initialize manager
manager = FeatureFlagManager(
    sdk_key="sdk_key_from_launchdarkly_console",
    environment="production"
)

# Create user context
user = LDUserContext(
    user_id="user_123",
    account_type="customer",
    subscription_tier="premium",
    region="US"
)

# Check boolean flag
if manager.check_flag(user, "enable_instant_booking"):
    show_instant_booking_option()

# Get multivariate flag
pricing_strategy = manager.get_variation(user, "dynamic_pricing", "fixed")
if pricing_strategy == "surge_pricing":
    apply_surge_pricing()

# Track metric for experiments
manager.track_metric(
    user=user,
    metric_key="booking_conversion_rate",
    value=1,
    data={"booking_id": "book_123"}
)
```

## Flag Types

### Boolean Flags

Binary on/off flags for feature control:

```python
if manager.check_flag(user, "escrow_payment_flow"):
    # Use Stripe Connect escrow
    process_escrow_payment()
else:
    # Fallback payment method
    process_simple_payment()
```

### Multivariate Flags

Multiple variations for A/B/C testing or multi-armed bandits:

```python
variation = manager.get_variation(user, "dynamic_pricing", "fixed")

if variation == "fixed":
    price = base_price
elif variation == "surge_pricing":
    price = base_price * surge_multiplier()
elif variation == "demand_based":
    price = ml_pricing_model.predict(user_id)
```

### Percentage Rollout Flags

Gradual rollout from 0% to 100%:

```yaml
enable_instant_booking:
  rollout_schedule:
    week_1: 0%     # Launch disabled
    week_2: 10%    # 10% to beta users
    week_3: 50%    # 50% to all
    week_4: 100%   # Full rollout
```

### Kill Switches

Emergency disable flags for critical features:

```python
if not manager.check_flag(user, "escrow_payment_flow", default=True):
    # Escrow system disabled - fallback immediately
    log_alert("Escrow payment system disabled")
    return fallback_payment_method()
```

## User Context and Targeting

User context contains attributes used for:
- Flag evaluation
- Targeting rule matching
- Segment membership
- Experiment allocation

```python
user = LDUserContext(
    user_id="provider_123",
    account_type="provider",           # customer, provider, operator
    subscription_tier="premium",       # basic, standard, premium, enterprise
    region="US",
    signup_date="2026-01-01",
    total_bookings=25,
    is_verified=True,
    is_new_user=False,
    custom_attributes={
        "gmv_usd": 15000.50,
        "avg_rating": 4.8
    }
)
```

### Custom Attributes

Add custom attributes for advanced targeting:

```python
user.custom_attributes = {
    "gmv_usd": 15000.50,
    "avg_rating": 4.8,
    "verification_method": "checkr",
    "partnership_tier": "gold"
}
```

## Targeting Rules

Flags use targeting rules to control feature access:

```yaml
targeting_rules:
  # Rule 1: Disable for basic tier
  - description: "Disable for low-tier customers"
    conditions:
      - attribute: "subscription_tier"
        operator: "is"
        values: ["basic"]
    variation: "off"
  
  # Rule 2: Enable for enterprise
  - description: "Enable for enterprise operators"
    conditions:
      - attribute: "account_type"
        operator: "equals"
        value: "operator"
    variation: "on"
```

## Creating New Flags

### Step 1: Define in flag_definitions.yaml

```yaml
my_new_flag:
  key: "my_new_flag"
  name: "My New Feature"
  description: "Detailed description"
  kind: "boolean"
  enabled: true
  variations:
    - key: "off"
      name: "Disabled"
      value: false
    - key: "on"
      name: "Enabled"
      value: true
  default_variation: "off"
  targeting_rules: []
  prerequisites: []
  status: "testing"
```

### Step 2: Update launchdarkly_config.py

Add to `FeatureFlagManager.FLAGS` dict:

```python
"my_new_flag": {
    "name": "My New Feature",
    "description": "...",
    "kind": "boolean",
    "variations": [...],
    "status": FlagStatus.TESTING.value,
    # ...
}
```

### Step 3: Create in LaunchDarkly Console

1. Go to LaunchDarkly dashboard
2. Create flag with matching key
3. Configure targeting rules
4. Set initial rollout percentage

### Step 4: Use in Code

```python
if manager.check_flag(user, "my_new_flag"):
    # New feature behavior
    use_new_feature()
else:
    # Old behavior
    use_old_feature()
```

## Best Practices

### 1. Use Descriptive Names

Flag keys should be clear and consistent:
- Good: `enable_instant_booking`, `dynamic_pricing`, `new_search_algorithm`
- Bad: `flag_1`, `test_xyz`, `feature_a`

### 2. Manage Lifecycle

Document flag status in flag_definitions.yaml:
- `planning`: Not yet implemented
- `testing`: Internal testing phase
- `partial_rollout`: Gradual rollout in progress
- `full_rollout`: Enabled for all users
- `permanent`: Permanent feature (can be archived)

### 3. Clean Up Completed Flags

Once flag is at 100% or deprecated, archive it:

```yaml
archived_flags:
  - key: "old_feature_flag"
    archived_date: "2026-03-01"
    reason: "Feature is now permanent"
```

### 4. Handle Prerequisites Correctly

If a flag depends on another:

```python
FLAGS = {
    "dynamic_pricing": {
        "prerequisites": ["enable_instant_booking"],
        # ...
    }
}
```

### 5. Default Values

Always provide sensible defaults:

```python
# With default
enabled = manager.check_flag(user, "new_feature", default=False)

# Without default (may raise exception)
enabled = manager.check_flag(user, "new_feature")
```

### 6. Monitor Kill Switches

Critical features should have always-on kill switches:

```yaml
escrow_payment_flow:
  kill_switch: true
  health_check:
    metric: "payment_error_rate"
    alert_threshold: 0.05
```

## Experiment Flags

Use flags for A/B and multivariate testing:

### A/B Test Example

```yaml
provider_verification_v2:
  kind: "string"
  variations:
    - key: "legacy_manual"
      value: "legacy_manual_review"
      weight: 50
    - key: "automated_checkr"
      value: "automated_plus_checkr"
      weight: 50
  experiment:
    hypothesis: "Automated verification is faster and more accurate"
    duration_days: 21
    metrics:
      - verification_time_hours
      - completion_rate
```

### Implementation

```python
config = manager.get_variation(user, "provider_verification_v2", "legacy")

if config == "automated_plus_checkr":
    verify_with_checkr(provider_id)
else:
    verify_manually(provider_id)

# Track metric for analysis
manager.track_metric(
    user=user,
    metric_key="verification_completion_rate",
    value=1
)
```

## Segment Targeting

Pre-defined segments enable targeting groups of users:

```python
SEGMENTS = {
    "marketplace_power_users": {
        "conditions": {
            "total_bookings": {"gte": 10},
            "account_age_days": {"gte": 90}
        }
    }
}
```

Apply to flags:

```yaml
new_search_algorithm:
  targeting_rules:
    - description: "Enable for power users"
      conditions:
        - attribute: "segment"
          operator: "in"
          values: ["marketplace_power_users"]
      variation: "on"
```

## Monitoring and Alerts

### Health Checks

Configure alerts for critical flags:

```yaml
escrow_payment_flow:
  health_check:
    metric: "payment_error_rate"
    alert_threshold: 0.05  # 5% error = page everyone
```

### Metrics Tracking

Track custom metrics for experiment analysis:

```python
manager.track_metric(
    user=user,
    metric_key="booking_conversion_rate",
    value=1 if success else 0,
    data={
        "booking_id": booking_id,
        "amount_usd": amount,
        "provider_id": provider_id
    }
)
```

## Troubleshooting

### Flag Not Evaluating Correctly

1. Verify flag key matches exactly
2. Check user context has required attributes
3. Verify targeting rules in console
4. Check flag is enabled in console

```python
# Debug flag evaluation
flag_config = manager.get_flag_config("my_flag")
print(f"Flag enabled: {flag_config['enabled']}")
print(f"Targeting rules: {flag_config['targeting_rules']}")
```

### User Not in Expected Segment

1. Check user attributes match segment definition
2. Verify segment condition operators (equals, in, lessThan, etc.)

```python
segment_config = manager.get_segment_config("my_segment")
print(f"Segment conditions: {segment_config['conditions']}")
```

### Flag Changes Not Reflecting

1. SDK must be re-initialized after flag changes
2. Check SDK version is current
3. Verify no local caching issues

## Environment Variables

```bash
# .env
LAUNCHDARKLY_SDK_KEY=sdk_xxx_from_console
LAUNCHDARKLY_ENVIRONMENT=production
LAUNCHDARKLY_LOG_LEVEL=INFO
```

## References

- [LaunchDarkly Documentation](https://docs.launchdarkly.com)
- [Python SDK Reference](https://github.com/launchdarkly/python-server-sdk)
- [Feature Flag Best Practices](https://launchdarkly.com/blog/best-practices-for-feature-flags)
- [Progressive Delivery Guide](https://launchdarkly.com/guides/progressive-delivery)
