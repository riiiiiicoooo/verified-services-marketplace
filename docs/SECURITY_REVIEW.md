# Security Review: Verified Services Marketplace

**Reviewed:** 2026-03-06
**Scope:** All source files in `src/`, `stripe/`, `clerk/`, `schema/`, `trigger-jobs/`, `n8n/`, `emails/`, `docker-compose.yml`, `.env.example`, `Dockerfile`, `vercel.json`, `feature_flags/`
**Methodology:** Manual static analysis of all application source code, infrastructure configuration, and database schemas.

---

## Executive Summary

This review identified **14 findings** across 5 severity levels. The codebase is a reference/portfolio implementation, so many integrations are stubbed. However, the code that does exist -- particularly in `stripe/marketplace_payments.py`, `clerk/marketplace_auth.ts`, `trigger-jobs/`, and `n8n/` -- contains patterns that would be exploitable in production. The most critical issues are: (1) missing Stripe webhook signature verification, (2) role determination from client-writable Clerk metadata, (3) use of the Supabase anon key for privileged server-side operations, and (4) hardcoded credentials in `docker-compose.yml`.

| Severity | Count |
|----------|-------|
| CRITICAL | 3 |
| HIGH     | 4 |
| MEDIUM   | 5 |
| LOW      | 2 |
| **Total** | **14** |

---

## CRITICAL Findings

### C-1: Missing Stripe Webhook Signature Verification

**Severity:** CRITICAL
**File:** `stripe/marketplace_payments.py`, line 630
**Impact:** An attacker can forge Stripe webhook events to mark payments as captured, create fake disputes, or change provider account statuses -- all without any payment actually occurring.

**Description:**
The `handle_stripe_webhook` function accepts a pre-parsed event dict and trusts it unconditionally. There is no call to `stripe.Webhook.construct_event()` to verify the `Stripe-Signature` header against `STRIPE_WEBHOOK_SECRET`. An attacker who can reach the webhook endpoint can send arbitrary event payloads.

**Code Evidence:**
```python
# stripe/marketplace_payments.py, line 630-643
async def handle_stripe_webhook(event: Dict[str, Any]) -> None:
    """Handle Stripe webhook events."""
    event_type = event["type"]  # Trusted without verification

    try:
        if event_type == "charge.succeeded":
            charge = event["data"]["object"]
            await supabase.table("payments").update(
                {"status": "captured"}
            ).eq("stripe_payment_intent_id", charge.payment_intent).execute()
```

**Fix:**
```python
async def handle_stripe_webhook(request_body: bytes, sig_header: str) -> None:
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    try:
        event = stripe.Webhook.construct_event(
            request_body, sig_header, webhook_secret
        )
    except stripe.error.SignatureVerificationError:
        raise ValueError("Invalid webhook signature")
    # Now proceed with verified event
```

---

### C-2: Role Authorization from Client-Writable `unsafeMetadata`

**Severity:** CRITICAL
**File:** `clerk/marketplace_auth.ts`, lines 41-42, 57-59, 371-372
**Impact:** Any authenticated user can escalate their role to `operator` (full admin), bypassing all authorization checks across the platform.

**Description:**
The `requireRole`, `getUserRole`, and `getMarketplaceSession` functions fall back to reading `user.unsafeMetadata.marketplace_role` when `publicMetadata` is not set. Clerk's `unsafeMetadata` is writable by the client (the user themselves) via the Clerk frontend SDK. A user can set `unsafeMetadata.marketplace_role = "operator"` from their browser and gain full operator privileges.

**Code Evidence:**
```typescript
// clerk/marketplace_auth.ts, lines 40-42
const userRole =
  user.publicMetadata?.marketplace_role ||
  user.unsafeMetadata?.marketplace_role;  // Client-writable!
```

```typescript
// clerk/marketplace_auth.ts, lines 57-59
return (
  (user.publicMetadata?.marketplace_role as UserRole) ||
  (user.unsafeMetadata?.marketplace_role as UserRole) ||  // Client-writable!
  null
);
```

**Fix:**
Remove all references to `unsafeMetadata` for role determination. Only use `publicMetadata` which is only writable via the Clerk Backend API (server-side):

```typescript
const userRole = user.publicMetadata?.marketplace_role;
// Never fall back to unsafeMetadata for authorization decisions
```

---

### C-3: Server-Side Operations Using Supabase Anon Key Instead of Service Role Key

**Severity:** CRITICAL
**Files:**
- `stripe/marketplace_payments.py`, lines 20-23
- `clerk/marketplace_auth.ts`, lines 106-109, 163-165, 393-396, 516-519
- `trigger-jobs/matching_engine.ts`, lines 6-9
- `trigger-jobs/provider_onboarding.ts`, lines 6-9
- `n8n/matching_notification.json` (all `Authorization: Bearer {{ $env.SUPABASE_ANON_KEY }}` headers)
- `n8n/provider_verification.json` (all `Authorization: Bearer {{ $env.SUPABASE_ANON_KEY }}` headers)

**Impact:** Server-side code that needs to bypass Row Level Security (RLS) -- such as payment processing, verification status updates, and cross-user queries -- uses the anon key. If RLS policies are strict (as defined in the migration), these operations will silently fail or return incomplete data. Conversely, if RLS is relaxed to accommodate the anon key, it exposes data to unauthenticated clients.

**Description:**
The Supabase migration at `supabase/migrations/001_initial_schema.sql` correctly enables RLS on all tables. However, all server-side code uses `SUPABASE_ANON_KEY` instead of `SUPABASE_SERVICE_ROLE_KEY`. The anon key is subject to RLS policies and cannot perform cross-tenant operations. Server-side payment processing, verification pipeline updates, and matching engine operations all require service role access.

**Code Evidence:**
```python
# stripe/marketplace_payments.py, lines 20-23
supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_ANON_KEY")  # Should be SUPABASE_SERVICE_ROLE_KEY
)
```

```typescript
// trigger-jobs/matching_engine.ts, lines 6-9
const supabase = createClient(
  process.env.SUPABASE_URL || "",
  process.env.SUPABASE_ANON_KEY || ""  // Should be SUPABASE_SERVICE_ROLE_KEY
);
```

**Fix:**
Use `SUPABASE_SERVICE_ROLE_KEY` for all server-side / backend operations. Reserve `SUPABASE_ANON_KEY` exclusively for client-side (browser) code:

```python
supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
)
```

---

## HIGH Findings

### H-1: Hardcoded Database Credentials in docker-compose.yml

**Severity:** HIGH
**File:** `docker-compose.yml`, lines 11, 50, 75
**Impact:** Default credentials committed to version control. If this compose file is used in any environment beyond local dev, the database and pgAdmin are trivially compromised.

**Description:**
The file contains hardcoded passwords for PostgreSQL and pgAdmin.

**Code Evidence:**
```yaml
# docker-compose.yml, line 11
POSTGRES_PASSWORD: dev_password_123

# docker-compose.yml, line 50
DATABASE_URL: postgresql://marketplace_user:dev_password_123@postgres:5432/marketplace

# docker-compose.yml, lines 74-75
PGADMIN_DEFAULT_EMAIL: admin@marketplace.local
PGADMIN_DEFAULT_PASSWORD: admin
```

**Fix:**
Use environment variable interpolation:
```yaml
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
```
Add a `.env` file to `.gitignore` (already done) and document that credentials must be set before use.

---

### H-2: Missing `os` Import in stripe/marketplace_payments.py

**Severity:** HIGH
**File:** `stripe/marketplace_payments.py`, line 18
**Impact:** The file will crash at import time with `NameError: name 'os' is not defined`. Since this module handles all payment processing, the entire payment system would be non-functional, and the error message could leak stack trace information.

**Description:**
Line 18 calls `os.getenv("STRIPE_SECRET_KEY")` but the `os` module is never imported. This is a runtime error that would prevent the payment module from loading.

**Code Evidence:**
```python
# stripe/marketplace_payments.py, lines 1-18
import stripe
import logging
from decimal import Decimal
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from enum import Enum

import asyncpg
from supabase import create_client

logger = logging.getLogger(__name__)

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")  # os is not imported
```

**Fix:**
Add `import os` to the imports section.

---

### H-3: Hardcoded Loopback IP for Stripe ToS Acceptance

**Severity:** HIGH
**Files:**
- `stripe/marketplace_payments.py`, line 81
- `trigger-jobs/provider_onboarding.ts`, line 345

**Impact:** Stripe requires the actual IP address of the user accepting the Terms of Service for compliance. Using `127.0.0.1` could result in Stripe rejecting the ToS acceptance, or it could constitute a compliance violation under Stripe's service agreement.

**Code Evidence:**
```python
# stripe/marketplace_payments.py, line 81
"ip": "127.0.0.1",  # Would be actual user IP in production
```

```typescript
// trigger-jobs/provider_onboarding.ts, line 345
ip: "127.0.0.1",
```

**Fix:**
Pass the actual client IP address from the HTTP request context:
```python
"ip": request.client.host,  # Pass from API route handler
```

---

### H-4: No Checkr Webhook Signature Verification

**Severity:** HIGH
**File:** `src/verification/provider_verifier.py`, lines 216-261
**Impact:** The Checkr webhook handler trusts incoming webhook data without verifying the HMAC signature. An attacker could forge background check results to make unverified providers appear as "passed", bypassing the entire verification pipeline.

**Description:**
The `handle_checkr_webhook` method directly reads `webhook_data.get("status")` and `webhook_data.get("result")` without any signature validation. Checkr provides HMAC-SHA256 signatures on webhook payloads that should be validated.

**Code Evidence:**
```python
# src/verification/provider_verifier.py, lines 216-231
def handle_checkr_webhook(self, webhook_data: dict) -> VerificationCheck:
    report_status = webhook_data.get("status")
    report_result = webhook_data.get("result")  # Trusted without verification

    if report_result == "clear":
        return VerificationCheck(
            check_type=CheckType.CRIMINAL_BACKGROUND,
            status=CheckStatus.PASSED,  # Attacker can force this
            ...
        )
```

**Fix:**
Verify the Checkr webhook signature before processing:
```python
import hmac
import hashlib

def verify_checkr_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)
```

---

## MEDIUM Findings

### M-1: Stored XSS Risk in Review Comments and Messages

**Severity:** MEDIUM
**Files:**
- `schema/schema.sql`, lines 234 (`comment TEXT`), 329 (`content TEXT`)
- `supabase/migrations/001_initial_schema.sql`, lines 339, 459
- `src/ratings/review_system.py`, line 115 (accepts `comment` parameter without sanitization)

**Impact:** User-supplied text in review comments, provider responses, message content, dispute descriptions, and bid scope-of-work fields could contain malicious HTML/JavaScript. If rendered without escaping in a frontend, this enables stored XSS attacks.

**Description:**
The database schema stores free-text fields (`comment`, `content`, `description`, `scope_of_work`, `provider_response`, `review_notes`, `cancellation_reason`) as raw TEXT without any server-side sanitization. The Python/TypeScript code passes these values through without escaping.

**Fix:**
1. Sanitize all user-generated text at the API layer before storage (strip HTML tags or use an allowlist).
2. Ensure the frontend uses proper output encoding (React's JSX does this by default, but `dangerouslySetInnerHTML` must be avoided).
3. Add a `Content-Security-Policy` header to prevent inline script execution (the `vercel.json` headers are missing CSP).

---

### M-2: Missing Content-Security-Policy Header

**Severity:** MEDIUM
**File:** `vercel.json`, lines 59-80
**Impact:** Without CSP, any XSS vulnerability can execute arbitrary JavaScript, exfiltrate data, or hijack sessions.

**Description:**
The `vercel.json` configuration includes `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, and `Referrer-Policy` headers for API routes, but is missing `Content-Security-Policy`. The `X-XSS-Protection` header is also deprecated in modern browsers and provides no real protection.

**Code Evidence:**
```json
"headers": [
  { "key": "X-Content-Type-Options", "value": "nosniff" },
  { "key": "X-Frame-Options", "value": "DENY" },
  { "key": "X-XSS-Protection", "value": "1; mode=block" },
  { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
  // Missing: Content-Security-Policy
  // Missing: Strict-Transport-Security
]
```

**Fix:**
Add CSP and HSTS headers:
```json
{ "key": "Content-Security-Policy", "value": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://*.supabase.co https://*.stripe.com" },
{ "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains" }
```

---

### M-3: Redis Exposed Without Authentication

**Severity:** MEDIUM
**Files:**
- `docker-compose.yml`, lines 28-41
- `.env.example`, line 105 (`REDIS_PASSWORD=` is empty)

**Impact:** Redis is bound to port 6379 with no password. If the Docker host is network-accessible, any client can connect to Redis, read cached data, or inject malicious data into job queues.

**Description:**
The Redis container has no `--requirepass` argument and the `REDIS_PASSWORD` environment variable in `.env.example` is empty.

**Code Evidence:**
```yaml
# docker-compose.yml, lines 28-34
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"  # Bound to all interfaces
  # No password, no --requirepass
```

```
# .env.example, line 105
REDIS_PASSWORD=
```

**Fix:**
```yaml
redis:
  image: redis:7-alpine
  command: redis-server --requirepass ${REDIS_PASSWORD}
  ports:
    - "127.0.0.1:6379:6379"  # Bind to localhost only
```

---

### M-4: Verification Status Bypass via Direct Database Writes with Anon Key

**Severity:** MEDIUM
**Files:**
- `n8n/provider_verification.json`, lines 307-330 (activate_provider node)
- `trigger-jobs/provider_onboarding.ts`, lines 364-376

**Impact:** Because the n8n workflow and trigger job both use `SUPABASE_ANON_KEY` and the RLS policy `providers_update_own` requires `auth.uid() = auth_user_id`, there is an inconsistency. Either these writes will fail (if RLS is enforced), or a separate non-RLS path exists that could be exploited.

**Description:**
The provider verification pipeline activates providers by setting `verification_status = 'verified'` and `is_active = true`. This is done via the Supabase REST API using the anon key. If the providers table has a permissive RLS policy for inserts/updates (or RLS is not enforced for the service), any authenticated user could potentially set their own `verification_status` to `verified` by crafting a direct Supabase API call.

The RLS policies in the migration only define `SELECT` and `UPDATE` policies for providers, but the `UPDATE` policy (`providers_update_own`) allows any authenticated provider to update their own row. There is no column-level restriction preventing a provider from updating `verification_status` or `is_active` on their own record.

**Code Evidence:**
```sql
-- supabase/migrations/001_initial_schema.sql, lines 626-627
CREATE POLICY providers_update_own ON public.providers
    FOR UPDATE USING (auth.uid() = auth_user_id);
    -- No column restrictions! Provider can update verification_status themselves
```

**Fix:**
Add column-level restrictions to the RLS policy, or use a security definer function for verification status changes:
```sql
CREATE POLICY providers_update_own ON public.providers
    FOR UPDATE USING (auth.uid() = auth_user_id)
    WITH CHECK (
        verification_status = (SELECT verification_status FROM public.providers WHERE auth_user_id = auth.uid())
        AND is_active = (SELECT is_active FROM public.providers WHERE auth_user_id = auth.uid())
    );
```
Alternatively, use a `SECURITY DEFINER` function called only by the service role for verification status transitions.

---

### M-5: Trigger.dev Webhook Endpoint Lacks Authentication

**Severity:** MEDIUM
**File:** `clerk/marketplace_auth.ts`, lines 198-216
**Impact:** The provider creation flow fires a webhook to `TRIGGER_DEV_WEBHOOK_URL` without any HMAC signature or shared secret. If the Trigger.dev webhook URL is discoverable, an attacker can inject fake `provider.created` events to start onboarding pipelines for non-existent providers or trigger excessive Checkr API calls.

**Code Evidence:**
```typescript
// clerk/marketplace_auth.ts, lines 199-216
const triggerDevWebhook = process.env.TRIGGER_DEV_WEBHOOK_URL;
if (triggerDevWebhook) {
  await fetch(triggerDevWebhook, {
    method: "POST",
    headers: { "Content-Type": "application/json" },  // No auth header
    body: JSON.stringify({
      event: "provider.created",
      data: { ... },
    }),
  });
}
```

**Fix:**
Add HMAC signature verification:
```typescript
const signature = crypto
  .createHmac('sha256', process.env.TRIGGER_WEBHOOK_SECRET)
  .update(JSON.stringify(payload))
  .digest('hex');

headers: {
  "Content-Type": "application/json",
  "X-Webhook-Signature": signature,
},
```

---

## LOW Findings

### L-1: PII Logged in Plaintext

**Severity:** LOW
**Files:**
- `stripe/marketplace_payments.py`, line 90: `logger.info(f"Created Stripe account {account.id} for provider {provider_id}")`
- `clerk/marketplace_auth.ts`, line 120: `console.log(\`Created customer account for ${email}\`)`
- `clerk/marketplace_auth.ts`, line 195: `console.log(\`Created provider account for ${email}\`)`
- `trigger-jobs/provider_onboarding.ts`, line 427: `logger.info(\`Verifying trade license: ${state} - ${licenseNumber}\`)`

**Impact:** Email addresses, provider IDs, license numbers, and Stripe account IDs are logged in plaintext. In production, these logs could be stored in log aggregation services (Datadog, Sentry) and become a data exposure vector if those services are compromised.

**Fix:**
Mask PII in log messages:
```typescript
console.log(`Created customer account for ${email.replace(/(.{2}).*@/, '$1***@')}`);
```

---

### L-2: Deprecated FCM Legacy HTTP API Usage

**Severity:** LOW
**Files:**
- `trigger-jobs/matching_engine.ts`, lines 449-466
- `n8n/matching_notification.json`, lines 162-192

**Impact:** The code uses the deprecated FCM legacy HTTP API (`https://fcm.googleapis.com/fcm/send` with `key=` authorization). Google has deprecated this API. The `key=` server key approach also provides less granular access control than OAuth2 tokens used by the v1 API.

**Code Evidence:**
```typescript
// trigger-jobs/matching_engine.ts, lines 449-466
return await axios.post(
  "https://fcm.googleapis.com/fcm/send",
  { to: fcmToken, notification: { ... } },
  { headers: { Authorization: `key=${process.env.FCM_SERVER_KEY}` } }
);
```

**Fix:**
Migrate to the FCM HTTP v1 API (`https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`) with OAuth2 service account authentication.

---

## Additional Observations (Not Scored)

### O-1: No Rate Limiting Visible

No rate limiting middleware or configuration is visible in the codebase. The `vercel.json` does not configure rate limits, and the API layer has no rate limiting guards. This could allow brute-force attacks on endpoints and abuse of Stripe/Checkr API calls.

### O-2: No Input Validation on API Parameters

Functions like `create_payment_intent_with_escrow` accept `bid_amount` as a `Decimal` parameter but do not validate bounds (minimum or maximum). A negative or zero `bid_amount` could create pathological payment states.

### O-3: SQL Injection Not Applicable

The codebase uses parameterized queries (Supabase client SDK with `.eq()`, `.select()`, etc. and PostGIS `$1` parameters). No raw SQL string concatenation was found. SQL injection risk is minimal.

### O-4: File Upload Security Not Assessable

The `verifications` table has a `document_url` field and the `job_photos` table has a `photo_url` field, but no file upload handling code was found in the reviewed source. File upload security (type validation, size limits, malware scanning) should be verified when the upload implementation exists.

### O-5: No CORS Configuration Visible

No CORS configuration was found. If the API is accessed cross-origin, missing or overly permissive CORS headers could allow unauthorized domains to make authenticated requests.

### O-6: Missing `createClient` Import in clerk/marketplace_auth.ts

The `createClient` function from `@supabase/supabase-js` is imported on line 548, after it is used on lines 106, 163, 393, and 516. While TypeScript/JavaScript hoists imports, this unusual ordering suggests the import was added as an afterthought and the file may not have been tested end-to-end.

---

## Remediation Priority

| Priority | Finding | Effort |
|----------|---------|--------|
| 1 | C-1: Add Stripe webhook signature verification | Low |
| 2 | C-2: Remove `unsafeMetadata` from role checks | Low |
| 3 | C-3: Use service role key for server operations | Low |
| 4 | M-4: Add column restrictions to RLS update policy | Medium |
| 5 | H-4: Add Checkr webhook signature verification | Low |
| 6 | H-1: Remove hardcoded credentials from docker-compose | Low |
| 7 | H-2: Add missing `import os` | Low |
| 8 | H-3: Pass real client IP for ToS acceptance | Medium |
| 9 | M-1: Sanitize user-generated text content | Medium |
| 10 | M-2: Add CSP and HSTS headers | Low |
| 11 | M-3: Secure Redis with password and localhost binding | Low |
| 12 | M-5: Add auth to Trigger.dev webhook | Medium |
| 13 | L-1: Mask PII in log messages | Low |
| 14 | L-2: Migrate to FCM v1 API | Medium |
