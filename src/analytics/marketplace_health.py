"""
Marketplace Health Analytics - Reference Implementation
Liquidity scoring, Gini coefficient for earnings fairness, composite health
index, and market-level diagnostics.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass
class MarketHealth:
    market: str
    providers_active: int
    weekly_requests: int
    bid_coverage_rate: float        # % of requests with 3+ bids
    fill_rate: float                # % of requests that convert to booking
    avg_hours_to_first_bid: float
    weekly_gmv_cents: int
    provider_utilization: float     # avg % of provider capacity used
    status: str                     # healthy, watch, intervene


@dataclass
class HealthIndex:
    overall_score: float            # 0-100 composite
    liquidity_score: float
    quality_score: float
    supply_score: float
    demand_score: float
    financial_score: float
    interpretation: str             # thriving, healthy, stressed, critical


@dataclass
class EarningsDistribution:
    gini_coefficient: float         # 0 = perfect equality, 1 = one provider earns all
    top_10_pct_share: float         # % of GMV earned by top 10% of providers
    middle_50_pct_share: float
    bottom_40_pct_share: float
    status: str                     # healthy, watch, warning, critical
    recommendation: Optional[str]


# Health index component weights
HEALTH_WEIGHTS = {
    "liquidity": 0.25,
    "quality": 0.25,
    "supply": 0.20,
    "demand": 0.20,
    "financial": 0.10,
}

# Market status thresholds
MARKET_THRESHOLDS = {
    "healthy": {"bid_coverage": 0.80, "fill_rate": 0.55},
    "watch": {"bid_coverage": 0.65, "fill_rate": 0.40},
    # Below "watch" thresholds = "intervene"
}

# Gini coefficient thresholds (see DEC-010 in Decision Log)
GINI_THRESHOLDS = {
    "healthy": (0.30, 0.45),
    "watch": (0.45, 0.50),
    "warning": (0.50, 0.55),
    # Above 0.55 = critical
}

# Health index interpretation bands
HEALTH_BANDS = {
    "thriving": (85, 100),      # Expand to new markets
    "healthy": (70, 84),        # Optimize before expanding
    "stressed": (55, 69),       # Fix weak components
    "critical": (0, 54),        # Pause expansion, stabilize
}


class MarketplaceHealthAnalyzer:
    """
    Calculates marketplace health metrics at the network and market level.

    Reported weekly to product team and monthly to leadership.
    The Health Index (0-100) is the single number that summarizes
    overall marketplace status.

    Key metrics:
    - Liquidity: Are customers getting bids? Are providers getting jobs?
    - Quality: Are customers satisfied? Are disputes low?
    - Supply: Do we have enough verified providers?
    - Demand: Is request volume growing?
    - Financial: Is GMV on track?
    - Fairness: Is earnings distribution healthy (Gini)?
    """

    def __init__(self, db_connection=None):
        self.db = db_connection

    def calculate_health_index(self, metrics: dict) -> HealthIndex:
        """
        Calculate the composite Marketplace Health Index (0-100).

        Components:
        - Liquidity (25%): bid coverage, time to first bid, fill rate
        - Quality (25%): CSAT, dispute rate, no-show rate
        - Supply (20%): active providers, utilization, churn
        - Demand (20%): requests, repeat rate, cancellation rate
        - Financial (10%): GMV growth, revenue, refund rate

        Each component is scored 0-100 independently, then weighted.
        """
        liquidity = self._score_liquidity(
            bid_coverage=metrics.get("bid_coverage_rate", 0),
            time_to_first_bid_hours=metrics.get("avg_hours_to_first_bid", 24),
            fill_rate=metrics.get("fill_rate", 0),
        )

        quality = self._score_quality(
            csat=metrics.get("csat", 0),
            dispute_rate=metrics.get("dispute_rate", 0),
            no_show_rate=metrics.get("no_show_rate", 0),
        )

        supply = self._score_supply(
            active_providers=metrics.get("active_providers", 0),
            utilization=metrics.get("provider_utilization", 0),
            monthly_churn=metrics.get("provider_churn_rate", 0),
        )

        demand = self._score_demand(
            monthly_requests=metrics.get("monthly_requests", 0),
            repeat_rate=metrics.get("repeat_customer_rate", 0),
            cancellation_rate=metrics.get("cancellation_rate", 0),
        )

        financial = self._score_financial(
            gmv_growth_mom=metrics.get("gmv_growth_mom", 0),
            revenue_vs_target=metrics.get("revenue_vs_target", 0),
            refund_rate=metrics.get("refund_rate", 0),
        )

        overall = (
            HEALTH_WEIGHTS["liquidity"] * liquidity
            + HEALTH_WEIGHTS["quality"] * quality
            + HEALTH_WEIGHTS["supply"] * supply
            + HEALTH_WEIGHTS["demand"] * demand
            + HEALTH_WEIGHTS["financial"] * financial
        )

        interpretation = self._interpret_health_score(overall)

        return HealthIndex(
            overall_score=round(overall, 1),
            liquidity_score=round(liquidity, 1),
            quality_score=round(quality, 1),
            supply_score=round(supply, 1),
            demand_score=round(demand, 1),
            financial_score=round(financial, 1),
            interpretation=interpretation,
        )

    def _score_liquidity(
        self,
        bid_coverage: float,
        time_to_first_bid_hours: float,
        fill_rate: float,
    ) -> float:
        """
        Score liquidity component (0-100).

        Score = 100 when: 90%+ coverage, <4h first bid, 60%+ fill
        Score = 50 when: 70% coverage, 8h first bid, 45% fill
        Score = 0 when: <50% coverage, >16h first bid, <30% fill
        """
        coverage_score = self._linear_score(bid_coverage, low=0.50, high=0.90)
        bid_time_score = self._linear_score_inverse(time_to_first_bid_hours, fast=4, slow=16)
        fill_score = self._linear_score(fill_rate, low=0.30, high=0.60)

        # Weighted: coverage matters most for liquidity
        return 0.40 * coverage_score + 0.30 * bid_time_score + 0.30 * fill_score

    def _score_quality(
        self,
        csat: float,
        dispute_rate: float,
        no_show_rate: float,
    ) -> float:
        """
        Score quality component (0-100).

        Score = 100 when: 4.7+ CSAT, <2% disputes, <1% no-shows
        Score = 50 when: 4.3 CSAT, 5% disputes, 3% no-shows
        Score = 0 when: <4.0 CSAT, >8% disputes, >5% no-shows
        """
        csat_score = self._linear_score(csat, low=4.0, high=4.7)
        dispute_score = self._linear_score_inverse(dispute_rate, fast=0.02, slow=0.08)
        no_show_score = self._linear_score_inverse(no_show_rate, fast=0.01, slow=0.05)

        return 0.50 * csat_score + 0.30 * dispute_score + 0.20 * no_show_score

    def _score_supply(
        self,
        active_providers: int,
        utilization: float,
        monthly_churn: float,
    ) -> float:
        """
        Score supply component (0-100).

        Provider utilization has an optimal range (40-70%).
        Too low = providers aren't getting enough work.
        Too high = not enough providers to handle demand.
        """
        provider_score = self._linear_score(active_providers, low=100, high=300)
        churn_score = self._linear_score_inverse(monthly_churn, fast=0.03, slow=0.08)

        # Utilization: optimal range is 40-70%
        if 0.40 <= utilization <= 0.70:
            util_score = 100
        elif 0.20 <= utilization < 0.40 or 0.70 < utilization <= 0.80:
            util_score = 60
        else:
            util_score = 20

        return 0.35 * provider_score + 0.35 * util_score + 0.30 * churn_score

    def _score_demand(
        self,
        monthly_requests: int,
        repeat_rate: float,
        cancellation_rate: float,
    ) -> float:
        """Score demand component (0-100)."""
        request_score = self._linear_score(monthly_requests, low=200, high=800)
        repeat_score = self._linear_score(repeat_rate, low=0.15, high=0.50)
        cancel_score = self._linear_score_inverse(cancellation_rate, fast=0.05, slow=0.15)

        return 0.40 * request_score + 0.35 * repeat_score + 0.25 * cancel_score

    def _score_financial(
        self,
        gmv_growth_mom: float,
        revenue_vs_target: float,
        refund_rate: float,
    ) -> float:
        """Score financial component (0-100)."""
        growth_score = self._linear_score(gmv_growth_mom, low=-0.05, high=0.15)
        revenue_score = self._linear_score(revenue_vs_target, low=0.50, high=1.0)
        refund_score = self._linear_score_inverse(refund_rate, fast=0.02, slow=0.08)

        return 0.40 * growth_score + 0.35 * revenue_score + 0.25 * refund_score

    def _linear_score(self, value: float, low: float, high: float) -> float:
        """Map value to 0-100 scale. Below low = 0, above high = 100, linear between."""
        if value <= low:
            return 0
        if value >= high:
            return 100
        return ((value - low) / (high - low)) * 100

    def _linear_score_inverse(self, value: float, fast: float, slow: float) -> float:
        """Inverse scoring: lower value = higher score (for metrics like dispute rate)."""
        if value <= fast:
            return 100
        if value >= slow:
            return 0
        return ((slow - value) / (slow - fast)) * 100

    def _interpret_health_score(self, score: float) -> str:
        """Convert numeric health score to actionable interpretation."""
        for label, (low, high) in HEALTH_BANDS.items():
            if low <= score <= high:
                return label
        return "critical"

    def calculate_gini_coefficient(self, provider_earnings: list[int]) -> EarningsDistribution:
        """
        Calculate Gini coefficient for provider earnings distribution.

        The Gini coefficient measures earnings inequality across the provider network.
        We track this as a guardrail metric because winner-take-all dynamics
        kill supply-side marketplaces.

        Target range: 0.30-0.45
        - Below 0.30: insufficient differentiation (best providers not rewarded)
        - Above 0.55: extreme concentration (most providers starving)

        Args:
            provider_earnings: List of total earnings (cents) per provider for the period

        Algorithm:
        Gini = (2 * sum(i * y_i)) / (n * sum(y_i)) - (n + 1) / n
        where y_i are sorted earnings and i is the rank (1-indexed)
        """
        if not provider_earnings or len(provider_earnings) < 2:
            return EarningsDistribution(
                gini_coefficient=0,
                top_10_pct_share=0,
                middle_50_pct_share=0,
                bottom_40_pct_share=0,
                status="insufficient_data",
                recommendation="Need at least 2 providers with earnings to calculate distribution",
            )

        sorted_earnings = sorted(provider_earnings)
        n = len(sorted_earnings)
        total = sum(sorted_earnings)

        if total == 0:
            return EarningsDistribution(
                gini_coefficient=0,
                top_10_pct_share=0,
                middle_50_pct_share=0,
                bottom_40_pct_share=0,
                status="no_earnings",
                recommendation=None,
            )

        # Gini calculation
        cumulative_sum = sum((i + 1) * earning for i, earning in enumerate(sorted_earnings))
        gini = (2 * cumulative_sum) / (n * total) - (n + 1) / n
        gini = round(gini, 4)

        # Distribution percentiles
        top_10_idx = max(1, int(n * 0.9))
        bottom_40_idx = max(1, int(n * 0.4))
        middle_start = bottom_40_idx
        middle_end = top_10_idx

        top_10_share = sum(sorted_earnings[top_10_idx:]) / total if total > 0 else 0
        bottom_40_share = sum(sorted_earnings[:bottom_40_idx]) / total if total > 0 else 0
        middle_50_share = sum(sorted_earnings[middle_start:middle_end]) / total if total > 0 else 0

        # Determine status and recommendation
        status, recommendation = self._evaluate_gini(gini, top_10_share)

        return EarningsDistribution(
            gini_coefficient=gini,
            top_10_pct_share=round(top_10_share, 4),
            middle_50_pct_share=round(middle_50_share, 4),
            bottom_40_pct_share=round(bottom_40_share, 4),
            status=status,
            recommendation=recommendation,
        )

    def _evaluate_gini(self, gini: float, top_10_share: float) -> tuple[str, Optional[str]]:
        """
        Evaluate Gini coefficient and provide actionable recommendation.

        See DEC-010 in Decision Log for threshold rationale.
        """
        if 0.30 <= gini <= 0.45:
            return "healthy", None

        if gini < 0.30:
            return "watch", (
                "Earnings distribution is very flat. Top performers may not feel "
                "sufficiently rewarded. Consider increasing tier differentiation."
            )

        if gini <= 0.50:
            return "watch", (
                "Earnings are beginning to concentrate. Monitor which categories "
                "and markets are driving concentration. Consider increasing matching "
                "diversity weight."
            )

        if gini <= 0.55:
            return "warning", (
                "Significant earnings concentration detected. Introduce 'new provider' "
                "boost in matching. Review if specific providers are monopolizing categories. "
                f"Top 10% earning {top_10_share:.0%} of GMV."
            )

        return "critical", (
            "Extreme earnings concentration. Most providers are likely not earning "
            "enough to stay engaged. Active intervention required: reduce max concurrent "
            "for top earners, increase matching radius, review tier criteria. "
            f"Top 10% earning {top_10_share:.0%} of GMV."
        )

    def assess_market_health(self, market_data: dict) -> MarketHealth:
        """
        Assess health of a single market.

        Markets are evaluated independently because each has different
        supply/demand dynamics. A market in "intervene" status gets
        targeted recruitment, radius expansion, and demand routing.
        """
        bid_coverage = market_data.get("bid_coverage_rate", 0)
        fill_rate = market_data.get("fill_rate", 0)

        if (
            bid_coverage >= MARKET_THRESHOLDS["healthy"]["bid_coverage"]
            and fill_rate >= MARKET_THRESHOLDS["healthy"]["fill_rate"]
        ):
            status = "healthy"
        elif (
            bid_coverage >= MARKET_THRESHOLDS["watch"]["bid_coverage"]
            and fill_rate >= MARKET_THRESHOLDS["watch"]["fill_rate"]
        ):
            status = "watch"
        else:
            status = "intervene"

        return MarketHealth(
            market=market_data.get("market", "unknown"),
            providers_active=market_data.get("providers_active", 0),
            weekly_requests=market_data.get("weekly_requests", 0),
            bid_coverage_rate=bid_coverage,
            fill_rate=fill_rate,
            avg_hours_to_first_bid=market_data.get("avg_hours_to_first_bid", 0),
            weekly_gmv_cents=market_data.get("weekly_gmv_cents", 0),
            provider_utilization=market_data.get("provider_utilization", 0),
            status=status,
        )

    def generate_intervention_plan(self, market: MarketHealth) -> list[dict]:
        """
        Generate specific intervention actions for underperforming markets.

        Playbook:
        1. Identify which service categories have coverage gaps
        2. Targeted provider recruitment for those categories
        3. Temporarily expand matching radius by 10 miles
        4. Operator manually routes additional demand
        5. Weekly check-in until sustained 80%+ coverage for 4 weeks
        """
        if market.status == "healthy":
            return []

        actions = []

        if market.bid_coverage_rate < 0.80:
            actions.append({
                "action": "identify_category_gaps",
                "description": f"Analyze which categories in {market.market} have < 80% bid coverage",
                "priority": "high",
                "owner": "operations",
            })
            actions.append({
                "action": "expand_matching_radius",
                "description": f"Temporarily increase matching radius by 10 miles in {market.market}",
                "priority": "high",
                "owner": "engineering",
            })

        if market.providers_active < 15:
            actions.append({
                "action": "targeted_recruitment",
                "description": f"Recruit 10+ providers in {market.market} for underserved categories",
                "priority": "high",
                "owner": "operations",
            })

        if market.provider_utilization < 0.30:
            actions.append({
                "action": "route_demand",
                "description": f"Operator manually routes additional demand to {market.market}",
                "priority": "medium",
                "owner": "operations",
            })

        if market.fill_rate < 0.40:
            actions.append({
                "action": "investigate_conversion",
                "description": f"Analyze why bids in {market.market} aren't converting. Check bid quality, pricing, provider profiles.",
                "priority": "medium",
                "owner": "product",
            })

        return actions
