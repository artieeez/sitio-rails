# Roadmap

**Current Milestone:** M5 — Cutover
**Status:** M4 complete (AD-009). Admin Wix config UI (`Admin::WixIntegrationsController`, site picker, webhook docs, real `Wix::Event` inbox) and the mutating-action `AuditLog` trail are live. Next: M5 cutover (artr-gitops manifests + DNS switch), not started.

Parity checklist source: `.specs/codebase/PORT-INVENTORY.md`. Cutover is big-bang (ADR-001/003): old NestJS/React stack stays live and is the parity reference until M5 ships, then it's retired in one change.

---

## M0 — Rails Bootstrap & In-App Auth

**Goal:** A deployable, empty Rails app with working email/password login, admin/member roles, and first-admin bootstrap. Nothing domain-specific yet — this is the walking skeleton that every later milestone builds on.

**Target:** Deployable to a scratch OKE namespace (or local Docker) with SQLite on a PVC, login works, roles enforced on a dummy protected page.

### Features

**Rails app scaffold** - DONE (T1 scaffold commit + M0 verification; spec requirements complete)

- New Rails app in `sitio-rails`, SQLite3 (no WAL), Tailwind + Hotwire installed
- Minitest + fixtures (AD-004 / AD-006; RSpec removed)
- Dockerfile + basic health check route

**In-app authentication (ADR-002)** - DONE (T1–T8 complete; suite green under Minitest)

- `User` model with `has_secure_password`, `admin`/`member` role
- Login/logout, session cookie, CSRF
- First-admin bootstrap via one-time registration form (zero users only); admin creates members via Admin::Users
- All routes except a to-be-defined public webhook prefix require a session

---

## M1 — Core Domain: Schools → Trips → Passengers → Payments

**Goal:** Full CRUD parity for the four core domain models, with Hotwire UI, matching today's dashboard capability (minus Wix-sourced automation, which comes in M2/M3).

**Target:** An admin can manually create a School, Trip, Passenger, and Payment end-to-end through the UI, with the same field set and business rules (minor-unit amounts, CPF uniqueness per trip, soft-remove, delete-eligibility, manual-paid-without-info).

### Features

**Schools** - DONE

- CRUD, deactivate/activate via `School::Deactivation`, store hide/show via `School::StoreConcealment`
- Hard delete via nested `deletion` resource; blocked when the linked Wix collection still has products, soft-fail permissive when no Wix API key is configured (`School::Deletion`, AD-007)
- Hotwire pages: directory, new, show, edit (pt-BR)

**Trips** - DONE

- CRUD nested under School; deactivate/activate + store conceal via shared concerns
- Hard delete via nested `deletion` (blocked when passengers exist; no separate Wix order gate — matches Nest, which also only checks passengers on trip delete)
- Hourly Solid Queue job conceals expired store-visible trips locally
- Hotwire pages: list under school, new, show, edit (pt-BR)

**Passengers** - DONE

- CRUD nested under Trip; CPF normalize/validate; name-duplicate confirm checkbox
- Soft-remove via `Passenger::Removal`; manual paid via `Passenger::ManualSettlement`
- Hotwire pages: list, new, show, edit (pt-BR)
- Payment-derived status aggregates deferred until Payments

**Payments** - DONE

- CRUD nested under Passenger; minor-unit amounts; `paid_on`/`location`/`payer_identity`
- Hard delete; create blocked when passenger is removed; optional unique `wix_transaction_id` (webhook path later)
- Derived passenger payment status (`pending` / `settled_payments` / `settled_manual` / `unavailable`)
- Hotwire pages: list, new, edit (pt-BR)

**Metadata scrape** - DONE

- `POST /metadata/page_fetch` (title/description/image/favicon/price) with SSRF-safe URL fetching (`Metadata::SafeUrl`), HTML parsing (`Metadata::PageParser`), and Faraday client with redirect-following (`Metadata::PageFetch`)
- School form wired via `metadata-fetch` Stimulus controller: debounced fetch on URL change, favicon auto-fill, status/error UI (pt-BR)

---

## M2 — Wix Catalog Integration (Inbound + Outbound)

**Goal:** Wix Stores stays the catalog source of truth: collections/products sync into School/Trip automatically, and admins can browse/link Wix catalog data from the UI.

**Target:** A Wix collection/product change triggers the same School/Trip create/update/deactivate behavior as today, verified with recorded or replayed webhook payloads.

### Features

**Outbound Wix API client** - DONE

- `Wix::Client` (Faraday): Stores Catalog v1 read (`stores-reader/v1`) + write (`stores/v1`) collections/products CRUD + query, prefix autocomplete helpers, site list (`site-list/v2`), media upload URL (`site-media/v1`)
- Raises typed errors (`ApiKeyMissing` / `NotFound` / `UpstreamError`); `WixIntegration` singleton resolves ENV vars first, then the DB row, so a missing key never crashes catalog sync
- Injectable connection for tests (no real HTTP in the suite)

**Inbound catalog webhooks** - DONE

- Public JWT-verified endpoint `POST /webhooks/wix` (RS256, public key from `WixIntegration`); this + M3's payment webhook are the *only* public HTTP surface per ADR-004
- `Wix::Event` inbox model (`wix_events` table) + async processing via `Wix::ProcessEventJob` (`after_create_commit`, `retry_on` with polynomial backoff, marks the event failed on final discard)
- `Wix::CatalogSync` PORO dispatches Collection/Product Created/Changed/Deleted, mirroring Nest's `wix-webhook-event-handler.service.ts`, including drift-heal on `*Changed` when no local record matches yet
- Visibility mapping onto `Deactivation`/`StoreConcealment` state-as-records (not Nest's booleans) per AD-007
- `PaymentEvent` is ingested and marked processed but is a deliberate no-op (M3 fills in the handler)

**Wix catalog autocomplete (authenticated)** - DONE

- `GET /wix/collections/autocomplete`, `GET /wix/collections/:id`, `GET /wix/products/autocomplete`, `GET /wix/products/:id` — same session auth as the rest of the admin app (matches Nest, no Wix-specific authorization tier)
- School/Trip forms wired via `wix-autocomplete` Stimulus (debounced prefix search, pick fills id + snapshot fields)

---

## M3 — Wix Payment Webhooks

**Goal:** Wix Payments events auto-create Passengers and Payments, matching today's behavior including dedup.

**Target:** A replayed `PaymentEvent` webhook produces the same School/Trip/Passenger/Payment side effects as the Nest implementation, with no duplicate Payments on redelivery.

### Features

**Payment event ingestion** - DONE

- `Wix::Event#process_now` routes `PaymentEvent` to `Wix::PaymentSync` (was a deliberate no-op in M2); resolves the sub-event (`TRANSACTION_CREATED`/`TRANSACTION_UPDATED`/`TRANSACTION_STATUS_CHANGED`) and `transaction.verticalOrderId`, then `Wix::Client#get_order` (`GET /ecom/v1/orders/{id}`)
- Ensures School/Trip exist for every line item's product, drift-healing via `Wix::ProductSnapshot` (shared with `Wix::CatalogSync`), matching Nest's `ensureProductAndSchoolForPayment`

**Auto-create Passenger & Payment** - DONE

- Passenger match/create by CPF from `extendedFields._user_fields` (falls back to the line item's free-text checkout fields when `student_name` is absent, matching Nest); `confirm_name_duplicate` bypassed since Wix-sourced data has no manual duplicate-name confirmation step
- Payment created only for the order's first line item per transaction (matches Nest), deduped by unique `wix_transaction_id`; skipped when the matched passenger was removed (Rails-specific — no Nest equivalent)

---

## M4 — Admin Tooling: Wix Config UI & Audit Log

**Goal:** Round out the admin-only surface that isn't strictly domain CRUD: Wix integration configuration and a mutating-action audit trail.

**Target:** An admin can view/edit Wix site+keys and webhook docs in the UI; every mutating action is recorded with actor and resource.

### Features

**Wix integration config UI** - DONE

- Admin-only `Admin::WixIntegrationsController#show/update` under `namespace :admin`: site select (loaded from `Wix::Client#list_sites` once a private key is configured, text-field fallback otherwise), public key textarea, private key rotate-by-blank field showing only the stored prefix, webhook callback URL, and an events-accepted panel driven by `Wix::Event::DESCRIPTIONS` (pt-BR)
- `Admin::WixEventsController#index/show` — real `Wix::Event` inbox (status, payload, last error), replacing the fixture-only screen from today's dashboard

**Audit log** - DONE

- `AuditLog` model + `Auditable` controller concern (`after_action`, mutating verbs only) records actor (user id/email/name, or `"system"` for unauthenticated webhooks), action (HTTP method), resource (path), IP on every mutating request app-wide, including `Webhooks::WixController`
- A logging failure is caught and reported via `Rails.error.report`, never breaks the request
- `Admin::AuditLogsController#index/show` — recent-first, simple `page`-based pagination (100/page)

---

## M5 — Cutover

**Goal:** Retire the NestJS/React stack in one change once M0–M4 are verified at parity.

**Target:** Rails app live in production on OKE, old stack decommissioned same day, no Postgres data carried over (greenfield, ADR-003).

### Features

**artr-gitops manifests** - PLANNED

- New Rails Deployment + Service + IngressRoute manifests, SQLite PVC on existing `nfs-client` storage class (single writer replica)
- Remove Sitio-specific TinyAuth forwardAuth wiring (ADR-002)

**DNS/ingress switch + retirement** - PLANNED

- Point production ingress at the Rails app
- Decommission `apps/backend` + `apps/dashboard` Deployments in `artr-gitops`
- Archive (don't delete) `sitio-monorepo` app code for reference

---

## Future Considerations

- Share-link / tokenless access (explicitly deferred, needs its own ADR per ADR-002)
- SQLite WAL mode once a non-NFS volume exists (ADR-003 upgrade path)
- Richer RBAC beyond admin/member, if product needs grow
- Wix Refund / Payment Link / Cashier Payment Event webhook types beyond what's already handled
