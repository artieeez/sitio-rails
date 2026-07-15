# Sitio (Rails)

**Vision:** A single, self-contained Ruby on Rails app that runs school-trip payment management for Sitio — replacing the current NestJS + React monorepo with one deployable unit whose conventions match the size of an early-stage product.

**For:** Sitio's own admin/staff users (school trip organizers) who manage schools, trips, passengers, and payments — with data sourced from a Wix Stores catalog and Wix Payments.

**Solves:** The JS split (NestJS backend + React dashboard) imposes two toolchains, a drifting API contract, and heavier AI-agent harness than the product's current stage warrants. A unified Rails app collapses that boundary and leans on Rails conventions instead of custom scaffolding.

## Goals

- Reach full feature parity with the current NestJS/React app (schools, trips, passengers, payments, Wix catalog + payment webhooks, admin Wix config, audit log) — measured by: every endpoint/page inventoried in the port checklist has a working Rails equivalent
- Cut over in one big-bang release with zero data migration (greenfield SQLite) — measured by: DNS/ingress switched to the Rails app in a single change, old stack retired same day
- Keep the public HTTP surface to Wix webhooks only, everything else behind an in-app session — measured by: no route outside `/webhooks/wix/*` is reachable without an authenticated admin/member session

## Tech Stack

**Core:**

- Framework: Ruby on Rails (latest stable at build time)
- Language: Ruby (latest stable at build time)
- Database: SQLite3, default rollback-journal mode (no WAL), on existing NFS `nfs-client` RWX PVC, single-writer Deployment

**Key dependencies:**

- Hotwire (Turbo + Stimulus) + Tailwind CSS — UI, no SPA/public JSON API
- Rails built-in auth (`has_secure_password` / session cookies) — email/password, `admin` + `member` roles, no external IdP
- Background jobs: Solid Queue (or equivalent DB-backed queue) — async Wix webhook event processing, replacing the current in-process Nest queue
- RSpec — test framework (request specs for controllers/webhooks, model specs for domain logic)
- Wix APIs — Stores Catalog v1 (collections/products), eCom Orders, Payments webhooks (JWT-verified)

## Scope

**v1 includes (full parity target):**

- In-app auth: email/password sessions, `admin`/`member` roles, first-admin bootstrap (replaces Traefik/TinyAuth forwardAuth for Sitio)
- Domain CRUD: Schools → Trips → Passengers → Payments (nested resources, minor-unit amounts)
- Wix catalog webhooks: Collection/Product created/changed/deleted → School/Trip create/update/deactivate
- Wix payment webhooks: PaymentEvent → resolve order → auto-create Passenger/Payment, dedup by `wixTransactionId`
- Wix outbound API client: catalog autocomplete, media upload URL, site list, orders lookup
- Admin-only Wix integration config UI (site/keys, webhook callback docs)
- Audit log of mutating actions (user id/email, action, resource, IP)
- Metadata scrape endpoint (page title/favicon) used by the school form
- Hotwire/Turbo + Tailwind UI covering the same page set as today's dashboard (schools, trips, passengers, payments, Wix integration screens), in Portuguese (pt-BR)

**Explicitly out of scope (for v1):**

- Any Postgres → SQLite data migration (data is greenfield per ADR-003)
- Share-link / tokenless access (deferred to a future ADR per ADR-002)
- SSO / external IdP (TinyAuth is removed from Sitio's path per ADR-002)
- Multi-writer / horizontal scale-out of the Rails app (single-writer SQLite per ADR-003)
- WAL mode (deferred until a non-NFS volume exists per ADR-003)
- Richer RBAC beyond admin/member (per ADR-002)
- A public JSON API for the dashboard (Hotwire-only per ADR-004)
- Wix Refund / Payment Link / Cashier Payment Event webhooks beyond what's already handled today (same policy carried over, not expanded)

## Constraints

- Timeline: none fixed — solo/AI-assisted, exploratory pace, milestone-driven
- Technical: single Rails Deployment on OKE; SQLite on existing NFS `nfs-client` PVC, no WAL; no separate DB service; big-bang cutover (old NestJS/React stack retired once v1 parity is reached, not staged per-domain)
- Resources: brand-new repo (`sitio-rails`, sibling to `sitio-monorepo`); `sitio-monorepo`'s NestJS/React app remains the parity reference and stays live until cutover; `artr-gitops` will need new manifests for the Rails Deployment and removal of TinyAuth forwardAuth for Sitio routes

## Links

- Source ADRs (originated in `sitio-monorepo/docs/adr/`, copied here as this repo's starting ADR history): `docs/adr/0001` through `0004`
- Parity reference / domain inventory: `sitio-monorepo` (`apps/backend`, `apps/dashboard`) — see `.specs/codebase/PORT-INVENTORY.md` in this repo for the extracted domain/route/schema inventory
- Deploy target: `artr-gitops` (OKE cluster, ArgoCD App-of-Apps) — new manifests needed for the Rails Deployment + PVC; TinyAuth forwardAuth removal for Sitio ingress
