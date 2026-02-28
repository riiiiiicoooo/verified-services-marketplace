"""
Escrow Manager - Reference Implementation
Manages the Stripe Connect escrow payment flow: hold creation on bid acceptance,
capture on job completion, refunds on disputes, and provider payouts.
"""

from dataclasses import dataclass
from typing import Optional


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


@dataclass
class PayoutSummary:
    provider_id: str
    total_earned: int          # Lifetime earnings (cents)
    pending_payout: int        # Captured but not yet paid out (cents)
    in_escrow: int             # Held in escrow (not yet captured) (cents)
    completed_payments: int    # Count of completed payments


# Fee rates
CUSTOMER_FEE_RATE = 0.05       # 5% added to customer's total
STANDARD_PROVIDER_FEE = 0.15   # 15% deducted from provider payout
ELITE_PROVIDER_FEE = 0.12      # 12% for Elite tier providers

# Stripe processing (platform absorbs — see DEC-012)
STRIPE_RATE = 0.029
STRIPE_FIXED = 30  # 30 cents


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

        Calculates all fee components and creates a Stripe PaymentIntent
        with manual capture (capture_method='manual').

        Example: $1,000 bid from a Standard tier provider
        - Customer pays: $1,050 (bid + 5% fee)
        - Platform keeps: $200 ($50 customer fee + $150 provider fee)
        - Provider receives: $850
        - Stripe processing: ~$30.75 (absorbed by platform)
        - Net platform revenue: ~$169.25
        """
        # Calculate fee components
        customer_fee = int(bid_amount_cents * CUSTOMER_FEE_RATE)
        amount_total = bid_amount_cents + customer_fee

        fee_rate = ELITE_PROVIDER_FEE if provider_tier == "elite" else STANDARD_PROVIDER_FEE
        platform_fee = int(bid_amount_cents * fee_rate)
        provider_payout = bid_amount_cents - platform_fee

        # Application fee = customer fee + provider fee (what platform retains)
        application_fee = customer_fee + platform_fee

        # In production:
        # payment_intent = self.stripe.PaymentIntent.create(
        #     amount=amount_total,
        #     currency="usd",
        #     customer=customer_stripe_id,
        #     capture_method="manual",  # THIS IS THE ESCROW — authorize but don't charge
        #     transfer_data={
        #         "destination": provider_stripe_account_id,  # Provider's Connected Account
        #     },
        #     application_fee_amount=application_fee,  # Platform's cut
        #     metadata={
        #         "bid_id": bid_id,
        #         "bid_amount": bid_amount_cents,
        #         "customer_fee": customer_fee,
        #         "platform_fee": platform_fee,
        #         "provider_payout": provider_payout,
        #         "provider_tier": provider_tier,
        #     },
        # )

        return EscrowHold(
            payment_intent_id="",  # From Stripe response
            transfer_id=None,
            amount_total=amount_total,
            bid_amount=bid_amount_cents,
            customer_fee=customer_fee,
            platform_fee=platform_fee,
            provider_payout=provider_payout,
            status="escrow_held",
        )

    def capture_payment(self, payment_intent_id: str) -> EscrowHold:
        """
        Capture (charge) a held payment when the customer confirms job completion.

        This is the moment the customer's card is actually charged and the
        provider's payout is scheduled.

        In production:
        payment_intent = self.stripe.PaymentIntent.capture(payment_intent_id)

        After capture:
        - Customer's card is charged the full amount
        - Platform fee is retained in our Stripe account
        - Provider payout is scheduled (Stripe automated payouts, T+3-5 days)
        """
        # In production:
        # captured = self.stripe.PaymentIntent.capture(payment_intent_id)
        # return EscrowHold(
        #     payment_intent_id=captured.id,
        #     transfer_id=captured.transfer,
        #     status="captured",
        #     ...
        # )

        return EscrowHold(
            payment_intent_id=payment_intent_id,
            transfer_id=None,
            amount_total=0,
            bid_amount=0,
            customer_fee=0,
            platform_fee=0,
            provider_payout=0,
            status="captured",
        )

    def refund_full(self, payment_intent_id: str, reason: str) -> dict:
        """
        Full refund: release the escrow hold entirely.
        Customer is not charged. Provider receives nothing.

        Used when:
        - Provider no-show
        - Operator rules in customer's favor in dispute
        - Job cancelled before work begins

        In production:
        # If payment was only authorized (not captured), cancel the PaymentIntent
        self.stripe.PaymentIntent.cancel(payment_intent_id)

        # If already captured, create a refund
        self.stripe.Refund.create(
            payment_intent=payment_intent_id,
            reason="requested_by_customer",
            metadata={"dispute_reason": reason},
        )
        """
        return {
            "payment_intent_id": payment_intent_id,
            "refund_type": "full",
            "reason": reason,
            "status": "refunded",
        }

    def refund_partial(
        self,
        payment_intent_id: str,
        refund_amount_cents: int,
        reason: str,
    ) -> dict:
        """
        Partial refund: capture a reduced amount.

        Used when operator rules a partial refund in a dispute.
        Example: $1,000 job, work was 60% complete → capture $600, refund $400.

        In production (if not yet captured):
        # Capture the reduced amount
        self.stripe.PaymentIntent.capture(
            payment_intent_id,
            amount_to_capture=reduced_amount,
        )

        In production (if already captured):
        self.stripe.Refund.create(
            payment_intent=payment_intent_id,
            amount=refund_amount_cents,
            metadata={"dispute_reason": reason},
        )
        """
        return {
            "payment_intent_id": payment_intent_id,
            "refund_type": "partial",
            "refund_amount": refund_amount_cents,
            "reason": reason,
            "status": "partially_refunded",
        }

    def get_provider_earnings(self, provider_stripe_account_id: str) -> PayoutSummary:
        """
        Get provider's earnings summary for their dashboard.

        Queries:
        - Total earned (lifetime captured payments to their account)
        - Pending payout (captured but not yet deposited)
        - In escrow (authorized but not yet captured)
        - Completed payment count

        In production:
        # Balance for the connected account
        balance = self.stripe.Balance.retrieve(
            stripe_account=provider_stripe_account_id,
        )
        # available = balance.available[0].amount (ready for payout)
        # pending = balance.pending[0].amount (captured, processing)
        """
        return PayoutSummary(
            provider_id="",
            total_earned=0,
            pending_payout=0,
            in_escrow=0,
            completed_payments=0,
        )

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
