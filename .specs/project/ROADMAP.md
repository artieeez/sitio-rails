# Roadmap

**Current Milestone:** M2 — Wix Catalog Integration (Inbound + Outbound)
**Status:** M1 complete (Schools + Trips + Passengers + Payments + Metadata scrape all done); M2 next

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
- Hard delete via nested `deletion` resource (Wix product-count gate deferred to M2)
- Hotwire pages: directory, new, show, edit (pt-BR)

**Trips** - DONE

- CRUD nested under School; deactivate/activate + store conceal via shared concerns
- Hard delete via nested `deletion` (blocked when passengers exist; Wix order gate deferred to M2)
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

**Outbound Wix API client** - PLANNED

- Stores Catalog v1 (collections/products CRUD + query), site list, media upload URL
- Graceful no-crash behavior when Wix key not configured

**Inbound catalog webhooks** - PLANNED

- Public JWT-verified endpoint (this + M3's payment webhook are the *only* public HTTP surface per ADR-004)
- `WixEvent` inbox model + async processing (Solid Queue), replacing Nest's in-process queue
- Collection Created/Changed/Deleted → School create/update/deactivate
- Product Created/Changed/Deleted → Trip create/update/deactivate

---

## M3 — Wix Payment Webhooks

**Goal:** Wix Payments events auto-create Passengers and Payments, matching today's behavior including dedup.

**Target:** A replayed `PaymentEvent` webhook produces the same School/Trip/Passenger/Payment side effects as the Nest implementation, with no duplicate Payments on redelivery.

### Features

**Payment event ingestion** - PLANNED

- Extend the M2 webhook endpoint/queue to handle `PaymentEvent` (Cashier v3) sub-events
- Resolve order → line items → product IDs via eCom Orders API

**Auto-create Passenger & Payment** - PLANNED

- Passenger match/create by CPF from order buyer/custom fields
- Payment create with `wix_transaction_id` dedup (unique constraint, matches Nest's P7)

---

## M4 — Admin Tooling: Wix Config UI & Audit Log

**Goal:** Round out the admin-only surface that isn't strictly domain CRUD: Wix integration configuration and a mutating-action audit trail.

**Target:** An admin can view/edit Wix site+keys and webhook docs in the UI; every mutating action is recorded with actor and resource.

### Features

**Wix integration config UI** - PLANNED

- Admin-only: site/keys form, webhook callback URL + docs
- Wix event list view (real data, not the fixture-only screen from today's dashboard)

**Audit log** - PLANNED

- Record actor (user id/email or `"system"` for webhooks), action, resource, IP on mutations
- Minimal admin view to browse the log

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
