"""
Stripe Connect Integration for Verified Services Marketplace
Handles escrow payments, provider payouts, and marketplace fees.
"""

import os
import stripe
import logging
from decimal import Decimal
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from enum import Enum

import asyncpg
from supabase import create_client

logger = logging.getLogger(__name__)

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_ANON_KEY")
)


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


# ============================================================================
# Provider Onboarding: Stripe Connect Account Creation
# ============================================================================


async def onboard_provider_to_stripe(
    provider_id: str,
    email: str,
    business_name: str,
    country: str = "US",
) -> Optional[str]:
    """
    Create a Stripe Connect Express account for a provider.

    Args:
        provider_id: Marketplace provider ID
        email: Provider email address
        business_name: Provider business name
        country: Country of business (default: US)

    Returns:
        Stripe account ID if successful, None otherwise
    """
    try:
        account = stripe.Account.create(
            type="express",
            country=country,
            email=email,
            business_profile={
                "name": business_name,
                "url": f"{os.getenv('MARKETPLACE_BASE_URL')}/providers/{provider_id}",
                "support_phone": os.getenv("MARKETPLACE_SUPPORT_PHONE"),
                "support_email": os.getenv("MARKETPLACE_SUPPORT_EMAIL"),
            },
            tos_acceptance={
                "service_agreement": "recipient",
                "date": int(datetime.utcnow().timestamp()),
                "ip": "127.0.0.1",  # Would be actual user IP in production
            },
            metadata={"provider_id": provider_id},
        )

        # Store Stripe account ID in database
        await supabase.table("providers").update(
            {"stripe_account_id": account.id}
        ).eq("id", provider_id).execute()

        logger.info(f"Created Stripe account {account.id} for provider {provider_id}")
        return account.id

    except stripe.error.StripeError as e:
        logger.error(f"Failed to create Stripe account: {e}")
        return None


async def create_account_link(
    provider_id: str,
    return_url: str,
) -> Optional[str]:
    """
    Create a Stripe Account Link for provider to complete onboarding.

    Args:
        provider_id: Marketplace provider ID
        return_url: URL to redirect after onboarding

    Returns:
        Stripe Account Link URL if successful
    """
    try:
        # Get provider's Stripe account ID
        result = await supabase.table("providers").select(
            "stripe_account_id"
        ).eq("id", provider_id).single().execute()

        stripe_account_id = result.data["stripe_account_id"]

        account_link = stripe.AccountLink.create(
            account=stripe_account_id,
            type="account_onboarding",
            return_url=return_url,
            refresh_url=f"{os.getenv('MARKETPLACE_BASE_URL')}/account/stripe-onboarding",
        )

        logger.info(f"Created account link for provider {provider_id}")
        return account_link.url

    except Exception as e:
        logger.error(f"Failed to create account link: {e}")
        return None


# ============================================================================
# Payment Processing: Escrow Hold
# ============================================================================


async def create_payment_intent_with_escrow(
    customer_id: str,
    provider_id: str,
    request_id: str,
    bid_id: str,
    bid_amount: Decimal,
    platform_fee_rate: Decimal = Decimal("0.15"),
) -> Optional[Dict[str, Any]]:
    """
    Create a Stripe PaymentIntent with escrow and automatic transfer to provider.

    The escrow is held until job completion, then automatically released to
    the provider's connected account via Stripe Transfer.

    Args:
        customer_id: Customer ID
        provider_id: Service provider ID
        request_id: Service request ID
        bid_id: Bid ID
        bid_amount: Amount customer is paying for service (cents)
        platform_fee_rate: Marketplace fee rate (default 15%)

    Returns:
        Payment record dict with Stripe integration details
    """
    try:
        # Fetch provider Stripe account ID
        provider_result = await supabase.table("providers").select(
            "stripe_account_id, platform_fee_rate"
        ).eq("id", provider_id).single().execute()

        stripe_account_id = provider_result.data["stripe_account_id"]
        if not stripe_account_id:
            raise ValueError(f"Provider {provider_id} has no Stripe account")

        # Calculate fees
        bid_amount_cents = int(bid_amount * 100)  # Convert dollars to cents
        platform_fee = int(bid_amount_cents * float(platform_fee_rate))
        amount_to_transfer = bid_amount_cents - platform_fee
        stripe_processing_fee = int(bid_amount_cents * Decimal("0.029") + 30)  # 2.9% + $0.30

        # Create PaymentIntent with transfer_data for automatic split
        payment_intent = stripe.PaymentIntent.create(
            amount=bid_amount_cents,
            currency="usd",
            description=f"Service request {request_id} - {bid_amount} - Platform escrow",
            metadata={
                "customer_id": str(customer_id),
                "provider_id": str(provider_id),
                "request_id": str(request_id),
                "bid_id": str(bid_id),
                "platform_fee": str(platform_fee),
            },
            transfer_data={
                "destination": stripe_account_id,
                "amount": amount_to_transfer,  # Amount after platform fee
            },
            # Hold funds in escrow - don't auto-capture
            capture_method="manual",
            on_behalf_of=stripe_account_id,
        )

        # Insert payment record in database
        payment_data = {
            "request_id": str(request_id),
            "bid_id": str(bid_id),
            "customer_id": str(customer_id),
            "provider_id": str(provider_id),
            "stripe_payment_intent_id": payment_intent.id,
            "amount_total": float(bid_amount),
            "bid_amount": float(bid_amount),
            "customer_fee": 0,  # No customer fee in this model
            "platform_fee": float(Decimal(platform_fee) / 100),
            "provider_payout": float(Decimal(amount_to_transfer) / 100),
            "stripe_processing_fee": float(Decimal(stripe_processing_fee) / 100),
            "status": "pending",
            "payout_status": "pending",
        }

        result = await supabase.table("payments").insert([payment_data]).execute()

        logger.info(
            f"Created PaymentIntent {payment_intent.id} with escrow for request {request_id}"
        )

        return {
            "payment_intent_id": payment_intent.id,
            "client_secret": payment_intent.client_secret,
            "amount": bid_amount_cents,
            "platform_fee": float(Decimal(platform_fee) / 100),
            "provider_payout": float(Decimal(amount_to_transfer) / 100),
        }

    except Exception as e:
        logger.error(f"Failed to create PaymentIntent with escrow: {e}")
        return None


async def confirm_payment_intent(
    payment_intent_id: str,
) -> bool:
    """
    Confirm a PaymentIntent (customer has completed payment).

    Args:
        payment_intent_id: Stripe PaymentIntent ID

    Returns:
        True if successful
    """
    try:
        payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)

        if payment_intent.status not in ["requires_confirmation", "requires_action"]:
            logger.warn(f"PaymentIntent {payment_intent_id} is in unexpected state")
            return False

        confirmed = stripe.PaymentIntent.confirm(payment_intent_id)

        # Update payment status in database
        await supabase.table("payments").update(
            {
                "status": "escrow_held",
                "escrow_held_at": datetime.utcnow().isoformat(),
            }
        ).eq("stripe_payment_intent_id", payment_intent_id).execute()

        logger.info(f"PaymentIntent {payment_intent_id} confirmed and funds held in escrow")
        return True

    except Exception as e:
        logger.error(f"Failed to confirm PaymentIntent: {e}")
        return False


# ============================================================================
# Payment Release: Escrow to Provider
# ============================================================================


async def capture_payment_and_transfer_to_provider(
    payment_intent_id: str,
) -> bool:
    """
    Capture the PaymentIntent (customer charge) and release to provider.

    Called when job is marked complete. Captures the payment and the transfer
    to the provider happens automatically via Stripe's transfer_data.

    Args:
        payment_intent_id: Stripe PaymentIntent ID

    Returns:
        True if successful
    """
    try:
        # Capture the payment intent
        captured = stripe.PaymentIntent.capture(payment_intent_id)

        if captured.status != "succeeded":
            raise ValueError(f"PaymentIntent capture failed: {captured.status}")

        # Get payment record for logging
        result = await supabase.table("payments").select("*").eq(
            "stripe_payment_intent_id", payment_intent_id
        ).single().execute()

        payment = result.data
        provider_id = payment["provider_id"]

        # Get provider's Stripe account
        provider_result = await supabase.table("providers").select(
            "stripe_account_id"
        ).eq("id", provider_id).single().execute()

        stripe_account_id = provider_result.data["stripe_account_id"]

        # The transfer happens automatically via transfer_data
        # But we can verify it completed
        transfers = stripe.Transfer.list(
            destination=stripe_account_id,
            limit=1,
            source_transaction=payment_intent_id,
        )

        transfer_id = transfers.data[0].id if transfers.data else None

        # Update payment status
        await supabase.table("payments").update(
            {
                "status": "captured",
                "captured_at": datetime.utcnow().isoformat(),
                "payout_status": "scheduled",
                "payout_scheduled_at": datetime.utcnow().isoformat(),
                "stripe_transfer_id": transfer_id,
            }
        ).eq("stripe_payment_intent_id", payment_intent_id).execute()

        logger.info(
            f"Captured PaymentIntent {payment_intent_id} and transferred funds to provider"
        )
        return True

    except Exception as e:
        logger.error(f"Failed to capture and transfer payment: {e}")

        # Mark payment as failed
        await supabase.table("payments").update(
            {
                "status": "failed",
            }
        ).eq("stripe_payment_intent_id", payment_intent_id).execute()

        return False


# ============================================================================
# Refunds
# ============================================================================


async def create_refund(
    payment_intent_id: str,
    amount_cents: Optional[int] = None,
    reason: str = "requested_by_customer",
) -> bool:
    """
    Create a refund for a payment (full or partial).

    Args:
        payment_intent_id: Stripe PaymentIntent ID
        amount_cents: Amount to refund in cents (None = full refund)
        reason: Refund reason

    Returns:
        True if successful
    """
    try:
        # Get payment details
        result = await supabase.table("payments").select("*").eq(
            "stripe_payment_intent_id", payment_intent_id
        ).single().execute()

        payment = result.data

        # Create refund
        refund = stripe.Refund.create(
            payment_intent=payment_intent_id,
            amount=amount_cents,
            reason=reason,
            metadata={
                "request_id": payment["request_id"],
                "provider_id": payment["provider_id"],
            },
        )

        # Update payment record
        refund_amount = amount_cents / 100 if amount_cents else payment["amount_total"]
        new_status = (
            "partially_refunded" if amount_cents and amount_cents < int(
                payment["amount_total"] * 100
            ) else "refunded"
        )

        await supabase.table("payments").update(
            {
                "status": new_status,
                "refunded_at": datetime.utcnow().isoformat(),
                "refund_amount": refund_amount,
                "refund_reason": reason,
            }
        ).eq("stripe_payment_intent_id", payment_intent_id).execute()

        logger.info(f"Created refund {refund.id} for PaymentIntent {payment_intent_id}")
        return True

    except Exception as e:
        logger.error(f"Failed to create refund: {e}")
        return False


# ============================================================================
# Dispute Handling
# ============================================================================


async def handle_payment_dispute(
    charge_id: str,
    dispute_id: str,
) -> None:
    """
    Handle Stripe dispute webhook (customer disputes the charge).

    Args:
        charge_id: Stripe charge ID
        dispute_id: Stripe dispute ID
    """
    try:
        # Find related payment
        result = await supabase.table("payments").select("*").eq(
            "stripe_payment_intent_id", charge_id
        ).execute()

        if not result.data:
            logger.warn(f"No payment found for charge {charge_id}")
            return

        payment = result.data[0]

        # Create dispute record in marketplace
        await supabase.table("disputes").insert(
            [
                {
                    "request_id": payment["request_id"],
                    "payment_id": payment["id"],
                    "filed_by": payment["customer_id"],
                    "filed_by_role": "customer",
                    "reason": "other",
                    "description": f"Stripe chargeback/dispute: {dispute_id}",
                    "status": "under_review",
                }
            ]
        ).execute()

        logger.info(f"Created marketplace dispute for Stripe dispute {dispute_id}")

    except Exception as e:
        logger.error(f"Failed to handle payment dispute: {e}")


# ============================================================================
# Payout Management
# ============================================================================


async def update_payout_status(
    payment_id: str,
) -> None:
    """
    Poll Stripe to update payout status.

    Called via cron job to track when payouts actually hit provider bank accounts.

    Args:
        payment_id: Marketplace payment ID
    """
    try:
        # Get payment details
        result = await supabase.table("payments").select("*").eq(
            "id", payment_id
        ).single().execute()

        payment = result.data
        transfer_id = payment["stripe_transfer_id"]

        if not transfer_id:
            logger.warn(f"Payment {payment_id} has no transfer ID")
            return

        # Get transfer details
        transfer = stripe.Transfer.retrieve(transfer_id)

        # Check for associated payout
        if transfer.destination_payment:
            payout = stripe.Payout.retrieve(transfer.destination_payment)

            payout_status_map = {
                "paid": "paid",
                "in_transit": "scheduled",
                "pending": "pending",
                "failed": "failed",
                "canceled": "failed",
            }

            new_status = payout_status_map.get(payout.status, "pending")

            # Update payout status
            await supabase.table("payments").update(
                {
                    "payout_status": new_status,
                    "payout_completed_at": (
                        datetime.fromtimestamp(payout.arrival_date).isoformat()
                        if payout.arrival_date
                        else None
                    ),
                }
            ).eq("id", payment_id).execute()

            logger.info(
                f"Updated payout status for payment {payment_id}: {new_status}"
            )

    except Exception as e:
        logger.error(f"Failed to update payout status: {e}")


async def bulk_update_payout_statuses() -> None:
    """
    Bulk update payout statuses for all pending/scheduled payouts.

    Should be run via cron job every 6 hours.
    """
    try:
        # Get all payments with pending/scheduled payouts
        result = await supabase.table("payments").select("id").in_(
            "payout_status", ["pending", "scheduled"]
        ).execute()

        payment_ids = [p["id"] for p in result.data]

        for payment_id in payment_ids:
            await update_payout_status(payment_id)

        logger.info(f"Updated payout statuses for {len(payment_ids)} payments")

    except Exception as e:
        logger.error(f"Failed to bulk update payout statuses: {e}")


# ============================================================================
# Tax Compliance: 1099 Tracking
# ============================================================================


async def generate_1099_data(
    provider_id: str,
    start_date: datetime,
    end_date: datetime,
) -> Optional[Dict[str, Any]]:
    """
    Generate 1099 tax information for a provider.

    Per IRS requirements, payments >= $20,000 and >= 200 transactions
    require 1099 reporting.

    Args:
        provider_id: Provider ID
        start_date: Period start date
        end_date: Period end date

    Returns:
        Tax data dict with totals and transaction count
    """
    try:
        # Get all paid transactions in period
        result = await supabase.table("payments").select(
            "*"
        ).eq("provider_id", provider_id).eq(
            "payout_status", "paid"
        ).gte(
            "payout_completed_at", start_date.isoformat()
        ).lte(
            "payout_completed_at", end_date.isoformat()
        ).execute()

        payments = result.data

        total_amount = sum(p["provider_payout"] for p in payments)
        transaction_count = len(payments)

        requires_1099 = total_amount >= 20000 and transaction_count >= 200

        return {
            "provider_id": provider_id,
            "period": f"{start_date.year}",
            "total_amount": float(total_amount),
            "transaction_count": transaction_count,
            "requires_1099": requires_1099,
            "box_1a": float(total_amount),  # Gross amount paid
            "box_5b": float(total_amount * Decimal("0.0765")),  # Federal withheld (7.65%)
            "transactions": [
                {
                    "date": p["payout_completed_at"],
                    "amount": p["provider_payout"],
                    "request_id": p["request_id"],
                }
                for p in payments
            ],
        }

    except Exception as e:
        logger.error(f"Failed to generate 1099 data: {e}")
        return None


# ============================================================================
# Webhook Handlers
# ============================================================================


async def handle_stripe_webhook(event: Dict[str, Any]) -> None:
    """
    Handle Stripe webhook events.

    Processes:
    - charge.succeeded: Payment captured
    - charge.failed: Payment failed
    - charge.dispute.created: Chargeback/dispute
    - account.updated: Provider account status change

    Args:
        event: Stripe webhook event
    """
    event_type = event["type"]

    try:
        if event_type == "charge.succeeded":
            # Payment was captured - update status
            charge = event["data"]["object"]
            await supabase.table("payments").update(
                {"status": "captured"}
            ).eq("stripe_payment_intent_id", charge.payment_intent).execute()

        elif event_type == "charge.failed":
            # Payment failed
            charge = event["data"]["object"]
            await supabase.table("payments").update(
                {"status": "failed"}
            ).eq("stripe_payment_intent_id", charge.payment_intent).execute()

        elif event_type == "charge.dispute.created":
            # Chargeback/dispute
            dispute = event["data"]["object"]
            await handle_payment_dispute(dispute.charge, dispute.id)

        elif event_type == "account.updated":
            # Provider account status change
            account = event["data"]["object"]
            provider_id = account.metadata.get("provider_id")

            # Check if charges enabled
            charges_enabled = account.charges_enabled
            payouts_enabled = account.payouts_enabled

            await supabase.table("providers").update(
                {
                    "stripe_account_charges_enabled": charges_enabled,
                    "stripe_account_payouts_enabled": payouts_enabled,
                }
            ).eq("stripe_account_id", account.id).execute()

        logger.info(f"Processed Stripe webhook: {event_type}")

    except Exception as e:
        logger.error(f"Failed to handle Stripe webhook: {e}")
        raise
