# State

**Last Updated:** 2026-07-21
**Current Work:** M5 cutover in progress — terraform OCIR `sitio-rails`, GH Action, gitops manifests ready. Blocked on human: `terraform apply`, kubeseal `RAILS_MASTER_KEY`, push repos, run Deploy Rails workflow.

---

## Recent Decisions (Last 60 days)

### AD-009: Audit log write path and Wix admin UI shape (2026-07-20)

**Decision:** `AuditLog` is written by a new `Auditable` controller concern included in `ApplicationController`, using an `after_action` (not `around_action`) gated on `MUTATING_METHODS = %w[POST PATCH PUT DELETE]` — GETs and the health check never match, so no separate skip-list was needed. The actor is `Current.user` when present, else the literal string `"system"` (webhooks run through `allow_unauthenticated_access`, so `Current.user` is nil there); `user_name` mirrors `user_email` since `User` has no `name` column today. A failed insert is rescued and reported via `Rails.error.report(handled: true)`, never raised into the request. The Wix admin UI is the "simpler" option from the prompt: one `Admin::WixIntegrationsController#show/update` (site select sourced from `Wix::Client#list_sites`, gated on a configured private key; falls back to a plain text field otherwise) rather than a separate `wix_sites`/`wix_webhook_config` resource tree. `Wix::Event::DESCRIPTIONS` (pt-BR) was added to the model as the single source for both the webhook-docs "accepted events" panel and the event inbox list/show pages. `WixIntegration#env_overridden?(field)` was added so the form can flag when an ENV var is already winning over the DB column (per `resolve_*`'s existing ENV-first precedence) instead of silently accepting an edit that has no effect.
**Reason:** Matches the M4 prompt's explicit "simpler" routing option and rails-dev's CRUD/small-interface conventions; `after_action` is enough since none of the audited actions need to run inside the action's own exception path, and Rails already renders/redirects on validation failure before the audit hook fires.
**Trade-off:** `Admin::AuditLogsController#index` paginates with a hand-rolled `page`/`limit(100)` (no Kaminari, per "minimal dependencies") rather than a real cursor; fine at this data volume. `user_name` carries no information beyond `user_email` until `User` gains a real name column.
**Impact:** `app/controllers/concerns/auditable.rb`, `app/models/audit_log.rb`, `db/migrate/..._create_audit_logs.rb`; `app/controllers/admin/{wix_integrations,wix_events,audit_logs}_controller.rb` + views; nav links added to `dashboard/_nav`. Tests: `test/models/audit_log_test.rb`, `test/integration/audit_logging_test.rb` (school create + webhook system actor + insert-failure-doesn't-break-request), `test/integration/admin/{wix_integrations,wix_events,audit_logs}_test.rb` (admin allowed, member 403).

### AD-008: Wix payment webhook shape (2026-07-20)

**Decision:** `Wix::Event#process_now` routes `PAYMENT_EVENT` to a new `Wix::PaymentSync` PORO (not `Wix::CatalogSync#payment_event`, which is removed) — dedicated noun per-M3-prompt direction, since the payment path has a materially different shape (order fetch, passenger/payment creation) from the catalog create/update/delete dispatch. `Wix::Client#get_order` added (`GET /ecom/v1/orders/{id}`, same typed-error convention as the rest of the client). Two small pieces of `Wix::CatalogSync` were extracted for reuse since `Wix::PaymentSync` needs the same School/Trip drift-heal shape: `Wix::CatalogSync.apply_visibility` (now a class method) and a new `Wix::ProductSnapshot.build` PORO (product → Trip snapshot attrs, previously private methods on `CatalogSync`).
**Reason:** Prompt explicitly preferred a dedicated `Wix::PaymentSync` PORO over expanding `CatalogSync`; the two extractions were repetition made real by a second caller, not spec work (rails-dev "an abstraction earns its place").
**Trade-off:** `Wix::PaymentSync`'s own school/trip auto-create (`ensure_school_and_trip`) duplicates `CatalogSync`'s drift-heal shape rather than sharing it outright, because Nest's own `ensureProductAndSchoolForPayment` deliberately behaves differently on an ambiguous school match (picks the first school with a warning) than `driftHealProduct` (skips entirely) — matching that Nest quirk exactly. Passenger's `needs_review` boolean (Nest tracks it when the student-name fallback fires) was not ported — no `needs_review` column exists and the prompt didn't request one; the fallback still creates the passenger, just without the flag. `Payment` creation skips when the matched passenger was removed (`Passenger::Removable`) — a Rails-only invariant Nest has no equivalent for, added so a legitimately-removed passenger can't crash/retry-loop the whole webhook delivery.
**Impact:** `test/models/wix/payment_sync_test.rb` covers create/dedupe-on-redelivery/CPF-match/removed-skip/custom-text-field-fallback/drift-heal/first-line-item-only-payment/unknown-sub-event/missing-order-id/API-key-missing/zero-amount/no-line-items. `Wix::Client#get_order` covered in `client_test.rb`.

### AD-007: Wix webhook inbox + catalog sync shape (2026-07-20)

**Decision:** Public webhook route is `POST /webhooks/wix` (singular resource under `namespace :webhooks`, explicit `controller: "wix"` since `resource` still pluralizes the inferred controller name by default). Inbound events persist first into `Wix::Event` (`wix_events` table), ack fast with `head :ok`/`:unauthorized`/`:bad_request`, then process via `Wix::ProcessEventJob` (`after_create_commit`). `Wix::Event#process_now` dispatches to `Wix::CatalogSync`, a plain PORO that mirrors Nest's `wix-webhook-event-handler.service.ts`. Nest's `active`/`wixVisible` booleans map onto the existing `Deactivation`/`StoreConcealment` state-as-records: `visible: true` → `activate` (if deactivated) + `reveal_in_store` (if concealed and active); `visible: false` → `conceal_in_store` only; delete with passengers on any trip → `deactivate` (which also conceals) + best-effort push `visible: false` back to Wix; delete with zero passengers → hard `destroy!`. `School::Deletion#allowed?` gates hard-delete on the live Wix product count for the school's collection, soft-failing permissive (allow delete) when the Wix API key is not configured; `Trip::Deletion` stays passenger-count-only (Nest doesn't gate trip delete on Wix orders either).
**Reason:** User-locked decisions at M2 kickoff (see prompt); avoids introducing new boolean columns when the app already has richer state-as-records for this exact purpose.
**Trade-off:** `Wix::CatalogSync` re-fetches canonical state from the Wix API on `*Changed` events rather than trusting the webhook payload, trading an extra HTTP round-trip for correctness under drift; `PaymentEvent` is ingested and marked processed but is a deliberate no-op until M3.
**Impact:** `WixIntegration` singleton row (ENV vars win over the DB columns); `Wix::Client` Faraday wrapper with injectable connection for tests; `Wix::CollectionsController`/`Wix::ProductsController` autocomplete JSON endpoints require the same session auth as the rest of the admin app (no Wix-specific authorization tier, matching Nest).

### AD-006: Adopt rails-dev conventions for the port going forward (2026-07-20)

**Decision:** From M1 onward (and retroactively for the test stack), follow the project `rails-dev` skill: Minitest + fixtures (no RSpec/FactoryBot), state-as-records instead of business booleans, CRUD-everything noun resources (no custom member actions), soft references without FK constraints. Integer PKs stay as the established project standard in `db/schema.rb` (do not mix ULID into new tables).
**Reason:** User directed the port to follow rails-dev when M0→M1 ambiguity was raised.
**Trade-off:** Diverges from Nest's `active`/`wixVisible` booleans and from the earlier RSpec choice; Wix gates for school hard-delete stay deferred to M2.
**Impact:** M0 suite ported to Minitest. School uses `School::Deactivation` + `School::StoreConcealment`; routes are nested singular resources.

### AD-004: Minitest as the Rails test framework (2026-07-20; supersedes 2026-07-15 RSpec choice)

**Decision:** Use Minitest + fixtures. Do not use RSpec or FactoryBot.
**Reason:** rails-dev convention adopted in AD-006; user confirmed when resolving M1 kickoff ambiguities.
**Trade-off:** M0 RSpec suite was ported; new features write Minitest only.
**Impact:** `bin/rails test` is the suite command; generators use `:test_unit`.

### AD-001: New separate git repo for the Rails port (2026-07-15)

**Decision:** The Rails app lives in a brand-new repo, `sitio-rails`, sibling to `sitio-monorepo` and `artr-gitops`.
**Reason:** Clean separation between the JS stack (parity reference until cutover) and the new Rails codebase.
**Trade-off:** Domain/route inventory lives in `.specs/codebase/PORT-INVENTORY.md`.
**Impact:** `sitio-monorepo` stays live as parity reference through M0–M4; `artr-gitops` needs net-new manifests at M5.

### AD-002: Full feature parity is the v1 bar (2026-07-15)

**Decision:** v1 scope = schools/trips/passengers/payments CRUD + Wix catalog/payment webhooks + admin Wix config UI + audit log.
**Reason:** Big-bang cutover requires full replacement.
**Trade-off:** Longer path to cutover than a core-first slice.
**Impact:** M0–M4 must ship before M5.

### AD-003: Big-bang cutover, no staged per-domain rollout (2026-07-15)

**Decision:** Old NestJS/React stack runs unmodified until Rails reaches full v1 parity, then ingress/DNS switches in one change.
**Reason:** Matches ADR-003 greenfield/no-migration stance.
**Trade-off:** No incremental production validation per domain.
**Impact:** M5 is a single flip.

### AD-005: In-app auth gray areas resolved (2026-07-15)

**Decision:** First-admin bootstrap while zero users; admin creates members; fixed 14-day session expiry; rate-limit ~5 failed logins; last-admin self-demote protection not in M0.
**Reason:** User decisions during M0 Discuss pass.
**Impact:** Auth shipped in M0.

---

## Active Blockers

_None._

---

## Lessons Learned

- Integration `sign_in_as` must `Rails.cache.clear` before posting to `SessionsController#create`, otherwise the login `rate_limit (to: 5)` trips once the suite grows past a handful of authenticated request tests.

---

## Quick Tasks Completed

_None yet._

---

## Deferred Ideas

- [ ] Share-link / tokenless access — future ADR per ADR-002
- [ ] SQLite WAL mode — only after non-NFS volume (ADR-003)
- [ ] Richer RBAC beyond admin/member
- [x] Real Wix event detail view — M4 (`Admin::WixEventsController#show`)
- [ ] Stimulus-driven collection/product autocomplete on the school/trip forms (endpoints exist and are tested; not wired into the form UI yet)

## Todos

- [x] Ruby/Rails versions — **Ruby 4.0.5 / Rails 8.1.3**
- [x] Fixed session expiry — T7 `expires_at` 14 days
- [x] M1 Schools / Trips / Passengers / Payments
- [x] Finish M1: metadata scrape endpoint + school form wire-up
- [x] M2: `WixIntegration`, `Wix::Event` inbox, `Wix::Client`, `Webhooks::WixController`, `Wix::CatalogSync`, `Wix::ProcessEventJob`, autocomplete endpoints + Stimulus, School hard-delete Wix gate (AD-007)
- [x] M3: payment webhook → passenger/payment auto-create via `Wix::PaymentSync` (AD-008)
- [x] M4: admin Wix config UI + audit log (AD-009)
- [ ] M5: cutover (artr-gitops manifests + DNS/ingress switch)

---

## Preferences

**Model Guidance Shown:** never
