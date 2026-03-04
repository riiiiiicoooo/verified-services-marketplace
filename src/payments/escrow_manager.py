"""
Escrow Manager - Reference Implementation
Manages the Stripe Connect escrow payment flow: hold creation on bid acceptance,
capture on job completion, refunds on disputes, and provider payouts.
"""

from dataclasses import dataclass, field
from typing import Optional
from enum import Enum
from datetime import datetime


class PaymentStatus(Enum):
    PENDING = "pending"
    ESCROW_HELD = "escrow_held"
    CAPTURED = "captured"
    PARTIALLY_REFUNDED = "partially_refunded"
    REFUNDED = "refunded"
    FAILED = "failed"
    CANCELLED = "cancelled"


class PayoutStatus(Enum):
    PENDING = "pending"
    SCHEDULED = "scheduled"
    PAID = "paid"
    FAILED = "failed"


@dataclass
class EscrowHold:
    payment_intent_id: str
    transfer_id: Optional[str]
    amount_total: int          # Total charged to customer (cents)
    bid_amount: int            # Original bid amount (cents)
    customer_fee: int          # 5% customer service fee (cents)
    platform_fee: int          # 15% or 12% provider fee (cents)
    provider_payout: int       # bid_amount - platform_fee (cents)
    status: str                # pending, escrow_held, captured, refunded, failed
    escrow_held_at: Optional[datetime] = None
    captured_at: Optional[datetime] = None
    refunded_at: Optional[datetime] = None


@dataclass
class PayoutSummary:
    provider_id: str
    total_earned: int          # Lifetime earnings (cents)
    pending_payout: int        # Captured but not yet paid out (cents)
    in_escrow: int             # Held in escrow (not yet captured) (cents)
    completed_payments: int    # Count of completed payments
    avg_job_payout: int = 0


@dataclass
class StripeAPICall:
    """Mock Stripe API call for reference documentation"""
    method: str
    endpoint: str
    parameters: dict = field(default_factory=dict)
    expected_response: dict = field(default_factory=dict)


# Fee rates
CUSTOMER_FEE_RATE = 0.05       # 5% added to customer's total
STANDARD_PROVIDER_FEE = 0.15   # 15% deducted from provider payout
ELITE_PROVIDER_FEE = 0.12      # 12% for Elite tier providers

# Stripe processing (platform absorbs — see DEC-012)
STRIPE_RATE = 0.029
STRIPE_FIXED = 30  # 30 cents

# 1099 threshold
ANNUAL_1099_THRESHOLD = 60000  # $600 per year


class EscrowManager:
    """
    Manages the complete payment lifecycle on Stripe Connect.

    Flow:
    1. Customer selects bid → Create PaymentIntent with manual capture (escrow hold)
    2. Job completes, customer confirms → Capture payment
    3. Platform fee deducted → Provider receives payout in 3-5 days
    4. If disputed → Hold maintained until resolution → Full/partial refund or capture

    Stripe Connect mode: Platform (us) is merchant of record.
    Providers have Stripe Connected Accounts for payouts.

    Key design choice: Manual capture = escrow.
    We authorize the customer's card but don't charge until job is confirmed complete.
    """

    def __init__(self, stripe_client=None):
        self.stripe = stripe_client

    def create_payment_intent(
        self,
        bid_id: str,
        bid_amount_cents: int,
        customer_stripe_id: str,
        provider_stripe_account_id: str,
        provider_tier: str = "standard",
    ) -> dict:
        """
        Create a Stripe PaymentIntent with manual capture for escrow hold.

        This shows the exact API call structure for Stripe Connect.

        Example: $1,000 bid from Standard provider
        - Customer charged: $1,050
        - Customer fee: $50 (5%)
        - Provider fee: $150 (15%)
        - Provider receives: $850
        - Platform net (after Stripe): ~$169
        """
        customer_fee = int(bid_amount_cents * CUSTOMER_FEE_RATE)
        amount_total = bid_amount_cents + customer_fee

        fee_rate = ELITE_PROVIDER_FEE if provider_tier == "elite" else STANDARD_PROVIDER_FEE
        platform_fee = int(bid_amount_cents * fee_rate)
        provider_payout = bid_amount_cents - platform_fee
        application_fee = customer_fee + platform_fee

        # Exact Stripe API call structure (in production):
        api_call = StripeAPICall(
            method="POST",
            endpoint="/v1/payment_intents",
            parameters={
                "amount": amount_total,
                "currency": "usd",
                "customer": customer_stripe_id,
                "capture_method": "manual",  # KEY: escrow hold
                "transfer_data": {
                    "destination": provider_stripe_account_id,
                    "amount": provider_payout,  # Provider receives this
                },
                "application_fee_amount": application_fee,  # Platform keeps
                "metadata": {
                    "bid_id": bid_id,
                    "bid_amount": bid_amount_cents,
                    "provider_tier": provider_tier,
                },
            },
            expected_response={
                "id": "pi_test_abc123",
                "amount": amount_total,
                "status": "requires_payment_method",
                "capture_method": "manual",
                "transfer_data": {
                    "destination": provider_stripe_account_id,
                },
                "application_fee_amount": application_fee,
            },
        )

        return {
            "api_call": api_call,
            "economics": {
                "bid_amount": bid_amount_cents,
                "customer_pays": amount_total,
                "customer_fee": customer_fee,
                "platform_fee": platform_fee,
                "provider_payout": provider_payout,
            },
        }

    def create_escrow(
        self,
        bid_id: str,
        bid_amount_cents: int,
        customer_stripe_id: str,
        provider_stripe_account_id: str,
        provider_tier: str = "standard",
    ) -> EscrowHold:
        """
        Create an escrow hold when a customer accepts a provider's bid.
        Calculates fee components and simulates Stripe PaymentIntent creation.
        """
        customer_fee = int(bid_amount_cents * CUSTOMER_FEE_RATE)
        amount_total = bid_amount_cents + customer_fee

        fee_rate = ELITE_PROVIDER_FEE if provider_tier == "elite" else STANDARD_PROVIDER_FEE
        platform_fee = int(bid_amount_cents * fee_rate)
        provider_payout = bid_amount_cents - platform_fee

        return EscrowHold(
            payment_intent_id=f"pi_escrow_{bid_id}",
            transfer_id=None,
            amount_total=amount_total,
            bid_amount=bid_amount_cents,
            customer_fee=customer_fee,
            platform_fee=platform_fee,
            provider_payout=provider_payout,
            status="escrow_held",
            escrow_held_at=datetime.utcnow(),
        )

    def hold_funds(
        self,
        payment_intent_id: str,
        amount_cents: int,
    ) -> dict:
        """
        Authorize funds without capturing (place in escrow).

        Stripe API call:
        POST /v1/payment_intents/{payment_intent_id}/confirm
        """
        api_call = StripeAPICall(
            method="POST",
            endpoint=f"/v1/payment_intents/{payment_intent_id}/confirm",
            parameters={},
            expected_response={
                "id": payment_intent_id,
                "amount": amount_cents,
                "status": "succeeded",
                "charges": {
                    "data": [{"id": f"ch_hold_{payment_intent_id}"}]
                },
            },
        )

        return {
            "api_call": api_call,
            "payment_intent_id": payment_intent_id,
            "status": "escrow_held",
            "amount_held_cents": amount_cents,
        }

    def capture_payment(self, payment_intent_id: str, amount_cents: int) -> dict:
        """
        Capture (charge) a held payment when job is confirmed complete.

        Stripe API call:
        POST /v1/payment_intents/{payment_intent_id}/capture
        """
        api_call = StripeAPICall(
            method="POST",
            endpoint=f"/v1/payment_intents/{payment_intent_id}/capture",
            parameters={
                "amount_to_capture": amount_cents,
            },
            expected_response={
                "id": payment_intent_id,
                "amount": amount_cents,
                "amount_capturable": 0,
                "status": "succeeded",
                "charges": {
                    "data": [{"id": f"ch_captured_{payment_intent_id}"}]
                },
            },
        )

        return {
            "api_call": api_call,
            "payment_intent_id": payment_intent_id,
            "status": "captured",
            "amount_captured_cents": amount_cents,
            "captured_at": datetime.utcnow().isoformat(),
        }

    def release_to_provider(
        self,
        payment_intent_id: str,
        provider_stripe_account_id: str,
        provider_payout_cents: int,
        platform_fee_cents: int,
    ) -> dict:
        """
        Transfer funds to provider and retain platform fee.

        This happens automatically after payment is captured, but shown here
        for understanding the exact fund flow.

        Stripe API calls:
        1. Create transfer to provider account (from platform's balance)
        2. Payout automatically scheduled T+3-5 days
        """
        api_call = StripeAPICall(
            method="POST",
            endpoint="/v1/transfers",
            parameters={
                "amount": provider_payout_cents,
                "currency": "usd",
                "destination": provider_stripe_account_id,
                "transfer_group": f"order_{payment_intent_id}",
                "metadata": {
                    "payment_intent": payment_intent_id,
                    "platform_fee": platform_fee_cents,
                },
            },
            expected_response={
                "id": f"tr_{payment_intent_id}",
                "amount": provider_payout_cents,
                "destination": provider_stripe_account_id,
                "status": "succeeded",
            },
        )

        return {
            "api_call": api_call,
            "transfer_id": f"tr_{payment_intent_id}",
            "provider_payout_cents": provider_payout_cents,
            "platform_fee_cents": platform_fee_cents,
            "payout_status": "scheduled",  # Stripe auto-pays in 3-5 days
        }

    def initiate_refund(
        self,
        payment_intent_id: str,
        refund_type: str = "full",
        refund_amount_cents: Optional[int] = None,
        reason: str = "requested_by_customer",
    ) -> dict:
        """
        Handle refunds: full, partial, or split resolution.

        Stripe API: POST /v1/refunds
        """
        params = {
            "payment_intent": payment_intent_id,
            "reason": reason,  # 'requested_by_customer', 'duplicate', etc.
            "metadata": {
                "refund_type": refund_type,
            },
        }

        if refund_type == "partial" and refund_amount_cents:
            params["amount"] = refund_amount_cents

        api_call = StripeAPICall(
            method="POST",
            endpoint="/v1/refunds",
            parameters=params,
            expected_response={
                "id": f"re_{payment_intent_id}",
                "payment_intent": payment_intent_id,
                "amount": refund_amount_cents or 0,
                "status": "succeeded",
                "reason": reason,
            },
        )

        return {
            "api_call": api_call,
            "refund_id": f"re_{payment_intent_id}",
            "refund_type": refund_type,
            "amount_refunded_cents": refund_amount_cents,
            "status": "refunded",
        }

    def handle_payment_errors(self, error_type: str) -> dict:
        """
        Error handling for common payment failures.

        Error types:
        - card_declined: Customer's card was declined
        - insufficient_funds: Not enough balance
        - unverified_account: Provider's Stripe account not verified
        - 3d_secure_required: Requires additional authentication
        """
        error_responses = {
            "card_declined": {
                "code": "card_declined",
                "message": "Your card was declined",
                "decline_code": "generic_decline",
                "recovery": "Try a different payment method",
            },
            "insufficient_funds": {
                "code": "insufficient_funds",
                "message": "Insufficient funds on card",
                "recovery": "Use a different card or payment method",
            },
            "unverified_account": {
                "code": "account_restricted",
                "message": "Provider account not fully verified",
                "recovery": "Provider must complete Stripe verification",
            },
            "3d_secure_required": {
                "code": "authentication_required",
                "message": "3D Secure authentication required",
                "recovery": "Customer must authenticate with their bank",
                "client_secret": "pi_test_secret_xyz",
            },
        }

        return error_responses.get(error_type, {
            "code": "unknown_error",
            "message": "An unknown error occurred",
        })

    def get_provider_earnings(self, provider_id: str, stripe_account_id: str) -> PayoutSummary:
        """
        Get provider's earnings summary from Stripe.

        Stripe API: GET /v1/accounts/{stripe_account_id}/balance
        """
        # In production, queries from database:
        # SELECT SUM(provider_payout) for different payment statuses

        return PayoutSummary(
            provider_id=provider_id,
            total_earned=0,  # From DB: paid payments
            pending_payout=0,  # From DB: captured, not yet paid
            in_escrow=0,  # From DB: escrow_held status
            completed_payments=0,
            avg_job_payout=0,
        )

    def generate_1099_summary(self, provider_id: str, year: int) -> dict:
        """
        Generate 1099 summary for tax reporting.

        IRS requires reporting of providers earning $600+ per year.

        Stripe API: Query all payments for provider in calendar year
        """
        # In production:
        # SELECT SUM(provider_payout) as gross_income
        # FROM payments
        # WHERE provider_id = $1 AND YEAR(captured_at) = $2
        #   AND payout_status = 'paid'

        api_call = StripeAPICall(
            method="GET",
            endpoint=f"/v1/accounts/{provider_id}/balance_transactions",
            parameters={
                "created[gte]": f"{year}-01-01",
                "created[lte]": f"{year}-12-31",
                "type": "net_volume",  # Net after platform fees
            },
            expected_response={
                "data": [
                    {
                        "amount": 850000,  # Provider's earnings in cents
                        "created": 1234567890,
                        "currency": "usd",
                    }
                ],
                "total_count": 120,  # 120 jobs in year
            },
        )

        return {
            "api_call": api_call,
            "year": year,
            "gross_income_cents": 0,  # Would be populated from data
            "should_issue_1099": False,  # True if >= $600
            "is_reportable": False,
            "notes": "Report to IRS if annual earnings >= $600",
        }

    def calculate_platform_economics(self, bid_amount_cents: int, tier: str = "standard") -> dict:
        """
        Calculate full economic breakdown for a single transaction.
        Used for financial reporting and unit economics analysis.

        Example: $1,000 bid, Standard tier
        """
        customer_fee = int(bid_amount_cents * CUSTOMER_FEE_RATE)
        amount_total = bid_amount_cents + customer_fee

        fee_rate = ELITE_PROVIDER_FEE if tier == "elite" else STANDARD_PROVIDER_FEE
        platform_fee = int(bid_amount_cents * fee_rate)
        provider_payout = bid_amount_cents - platform_fee

        gross_platform_revenue = customer_fee + platform_fee
        stripe_fee = int(amount_total * STRIPE_RATE) + STRIPE_FIXED
        net_platform_revenue = gross_platform_revenue - stripe_fee

        return {
            "bid_amount": bid_amount_cents,
            "customer_pays": amount_total,
            "customer_fee": customer_fee,
            "platform_fee_from_provider": platform_fee,
            "provider_receives": provider_payout,
            "gross_platform_revenue": gross_platform_revenue,
            "stripe_processing_fee": stripe_fee,
            "net_platform_revenue": net_platform_revenue,
            "effective_take_rate": round(net_platform_revenue / bid_amount_cents, 4),
            "provider_fee_rate": fee_rate,
            "tier": tier,
        }
