"""
FastAPI application for Verified Services Marketplace.

Provides:
- Service request CRUD with pagination
- Provider bid management with pagination
- Verification workflow endpoints
- Marketplace analytics
- Health checks and database pooling
"""

import logging
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

from src import db as database

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


# ============================================================================
# Pydantic Models
# ============================================================================

class ServiceRequestSummary(BaseModel):
    """Summary of a service request."""
    id: str
    title: str
    description: str
    customer_id: str
    service_type: str
    status: str
    budget_cents: int
    created_at: datetime
    due_date: Optional[datetime] = None


class ServiceRequestList(BaseModel):
    """Paginated list of service requests."""
    total: int
    skip: int
    limit: int
    items: List[ServiceRequestSummary]


class BidSummary(BaseModel):
    """Summary of a provider bid."""
    id: str
    request_id: str
    provider_id: str
    provider_name: str
    amount_cents: int
    timeline_days: int
    status: str
    submitted_at: datetime


class BidList(BaseModel):
    """Paginated list of bids."""
    total: int
    skip: int
    limit: int
    items: List[BidSummary]


class ProviderVerification(BaseModel):
    """Provider verification status."""
    provider_id: str
    name: str
    status: str
    license_verified: bool
    insurance_verified: bool
    background_check_verified: bool
    overall_tier: str


class ProviderList(BaseModel):
    """Paginated list of verified providers."""
    total: int
    skip: int
    limit: int
    items: List[ProviderVerification]


class ErrorResponse(BaseModel):
    """Standard error response."""
    error: str
    detail: Optional[str] = None


# ============================================================================
# Application Lifespan
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager."""
    # Startup
    logger.info("Starting Verified Services Marketplace API")

    try:
        await database.init_asyncpg_pool()
        logger.info("asyncpg pool initialized")
    except Exception as e:
        logger.warning("Failed to initialize asyncpg pool: %s", str(e))

    try:
        await database.init_sqlalchemy()
        logger.info("SQLAlchemy initialized")
    except Exception as e:
        logger.warning("Failed to initialize SQLAlchemy: %s", str(e))

    yield

    # Shutdown
    logger.info("Shutting down Verified Services Marketplace API")
    try:
        await database.shutdown()
        logger.info("Database connections closed")
    except Exception as e:
        logger.error("Error during database shutdown: %s", str(e))


# ============================================================================
# FastAPI Application
# ============================================================================

app = FastAPI(
    title="Verified Services Marketplace API",
    description="Two-sided marketplace with verified provider network",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Health Checks
# ============================================================================

@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint."""
    db_ok = await database.check_database()
    return {
        "status": "healthy",
        "version": "1.0.0",
        "database": "ready" if db_ok else "unavailable",
    }


@app.get("/health/ready", tags=["Health"])
async def readiness_check():
    """Readiness check endpoint."""
    try:
        db_ok = await database.check_database()
        if db_ok:
            return {"status": "ready"}
        else:
            return {
                "status": "not_ready",
                "error": "Database unavailable",
            }
    except Exception as e:
        logger.error("Readiness check failed: %s", str(e))
        return {
            "status": "not_ready",
            "error": str(e),
        }


# ============================================================================
# Service Requests Endpoints
# ============================================================================

@app.get("/api/v1/requests", response_model=ServiceRequestList, tags=["Requests"])
async def list_service_requests(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(50, ge=1, le=1000, description="Number of records to return"),
    status: Optional[str] = Query(None, description="Filter by request status"),
    customer_id: Optional[str] = Query(None, description="Filter by customer ID"),
):
    """
    List service requests with pagination.

    Returns paginated list of service requests with optional filtering.
    """
    # This is a placeholder implementation.
    # In production, this would query the database:
    # SELECT * FROM service_requests WHERE ... LIMIT limit OFFSET skip
    logger.info(
        "Listing service requests: skip=%d, limit=%d, status=%s, customer=%s",
        skip,
        limit,
        status,
        customer_id,
    )

    # Mock data for demo
    mock_requests = [
        ServiceRequestSummary(
            id=f"REQ_{i:06d}",
            title=f"Service Request {i}",
            description="Sample service request",
            customer_id=customer_id or "CUST_001",
            service_type="general",
            status=status or "open",
            budget_cents=50000,
            created_at=datetime.now(),
        )
        for i in range(1, 11)
    ]

    return ServiceRequestList(
        total=len(mock_requests),
        skip=skip,
        limit=limit,
        items=mock_requests[skip : skip + limit],
    )


# ============================================================================
# Bids Endpoints
# ============================================================================

@app.get("/api/v1/requests/{request_id}/bids", response_model=BidList, tags=["Bids"])
async def list_bids_for_request(
    request_id: str,
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(50, ge=1, le=1000, description="Number of records to return"),
    status: Optional[str] = Query(None, description="Filter by bid status"),
):
    """
    List bids for a specific service request with pagination.

    Returns paginated list of bids from verified providers.
    """
    logger.info(
        "Listing bids for request %s: skip=%d, limit=%d, status=%s",
        request_id,
        skip,
        limit,
        status,
    )

    # Mock data for demo
    mock_bids = [
        BidSummary(
            id=f"BID_{i:06d}",
            request_id=request_id,
            provider_id=f"PROV_{i:04d}",
            provider_name=f"Provider {i}",
            amount_cents=45000 + (i * 1000),
            timeline_days=7 + i,
            status=status or "pending",
            submitted_at=datetime.now(),
        )
        for i in range(1, 6)
    ]

    return BidList(
        total=len(mock_bids),
        skip=skip,
        limit=limit,
        items=mock_bids[skip : skip + limit],
    )


# ============================================================================
# Providers Endpoints
# ============================================================================

@app.get("/api/v1/providers", response_model=ProviderList, tags=["Providers"])
async def list_verified_providers(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(50, ge=1, le=1000, description="Number of records to return"),
    tier: Optional[str] = Query(None, description="Filter by provider tier (elite, preferred, standard)"),
    service_type: Optional[str] = Query(None, description="Filter by service type"),
):
    """
    List verified providers with pagination.

    Returns paginated list of verified service providers.
    """
    logger.info(
        "Listing verified providers: skip=%d, limit=%d, tier=%s, service=%s",
        skip,
        limit,
        tier,
        service_type,
    )

    # Mock data for demo
    mock_providers = [
        ProviderVerification(
            provider_id=f"PROV_{i:06d}",
            name=f"Provider {i}",
            status="active",
            license_verified=True,
            insurance_verified=True,
            background_check_verified=True,
            overall_tier=tier or "standard",
        )
        for i in range(1, 11)
    ]

    return ProviderList(
        total=len(mock_providers),
        skip=skip,
        limit=limit,
        items=mock_providers[skip : skip + limit],
    )


# ============================================================================
# Root Endpoint
# ============================================================================

@app.get("/", tags=["Info"])
async def root():
    """Root endpoint with API documentation."""
    return {
        "name": "Verified Services Marketplace API",
        "version": "1.0.0",
        "description": "Two-sided marketplace with verified provider network",
        "docs": "/docs",
        "endpoints": {
            "health": "/health",
            "requests": "/api/v1/requests?skip=0&limit=50",
            "bids": "/api/v1/requests/{request_id}/bids?skip=0&limit=50",
            "providers": "/api/v1/providers?skip=0&limit=50",
        },
    }


# ============================================================================
# Error Handlers
# ============================================================================

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Handle unexpected exceptions."""
    logger.error(
        "Unhandled exception: %s %s",
        type(exc).__name__,
        str(exc),
    )
    return {
        "error": "Internal server error",
        "detail": str(exc),
    }


if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
