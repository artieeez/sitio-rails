# Port Inventory (source: sitio-monorepo, NestJS + React)

Snapshot taken 2026-07-15 while planning the Rails port. This is the parity checklist for `.specs/project/ROADMAP.md`. Source of truth for details remains `sitio-monorepo` until cutover.

## Backend domains (apps/backend/src/modules)

| Module | Endpoints | Role | Rails equivalent |
|---|---|---|---|
| auth | 0 controllers | Global `AuthGuard` + `RolesGuard`; reads TinyAuth `Remote-*` headers; no login API | In-app `Session`/`User` model, `has_secure_password`, admin/member roles (ADR-002) |
| school | 8 | CRUD schools; activate/deactivate; delete-eligibility; optional Wix collection link | `SchoolsController` + nested resources |
| trip | 7 | List/create under school; get/patch/delete; passenger-status aggregates; delete-eligibility; expiration scheduler | `TripsController` nested under School; scheduled job for expiration |
| passenger | 4 | List/create on trip; patch; soft-remove; `manual-paid-without-info` | `PassengersController` nested under Trip |
| payment | 4 | List/create payments per passenger; patch/delete by id (minor units) | `PaymentsController` nested under Passenger |
| wix-integration | 9 admin + 1 public | Tenant Wix keys/sites; catalog autocomplete/get; media upload URL; webhook config; public JWT webhook ingest + async queue | `WixIntegration` model (singleton); `Webhooks::WixController` (public, JWT-verified); Solid Queue job |
| metadata | 1 | `POST /metadata/fetch-page` — scrape title/favicon for school form | Small controller + scraping service |
| health | 1 | `GET /health`, Prometheus `/metrics` | Rails health check route + metrics |

~34 HTTP actions total today.

## Data model (Prisma → Rails equivalent, all UUID PKs except WixIntegration)

| Model | Key relations | Notes |
|---|---|---|
| School | has_many :trips | optional unique `wix_collection_id`, `active`, `wix_visible` |
| Trip | belongs_to :school, has_many :passengers | optional unique `wix_product_id` + slug/media, `default_expected_amount_minor`, `expiration_date` |
| Passenger | belongs_to :trip, has_many :payments | CPF unique per trip incl. soft-deleted, `manual_paid_without_info`, `needs_review`, `removed_at` |
| Payment | belongs_to :passenger | `amount_minor`, optional unique `wix_transaction_id` (dedup key) |
| WixIntegration | singleton row | `site_id`, `public_key`, `private_api_key` |
| WixEvent | webhook inbox | `event_type`, `wix_entity_id`, `status` (pending/processing/completed/failed), raw event JSON |
| AuditLog | mutating HTTP trail | `user_id`/email/name, action, resource, IP |

No User/Role tables exist in Nest today — this is new in Rails per ADR-002.

## Dashboard routes (apps/dashboard, TanStack) → Hotwire pages

- `/` → redirect to last/first school or new-school
- `/schools`, `/schools/new`, `/schools/$id`, `/schools/$id/edit` → school directory + form
- `/schools/$id/trips`, `.../trips/new`, `.../trips/$tripId` → trip list/create/summary
- `.../passengers`, `.../passengers/new`, `.../passengers/$id/edit` → passenger CRUD
- `.../payments`, `.../payments/new`, `.../payments/$id/edit` → payment CRUD
- `/trips/$tripId/*` → same trip workspace, alternate URL tree (collapse into one nested-resource tree in Rails)
- `/integrations/wix`, `/integrations/wix/configuration`, `/integrations/wix/$eventId` → admin Wix config + event detail (event detail is fixture-only today, not wired to a real API)

UI copy is Portuguese (pt-BR) — carry over.

## Wix integration behavior to preserve

- Inbound public webhook: JWT-verified body → persist `WixEvent` → async queue → handler
  - Collection Created/Changed/Deleted → School create/update/deactivate
  - Product Created/Changed/Deleted → Trip create/update/deactivate
  - PaymentEvent (Cashier v3) → resolve order → line items → auto-create School/Trip if missing → auto-create Passenger (match by CPF) → auto-create Payment (dedup by `wixTransactionId`)
- Outbound `WixApiService`: Stores Catalog v1 CRUD/query, eCom orders, site list, media upload URL
- Graceful no-crash behavior when Wix API key not configured (log + skip)

## Auth today (to be replaced per ADR-002)

- Edge: Traefik + TinyAuth/OIDC; Nest itself does not issue sessions
- `AuthGuard` maps `Remote-User`/`Remote-Groups`/`Remote-Email`/`Remote-Name` → `request.user` (prod/staging only)
- `RolesGuard`: default group required; `@Roles(ADMIN_ROLE)` gates Wix config + media upload URL
- Mutating requests audit-logged with user id or `"system"` (webhooks)

## Testing today

- Backend: Jest + Supertest e2e, co-located specs, coverage floor ~5% (known gap, not a target to replicate)
- Dashboard: Vitest + Testing Library, ~44% statements
- Rails will use RSpec (request specs + model specs) — see ROADMAP.md gates per milestone
