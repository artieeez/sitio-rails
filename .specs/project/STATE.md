# State

**Last Updated:** 2026-07-20
**Current Work:** M1 in progress — Schools + Trips + Passengers done. Next: Payments (+ metadata scrape).

---

## Recent Decisions (Last 60 days)

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

_None yet._

---

## Quick Tasks Completed

_None yet._

---

## Deferred Ideas

- [ ] Share-link / tokenless access — future ADR per ADR-002
- [ ] SQLite WAL mode — only after non-NFS volume (ADR-003)
- [ ] Richer RBAC beyond admin/member
- [ ] School/Trip hard-delete Wix gates — M2
- [ ] Real Wix event detail view — M4

## Todos

- [ ] Decide public webhook route prefix during M2 Specify
- [x] Ruby/Rails versions — **Ruby 4.0.5 / Rails 8.1.3**
- [x] Fixed session expiry — T7 `expires_at` 14 days
- [ ] Continue M1: Trips nested under School

---

## Preferences

**Model Guidance Shown:** never
