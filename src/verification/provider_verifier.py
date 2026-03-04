"""
Provider Verifier - Reference Implementation
Automated verification pipeline: identity checks (Checkr), license validation
(state APIs), insurance parsing (ACORD forms), and credential expiration monitoring.
"""

from dataclasses import dataclass
from datetime import date, timedelta
from enum import Enum
from typing import Optional


class CheckType(Enum):
    IDENTITY = "identity"
    CRIMINAL_BACKGROUND = "criminal_background"
    TRADE_LICENSE = "trade_license"
    BUSINESS_LICENSE = "business_license"
    GENERAL_LIABILITY = "general_liability_insurance"
    WORKERS_COMP = "workers_comp_insurance"


class CheckStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    PASSED = "passed"
    FAILED = "failed"
    EXPIRED = "expired"
    REQUIRES_MANUAL = "requires_manual_review"


@dataclass
class VerificationCheck:
    check_type: CheckType
    status: CheckStatus
    vendor: Optional[str] = None       # checkr, state_api, manual
    vendor_ref_id: Optional[str] = None
    document_number: Optional[str] = None
    expires_at: Optional[date] = None
    failure_reason: Optional[str] = None


@dataclass
class VerificationResult:
    provider_id: str
    checks: list[VerificationCheck]
    all_passed: bool
    ready_for_operator_review: bool
    blocking_failures: list[str]


# States with licensing board APIs for automated lookup
STATES_WITH_LICENSE_API = {
    "AL", "AZ", "CA", "CO", "CT", "FL", "GA", "IL", "IN", "KY",
    "LA", "MA", "MD", "MI", "MN", "MO", "NC", "NJ", "NV", "NY",
    "OH", "OK", "OR", "PA", "SC", "TN", "TX", "UT", "VA", "WA",
    "WI", "WV", "DC", "HI",
}

# Minimum insurance coverage requirements
INSURANCE_MINIMUMS = {
    "general_liability": 1_000_000,   # $1M per occurrence
    "workers_comp": "state_minimum",   # Varies by state
    "commercial_auto": 500_000,        # $500K combined (if applicable)
}

# Criminal background policy (see Trust Framework Section 3.2)
AUTO_DISQUALIFY_OFFENSES = {
    "felony_violence",       # Any violent felony (no time limit)
    "sex_offense",           # Any sex offense (no time limit)
    "felony_fraud_7yr",      # Fraud/theft felony within 7 years
    "active_warrant",        # Active warrant or pending felony
}


class VerificationPipeline:
    """
    State machine for provider verification pipeline.

    States:
    - pending: Application submitted, no checks started
    - bg_check_pending: Checkr initiated, awaiting results
    - bg_passed: Criminal background check passed
    - license_pending: License verification in progress
    - license_verified: License validated (or manual review passed)
    - insurance_pending: Insurance validation in progress
    - insurance_verified: Insurance validated
    - onboarded: All checks passed, provider active (Standard tier)
    """

    def __init__(self):
        self.state = "pending"
        self.checks_completed = {}

    def advance(self, check_type: str, passed: bool) -> str:
        """Advance state based on completed check."""
        self.checks_completed[check_type] = passed

        if not passed:
            return "rejected"  # Fail fast on any check failure

        # Determine next state based on completed checks
        required_checks = {"identity", "license", "insurance"}
        completed = set(self.checks_completed.keys())

        if completed == required_checks:
            return "onboarded"
        elif "identity" in completed and not completed.issuperset({"license"}):
            return "license_pending"
        elif completed.issuperset({"identity", "license"}) and "insurance" not in completed:
            return "insurance_pending"

        return "checks_in_progress"


class ProviderVerifier:
    """
    Orchestrates the multi-step provider verification pipeline.

    Pipeline:
    1. Identity + criminal background (Checkr) — parallel with steps 2-3
    2. Trade license validation (state API or manual)
    3. Insurance certificate validation (ACORD form parsing)
    4. If all automated checks pass → route to operator manual review queue
    5. Operator approves → provider goes live as Standard tier

    Average total time: 42 hours (24-48h Checkr + parallel license/insurance)
    """

    def __init__(self, checkr_client=None, db_connection=None):
        self.checkr = checkr_client
        self.db = db_connection
        self.pipeline = VerificationPipeline()

    def start_verification(self, provider_id: str, documents: dict) -> VerificationResult:
        """
        Kick off all verification checks for a new provider application.
        Checks run in parallel where possible.

        Args:
            provider_id: Provider being verified
            documents: Dict of uploaded document references
                {
                    "government_id": "storage://path/to/id.pdf",
                    "trade_license": "storage://path/to/license.pdf",
                    "license_number": "PL-12345",
                    "license_state": "GA",
                    "insurance_cert": "storage://path/to/acord.pdf",
                }
        """
        checks = []

        # 1. Identity + Background (Checkr) — async, webhook-based
        identity_check = self._initiate_checkr(provider_id, documents)
        checks.append(identity_check)

        # 2. Trade License — sync if API available, manual otherwise
        license_check = self._verify_license(
            documents.get("license_number"),
            documents.get("license_state"),
        )
        checks.append(license_check)

        # 3. Insurance — sync (ACORD form parsing)
        insurance_check = self._verify_insurance(documents.get("insurance_cert"))
        checks.append(insurance_check)

        # Evaluate results
        all_passed = all(c.status == CheckStatus.PASSED for c in checks)
        blocking = [c.failure_reason for c in checks if c.status == CheckStatus.FAILED and c.failure_reason]
        needs_manual = any(c.status == CheckStatus.REQUIRES_MANUAL for c in checks)

        # Checkr is async — identity check will be IN_PROGRESS at this point
        # Operator review happens after Checkr webhook confirms pass
        ready_for_review = all(
            c.status in (CheckStatus.PASSED, CheckStatus.IN_PROGRESS)
            for c in checks
        )

        return VerificationResult(
            provider_id=provider_id,
            checks=checks,
            all_passed=all_passed,
            ready_for_operator_review=ready_for_review and not blocking,
            blocking_failures=blocking,
        )

    def _initiate_checkr(self, provider_id: str, documents: dict) -> VerificationCheck:
        """
        Start Checkr identity + criminal background check.

        Checkr process:
        1. Create candidate with provider info
        2. Create invitation (provider completes consent form)
        3. Report generated (24-72 hours)
        4. Webhook callback with results

        In production:
        candidate = self.checkr.candidates.create(
            first_name=provider.first_name,
            last_name=provider.last_name,
            email=provider.email,
            ssn=documents.get("ssn"),  # Collected securely, not stored
        )
        invitation = self.checkr.invitations.create(
            candidate_id=candidate.id,
            package="driver_pro",  # Includes identity, criminal, SSN trace
        )
        """
        return VerificationCheck(
            check_type=CheckType.CRIMINAL_BACKGROUND,
            status=CheckStatus.IN_PROGRESS,
            vendor="checkr",
            vendor_ref_id="",  # Set from Checkr API response
        )

    def handle_checkr_webhook(self, webhook_data: dict) -> VerificationCheck:
        """
        Process Checkr webhook callback when background check completes.

        Webhook types we handle:
        - report.completed: Final report ready
        - report.upgraded: Report updated with new information

        Auto-disqualification criteria (see Trust Framework):
        - Felony violence (any timeframe)
        - Sex offense (any timeframe)
        - Felony fraud/theft within 7 years
        - Active warrant or pending felony charge
        """
        report_status = webhook_data.get("status")
        report_result = webhook_data.get("result")  # "clear" or "consider"

        if report_result == "clear":
            return VerificationCheck(
                check_type=CheckType.CRIMINAL_BACKGROUND,
                status=CheckStatus.PASSED,
                vendor="checkr",
                vendor_ref_id=webhook_data.get("id"),
            )

        # "consider" means records found — evaluate against our policy
        records = webhook_data.get("records", [])
        for record in records:
            offense_type = self._classify_offense(record)
            if offense_type in AUTO_DISQUALIFY_OFFENSES:
                return VerificationCheck(
                    check_type=CheckType.CRIMINAL_BACKGROUND,
                    status=CheckStatus.FAILED,
                    vendor="checkr",
                    vendor_ref_id=webhook_data.get("id"),
                    failure_reason=f"Background check: {offense_type}",
                )

        # Records found but none are auto-disqualifying → operator review
        return VerificationCheck(
            check_type=CheckType.CRIMINAL_BACKGROUND,
            status=CheckStatus.REQUIRES_MANUAL,
            vendor="checkr",
            vendor_ref_id=webhook_data.get("id"),
            failure_reason="Background check requires individualized assessment",
        )

    def _classify_offense(self, record: dict) -> str:
        """Classify a criminal record against our background policy."""
        # In production: parse record type, severity, date, disposition
        # and match against AUTO_DISQUALIFY_OFFENSES criteria
        return "none"

    def _verify_license(self, license_number: str, state: str) -> VerificationCheck:
        """
        Verify trade license against state licensing board.

        34 states have APIs for automated lookup. Remaining states
        require manual verification (operator checks state website or calls board).
        """
        if not license_number or not state:
            return VerificationCheck(
                check_type=CheckType.TRADE_LICENSE,
                status=CheckStatus.FAILED,
                failure_reason="License number and state are required",
            )

        if state.upper() in STATES_WITH_LICENSE_API:
            return self._api_license_lookup(license_number, state)
        else:
            return VerificationCheck(
                check_type=CheckType.TRADE_LICENSE,
                status=CheckStatus.REQUIRES_MANUAL,
                vendor="manual",
                document_number=license_number,
                failure_reason=f"No API available for {state}. Manual verification required.",
            )

    def _api_license_lookup(self, license_number: str, state: str) -> VerificationCheck:
        """
        Call state licensing board API to validate license.

        Validates:
        - License exists and is active (not revoked, suspended, or expired)
        - License type matches the service category
        - License holder name matches provider name
        - Expiration date is > 30 days from now

        In production: each state has a different API format.
        We maintain adapters per state in a state_apis/ directory.
        """
        # Reference: simulate a passing check
        return VerificationCheck(
            check_type=CheckType.TRADE_LICENSE,
            status=CheckStatus.PASSED,
            vendor="state_api",
            document_number=license_number,
            expires_at=date.today() + timedelta(days=365),
        )

    def _verify_insurance(self, cert_url: str) -> VerificationCheck:
        """
        Validate insurance certificate (ACORD 25 or 28 form).

        Extracts and validates:
        - Carrier name and AM Best rating
        - Policy number
        - General liability coverage ≥ $1M per occurrence
        - Workers' comp coverage (if provider has employees)
        - Certificate holder / named insured matches provider
        - Policy expiration > 30 days from now

        In production: use OCR or structured extraction to parse ACORD form fields.
        ACORD forms have standardized field positions, making extraction reliable.
        """
        if not cert_url:
            return VerificationCheck(
                check_type=CheckType.GENERAL_LIABILITY,
                status=CheckStatus.FAILED,
                failure_reason="Insurance certificate is required",
            )

        # Reference: simulate ACORD form extraction
        extracted = {
            "carrier": "State Farm",
            "policy_number": "GL-2024-123456",
            "gl_per_occurrence": 1_000_000,
            "gl_aggregate": 2_000_000,
            "named_insured": "Mike's Plumbing LLC",
            "effective_date": "2024-01-01",
            "expiration_date": "2025-01-01",
        }

        # Validate coverage meets minimums
        if extracted["gl_per_occurrence"] < INSURANCE_MINIMUMS["general_liability"]:
            return VerificationCheck(
                check_type=CheckType.GENERAL_LIABILITY,
                status=CheckStatus.FAILED,
                failure_reason=(
                    f"General liability coverage ${extracted['gl_per_occurrence']:,} "
                    f"is below minimum ${INSURANCE_MINIMUMS['general_liability']:,}"
                ),
            )

        expires = date.fromisoformat(extracted["expiration_date"])
        if expires < date.today() + timedelta(days=30):
            return VerificationCheck(
                check_type=CheckType.GENERAL_LIABILITY,
                status=CheckStatus.FAILED,
                expires_at=expires,
                failure_reason="Insurance expires within 30 days. Please upload renewed certificate.",
            )

        return VerificationCheck(
            check_type=CheckType.GENERAL_LIABILITY,
            status=CheckStatus.PASSED,
            document_number=extracted["policy_number"],
            expires_at=expires,
        )

    def parse_acord_certificate(self, certificate_path: str) -> dict:
        """
        Parse ACORD 25/28 insurance certificate form.

        ACORD forms have standardized field positions making OCR/extraction reliable.
        This would use OCR (e.g., Google Cloud Vision, AWS Textract) in production.

        Extracts:
        - Policy holder / named insured
        - Insurance carrier and AM Best rating
        - Policy number
        - Coverage limits (GL, workers comp, etc.)
        - Effective and expiration dates
        """
        # In production: OCR + field extraction
        # For now: simulate extraction from test certificates

        extracted = {
            "named_insured": "Business Name LLC",
            "carrier": "State Farm",
            "am_best_rating": "A++",
            "policy_number": "GL-2024-ABC123",
            "effective_date": date.today(),
            "expiration_date": date.today() + timedelta(days=365),
            "general_liability": {
                "per_occurrence": 1_000_000,
                "aggregate": 2_000_000,
                "product_completed_ops": 2_000_000,
            },
            "workers_comp": {
                "employer_liability": 1_000_000,
                "state_minimum": True,
            },
            "additional_insured": False,
        }

        return extracted

    def validate_license_against_state_db(self, license_number: str, state: str, provider_name: str) -> dict:
        """
        Validate professional license against state licensing board database.

        Checks:
        - License exists and is active (not revoked, suspended, expired)
        - License holder name matches provider name
        - License type is valid for requested service category
        - Expiration date > 30 days from now
        """
        # In production: state-specific API calls
        # Example: Georgia Secretary of State, Texas TDLR, etc.

        validation = {
            "license_number": license_number,
            "state": state,
            "is_valid": True,
            "is_active": True,
            "license_holder": provider_name,
            "name_matches": True,
            "license_type": "Trade License",
            "issued_date": date.today() - timedelta(days=180),
            "expires_date": date.today() + timedelta(days=200),
            "days_until_expiry": 200,
            "is_expiring_soon": False,  # True if < 30 days
            "revoked": False,
            "suspended": False,
        }

        return validation

    def handle_edge_case_background_check(self, webhook_data: dict) -> dict:
        """
        Handle edge cases in background check results.

        Cases:
        - "consider" result: Records found, requires manual assessment
        - Wrong state license: License is for different state than service area
        - Below-minimum coverage: Insurance below $1M threshold
        """
        result = webhook_data.get("result", "clear")

        if result == "consider":
            records = webhook_data.get("records", [])
            # Evaluate each record against policy
            # Return: REQUIRES_MANUAL if none are auto-disqualifying
            return {
                "status": "requires_manual_review",
                "reason": "Background check found records requiring individualized assessment",
                "record_count": len(records),
            }

        if result == "clear":
            return {
                "status": "passed",
                "reason": "No disqualifying records found",
            }

        return {
            "status": "failed",
            "reason": "Background check failed",
        }

    def handle_wrong_state_license(self, provided_state: str, service_state: str) -> dict:
        """
        Handle case where provider's license is from different state.

        Logic:
        - Some trades are multi-state (e.g., national contractor license)
        - Most trades require state-specific licensing
        - Decision: manual operator review
        """
        return {
            "status": "requires_manual_review",
            "reason": f"License from {provided_state} but service in {service_state}",
            "action": "Operator must verify if license valid in service state",
        }

    def handle_below_minimum_insurance(self, coverage_limit: int, minimum: int) -> dict:
        """
        Handle case where insurance is below minimum coverage.

        Compliance requirement: $1M general liability per occurrence minimum.
        """
        return {
            "status": "failed",
            "reason": f"General liability ${coverage_limit:,} below minimum ${minimum:,}",
            "action": "Provider must obtain additional coverage or resubmit",
        }

    def check_expiring_credentials(self, days_ahead: int = 30) -> list[dict]:
        """
        Daily cron job: find providers with credentials expiring within N days.

        Returns list of providers needing reminders, grouped by urgency:
        - 30 days: email reminder
        - 14 days: email + SMS + in-app alert
        - 7 days: email + SMS + push + operator alert
        - 0 days: start 14-day grace period
        - -14 days: auto-suspend

        In production:
        SELECT
            p.id, p.business_name, p.email, p.phone,
            v.check_type, v.expires_at,
            v.reminder_30d_sent, v.reminder_14d_sent, v.reminder_7d_sent,
            EXTRACT(DAY FROM v.expires_at - NOW()) AS days_until_expiry
        FROM verifications v
        JOIN providers p ON p.id = v.provider_id
        WHERE v.status = 'passed'
            AND v.expires_at IS NOT NULL
            AND v.expires_at <= NOW() + INTERVAL '$days_ahead days'
        ORDER BY v.expires_at ASC;
        """
        return []

    def monitoring_expiring_credentials(self) -> dict:
        """
        Monitoring: Daily expiration check with notification/suspension logic.

        Tiering:
        - 30 days out: email reminder
        - 14 days out: email + SMS reminder
        - 7 days out: email + SMS + push + in-app alert
        - At expiry: start 14-day grace period
        - 14+ days expired: auto-suspend provider
        """
        return {
            "monitoring_enabled": True,
            "reminders": {
                "30_days": "email",
                "14_days": "email, sms",
                "7_days": "email, sms, push, in-app",
            },
            "grace_period_days": 14,
            "auto_suspension_days": 14,
        }
