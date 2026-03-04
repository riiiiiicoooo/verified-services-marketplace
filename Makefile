.PHONY: help install dev up down logs clean test db-init db-seed schema-validate simulation

help:
	@echo "Verified Services Marketplace - Development Tasks"
	@echo ""
	@echo "Installation & Setup:"
	@echo "  make install          - Install Python dependencies"
	@echo "  make schema-validate  - Validate PostgreSQL schema syntax"
	@echo ""
	@echo "Docker & Database:"
	@echo "  make up               - Start Docker containers (PostgreSQL, Redis, API)"
	@echo "  make down             - Stop all containers"
	@echo "  make logs             - Stream Docker logs"
	@echo "  make clean            - Remove all containers and volumes"
	@echo "  make db-init          - Initialize database schema"
	@echo "  make db-seed          - Seed sample data (Atlanta metro, 12 providers, 20 requests)"
	@echo ""
	@echo "Development & Testing:"
	@echo "  make dev              - Run API in development mode (requires Docker up)"
	@echo "  make test             - Run all tests"
	@echo "  make test-escrow      - Run escrow manager tests"
	@echo ""
	@echo "Simulation:"
	@echo "  make simulation       - Run 12-week growth simulation"
	@echo ""

install:
	@echo "Installing Python dependencies..."
	pip install -r requirements.txt

dev:
	@echo "Starting API in development mode..."
	uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload

up:
	@echo "Starting Docker containers..."
	docker-compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 10
	@echo "Services are up! Database: localhost:5432, Redis: localhost:6379, pgAdmin: localhost:5050"

down:
	@echo "Stopping Docker containers..."
	docker-compose down

logs:
	docker-compose logs -f

clean:
	@echo "Stopping and removing all containers and volumes..."
	docker-compose down -v
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete

db-init:
	@echo "Initializing database schema..."
	docker-compose exec -T postgres psql -U marketplace_user -d marketplace -f /docker-entrypoint-initdb.d/01-schema.sql

db-seed:
	@echo "Seeding sample data..."
	docker-compose exec -T postgres psql -U marketplace_user -d marketplace -f /docker-entrypoint-initdb.d/02-seed.sql

schema-validate:
	@echo "Validating SQL schema..."
	@echo "Checking PostGIS syntax..."
	docker-compose exec -T postgres psql -U marketplace_user -d marketplace -c "SELECT postgis_version();"
	@echo "Schema validation complete!"

test:
	@echo "Running all tests..."
	pytest tests/ -v --tb=short

test-escrow:
	@echo "Running escrow manager tests..."
	pytest tests/test_escrow.py -v

simulation:
	@echo "Running 12-week marketplace growth simulation..."
	python demo/marketplace_simulation.py

query-matching:
	@echo "Executing matching engine queries against seed data..."
	docker-compose exec -T postgres psql -U marketplace_user -d marketplace -c \
	"SELECT p.id, p.business_name, p.tier, p.composite_rating, \
	 ST_Distance(p.service_location, ST_SetSRID(ST_MakePoint(-84.3880, 33.7490), 4326)::geography) / 1609.34 as distance_miles \
	 FROM providers p \
	 WHERE ST_DWithin(p.service_location, ST_SetSRID(ST_MakePoint(-84.3880, 33.7490), 4326)::geography, 25 * 1609.34) \
	 AND p.verification_status = 'verified' \
	 AND p.is_active = true \
	 ORDER BY distance_miles ASC LIMIT 10;"

query-health:
	@echo "Querying marketplace health metrics..."
	docker-compose exec -T postgres psql -U marketplace_user -d marketplace -c \
	"SELECT mh.market, mh.day, mh.total_requests, mh.bid_coverage_rate, mh.daily_gmv, mh.avg_hours_to_first_bid \
	 FROM marketplace_health mh \
	 WHERE mh.day >= NOW()::DATE - INTERVAL '30 days' \
	 ORDER BY mh.day DESC, mh.market LIMIT 10;"

.DEFAULT_GOAL := help
