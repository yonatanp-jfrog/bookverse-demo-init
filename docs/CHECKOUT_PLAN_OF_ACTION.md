<!-- markdownlint-disable MD013 -->
# BookVerse Checkout Service – Plan of Action (Central Copy)

This is a read-only synchronized copy of the Checkout plan.
The source of truth lives at:

- `/Users/yonatanp/playground/AppTrust-BookVerse/bookverse-demo/bookverse-checkout/PLAN_OF_ACTION.md`

---

## BookVerse Checkout Service – Plan of Action

## 🎯 Goal

Deliver a minimal-yet-realistic Checkout service that can be tested independently and in integration with `bookverse-inventory`, demonstrating robust service patterns: idempotency, timeouts/retries, compensations, and simple persistence.

## 📦 Scope (MVP)

- REST API
  - POST `/orders` – create an order (idempotent)
  - GET `/orders/{orderId}` – retrieve order
  - GET `/health` – liveness/readiness
- Data persistence: SQLite (via SQLAlchemy) – `orders`, `order_items`, `idempotency_keys`, optional `outbox_events`
- External dependency: `bookverse-inventory`
  - Validate stock via GET `/api/v1/inventory/{book_id}`
  - Adjust stock via POST `/api/v1/inventory/adjust?book_id=...` with body `{ "quantity_change": -qty, "notes": "order:<id>" }`
  - Compensation on failure: POST adjust with positive qty
- Payment: simulated/stub with configurable success ratio
- Idempotency: header `Idempotency-Key` (preferred) or request body `idempotencyKey`
- Observability: structured logs, correlation IDs, basic metrics (timings, counts)

## 🔗 External Contracts (current inventory API)

- GET `/api/v1/inventory/{book_id}` → returns `{ inventory: { quantity_available, ... }, book: {...} }`
- POST `/api/v1/inventory/adjust?book_id=<UUID>` body `{ quantity_change: int, notes?: str }` → reduces available and total simultaneously. We will use:
  - order place: negative change per item (stock_out)
  - compensation: positive change per item (stock_in)

Note: Inventory lacks explicit “reserve/release”. We treat order creation as immediate stock decrement, compensating on payment failure or error.

## 🧠 Domain Model (MVP)

- Order
  - id (uuid), user_id (string/uuid), status: PENDING | CONFIRMED | CANCELLED | PAYMENT_FAILED
  - total_amount (decimal), currency (string, default "USD"), created_at, updated_at
  - idempotency_key (nullable, unique)
- OrderItem
  - id (uuid), order_id (fk), book_id (uuid as string), quantity (int), unit_price (decimal), line_total (decimal)
- IdempotencyKey
  - key (string, pk), order_id (uuid), request_hash (string), created_at
- OutboxEvent (optional, for future eventing)
  - id (uuid), type (string), payload (json), created_at, processed_at (nullable)

## 🧾 API Contracts

- POST `/orders`

  - Headers: `Idempotency-Key: <string>` (recommended)
  - Body:

    ```json
    {
      "userId": "uuid-or-string",
      "items": [
        { "bookId": "uuid", "qty": 1, "unitPrice": 16.99 }
      ]
    }
    ```

  - 201 Created (or 200 on idempotent-replay):

    ```json
    {
      "orderId": "uuid",
      "status": "CONFIRMED",
      "total": 16.99,
      "currency": "USD",
      "items": [{ "bookId": "uuid", "qty": 1, "unitPrice": 16.99, "lineTotal": 16.99 }],
      "createdAt": "2025-01-01T12:00:00Z"
    }
    ```

  - 400/409 examples:
    - `insufficient_stock` with details per `bookId`
    - `validation_error`
    - `idempotency_conflict` when same key used with different request hash
  - 502/504 on upstream inventory failure after retries (compensated if partial adjusts happened)

- GET `/orders/{orderId}` → 200 with same shape as above; 404 if missing

- GET `/health` → `{ status: "healthy", version, timestamp }`

## 🔄 End-to-End Flow (Happy Path)

1) Receive POST `/orders` with `Idempotency-Key`
2) Validate payload (non-empty items, qty > 0, prices ≥ 0)
3) Compute `request_hash` (stable JSON canonicalization) and check `idempotency_keys`:
   - New key → reserve row mapping to a new `order_id`
   - Existing key with same `request_hash` → return existing order (200)
   - Existing key with different `request_hash` → 409 `idempotency_conflict`
4) Pre-check stock per item via inventory GET; collect any `insufficient_stock` and fail fast if any
5) Start DB transaction for order rows
6) Insert `orders` (PENDING) + `order_items`
7) For each item, call inventory adjust (negative). If any adjust fails:
   - Attempt to compensate prior successful adjusts with positive adjusts
   - Mark order `CANCELLED` and return 409/400 with reason
8) Simulate payment (stub):
   - If fail: compensate all adjusts with positive quantities; set `PAYMENT_FAILED`; return 400 with `payment_failed`
   - If success: set `CONFIRMED` and total_amount
9) Optionally enqueue `order.created` outbox event
10) Commit and respond 201

## 🧩 Algorithmic Details

- Idempotency handling

  ```python
  def upsert_idempotency(key: str, request_hash: str) -> IdempotencyDecision:
      entry = repo.find_key(key)
      if not entry:
          order_id = uuid4()
          repo.insert_key(key, order_id, request_hash)
          return { "decision": "proceed", "order_id": order_id }
      if entry.request_hash != request_hash:
          return { "decision": "conflict" }
      return { "decision": "replay", "order_id": entry.order_id }
  ```

- Stock pre-check

  ```python
  def precheck_stock(items):
      failures = []
      for it in items:
          inv = inventory.get(book_id=it.book_id)
          if inv.inventory.quantity_available < it.qty:
              failures.append({ "bookId": it.book_id, "available": inv.inventory.quantity_available, "requested": it.qty })
      if failures:
          raise InsufficientStock(failures)
  ```

- Adjust with compensation and retry

  ```python
  def adjust_with_compensation(order_id, items):
      adjusted = []
      for it in items:
          try:
              inventory.adjust(book_id=it.book_id, change=-it.qty, notes=f"order:{order_id}")
              adjusted.append(it)
          except UpstreamError:
              for done in reversed(adjusted):
                  try:
                      inventory.adjust(book_id=done.book_id, change=done.qty, notes=f"compensate:{order_id}")
                  except Exception:
                      log.error("compensation_failed", extra={"order_id": order_id, "book_id": done.book_id})
              raise
  ```

- Payment stub

  ```python
  def process_payment(order):
      # configurable success ratio via env, default 1.0
      return random.random() < PAYMENT_SUCCESS_RATIO
  ```

- HTTP client policy for inventory
  - Timeout: 1s connect, 2s total
  - Retries: 2 with exponential backoff (only on 5xx/connect timeouts), idempotent
  - Circuit-breaker (optional later)

## 🧪 Testing Strategy

- Unit tests
  - Idempotency decisions
  - Stock pre-check logic
  - Adjust-with-compensation behavior (mock inventory client)
  - Order totals calculation
  - Payment stub outcomes
- Contract tests (inventory)
  - Against a locally running `bookverse-inventory` or via httpx mocking using recorded responses
- Integration tests
  - docker-compose up inventory + checkout; place an order; verify inventory reduced; failure path compensates
- Edge cases
  - Duplicate idempotency key same payload → 200 replay
  - Duplicate key different payload → 409 conflict
  - Partial failure during adjusts → compensations executed
  - Payment failure → compensations executed

## ⚙️ Configuration

- `INVENTORY_BASE_URL` (e.g., `http://localhost:8001`)
- `REQUEST_TIMEOUT_SECONDS` (default 2)
- `RETRY_ATTEMPTS` (default 2)
- `PAYMENT_SUCCESS_RATIO` (0.0–1.0, default 1.0)
- `DATABASE_URL` (default sqlite:///./checkout.db)
- `LOG_LEVEL` (INFO)

## 🔧 Workflows & CI/CD updates (lessons from Inventory)

Carry over the proven CI structure and practices from `bookverse-inventory` and adapt to Checkout:

- Triggers/permissions
  - Keep `workflow_dispatch` during early demo; later enable `push`/PR triggers
  - Permissions: `id-token: write`, `contents: read`
- OIDC and identity
  - Use JFrog CLI OIDC with provider `github-bookverse-checkout`
  - Application key: `bookverse-checkout`
- Versioning and build info
  - Resolve next SemVer by querying AppTrust application versions; use as `IMAGE_TAG` and `APP_VERSION`
  - Consistent Build Info naming and number; publish build info
- Dependency resolution
  - Configure pip to use `${PROJECT_KEY}-pypi-virtual`, with public PyPI fallback if needed
- Docker build/publish
  - Build via `jf docker build`; push via `jf docker push`
  - Image name: `${REGISTRY_URL}/${PROJECT_KEY}-checkout-docker-internal-local/checkout:${IMAGE_TAG}`
  - Verify manifest via Docker V2 API after push
- Evidence attachments
  - Coverage (pytest) attached to image; compute and export coverage percent
  - SAST (placeholder), Sonar quality gate (placeholder), License compliance (placeholder)
  - Remove legacy verified-only flow; attach evidence in main pipeline
- AppTrust application version
  - Create version with build sources; attach SLSA and Jira templates for UNASSIGNED (gate to DEV)
  - Emit GitHub step summary with highlights
- Diagnostics
  - HTTP debug helper with sanitized headers and optional project header
  - Environment/registry pings for early failure surfacing

## 📦 Multi-artifact application version (for CI/CD showcase)

To demonstrate richer pipelines, the Checkout service will produce multiple container images and additional non-image artifacts that are all referenced by a single AppTrust application version.

- Docker images
  - `checkout` (API): main FastAPI service
  - `checkout-worker`: background worker that dispatches `order.created` from an outbox table (idempotent sender)
  - `checkout-migrations`: init/job image that applies DB migrations on startup (Alembic-ready even if SQLite is used in the demo)
  - `mock-payment` (optional): ephemeral mock payment gateway used in integration tests (still built/pushed for artifact governance)

- Non-image artifacts
  - OpenAPI schema export: `openapi.json` (built at CI and uploaded)
  - Event contract schema: `order.created.schema.json`
  - Per-service Helm chart `.tgz` for internal testing (platform remains the deployable chart)
  - Config bundle: `checkout-config.bundle.tar.gz` (sample env, defaults, feature flags)
  - Test dataset and docker-compose for local E2E: `compose.checkout-e2e.yaml`

- AppTrust application version contents
  - Bind all images pushed in the build (API, worker, migrations[, mock-payment])
  - Attach non-image artifacts as binary packages or as build artifacts via Build Info
  - Attach evidence to at least the API image; optionally replicate evidence to worker/migrations for parity

- CI implications (incremental changes)
  - Build/push multiple images with the same `APP_VERSION` tag
  - Verify manifests for each image
  - Publish Build Info with separate modules for each image build
  - Package and upload non-image artifacts, then include them in the Build Info and/or directly in the AppTrust version

## 🧭 Sequence (Mermaid)

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant CO as Checkout
  participant INV as Inventory

  C->>CO: POST /orders (Idempotency-Key, items)
  CO->>CO: validate + idempotency check
  CO->>INV: GET /inventory/{book_id} (for each item)
  INV-->>CO: availability
  CO->>INV: POST /inventory/adjust (-qty per item)
  INV-->>CO: adjusted
  CO->>CO: simulate payment
  alt payment success
    CO->>CO: set status CONFIRMED; enqueue order.created
    CO-->>C: 201 Created (order)
  else payment failure
    CO->>INV: POST /inventory/adjust (+qty per item) (compensate)
    INV-->>CO: adjusted
    CO-->>C: 400 payment_failed
  end
```

## 🧱 Implementation Tasks (TODO)

- Project bootstrap
  - [ ] Add app skeleton: `app/main.py`, routers, settings, models, schemas
  - [ ] Add SQLite models: `orders`, `order_items`, `idempotency_keys`, `outbox_events`
  - [ ] Add migration or auto-create tables on startup (demo-simple)
- API & business logic
  - [ ] Implement POST `/orders` with idempotency and compensation
  - [ ] Implement GET `/orders/{id}`
  - [ ] Implement GET `/health`
  - [ ] Compute totals from `items` (qty × unitPrice)
  - [ ] Correlation IDs and structured logging
- Inventory client
  - [ ] HTTP client with timeouts, retries, and backoff
  - [ ] `get_inventory(book_id)` and `adjust(book_id, change, notes)`
  - [ ] Error taxonomy (4xx vs 5xx) and retry policy
- Payment stub
  - [ ] Configurable success ratio + deterministic override for tests
- Tests
  - [ ] Unit tests: idempotency, stock check, compensation, totals, payment stub
  - [ ] Contract tests with inventory (mocked and live)
  - [ ] Integration test via docker-compose (inventory + checkout)
- Ops & docs
  - [ ] README run instructions (local and Docker)
  - [ ] OpenAPI docs polish and examples
  - [ ] CI: test → build → SBOM/sign → publish (reuse inventory workflow pattern)
- Workflows & CI/CD
  - [ ] Create `.github/workflows/ci.yml` mirroring inventory jobs (build-test-publish, create-application-version)
  - [ ] Configure OIDC provider `github-bookverse-checkout`; `id-token: write`, `contents: read`
  - [ ] Implement SemVer resolver for `APPLICATION_KEY=bookverse-checkout`; set `IMAGE_TAG` and `APP_VERSION`
  - [ ] Name Docker image `${REGISTRY_URL}/${PROJECT_KEY}-checkout-docker-internal-local/checkout:${IMAGE_TAG}`
  - [ ] Use JFrog pip virtual (`${PROJECT_KEY}-pypi-virtual`) with fallback to public PyPI
  - [ ] Attach evidence: coverage (pytest), SAST placeholder, Sonar placeholder, License placeholder
  - [ ] Verify pushed image manifest via Artifactory Docker API
  - [ ] Publish Build Info and add GitHub step summary
  - [ ] Include HTTP request debug helper used in inventory workflow
  - [ ] Document required `vars` and `secrets` in README (JFROG_URL, PROJECT_KEY, DOCKER_REGISTRY, EVIDENCE_KEY_ALIAS, tokens)
