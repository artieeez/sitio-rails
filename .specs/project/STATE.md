# State

**Last Updated:** 2026-07-15
**Current Work:** Project planning - PROJECT.md/ROADMAP.md drafted, no milestone started yet

---

## Recent Decisions (Last 60 days)

### AD-001: New separate git repo for the Rails port (2026-07-15)

**Decision:** The Rails app lives in a brand-new repo, `sitio-rails`, sibling to `sitio-monorepo` and `artr-gitops`, rather than a new app inside `sitio-monorepo` or an in-place replace.
**Reason:** Clean separation between the JS stack (parity reference until cutover) and the new Rails codebase; avoids Nx/pnpm tooling bleeding into a Ruby project.
**Trade-off:** Domain/route inventory had to be captured as a standalone doc (`.specs/codebase/PORT-INVENTORY.md`) instead of living alongside the source in one repo.
**Impact:** `sitio-monorepo` stays untouched and fully live as the parity reference through M0–M4; `artr-gitops` needs net-new manifests (M5) rather than edits to existing ones.

### AD-002: Full feature parity is the v1 bar (2026-07-15)

**Decision:** v1 scope = schools/trips/passengers/payments CRUD + Wix catalog webhooks + Wix payment webhooks + admin Wix config UI + audit log — everything currently in `sitio-monorepo`, not a reduced slice.
**Reason:** Big-bang cutover (AD-003) requires the new app to fully replace the old one; a partial slice would leave a capability gap at cutover time.
**Trade-off:** Longer path to cutover than a core-first slice; M2-M4 in the roadmap carry real scope.
**Impact:** Roadmap milestones M0-M4 must all ship before M5 (cutover) starts.

### AD-003: Big-bang cutover, no staged per-domain rollout (2026-07-15)

**Decision:** Old NestJS/React stack runs unmodified until Rails reaches full v1 parity, then ingress/DNS switches in one change and the old stack is retired same day.
**Reason:** Matches ADR-003's greenfield/no-migration stance; avoids the complexity of dual-write or split-traffic between two stacks with different databases (Postgres vs SQLite).
**Trade-off:** No incremental production validation of individual domains before the full switch; more testing weight lands on pre-cutover verification (RSpec + manual UAT) rather than gradual rollout.
**Impact:** M5 in the roadmap is a single "flip the switch" milestone; artr-gitops changes for M5 should be prepared but not applied until M0-M4 are verified.

### AD-004: RSpec as the Rails test framework (2026-07-15)

**Decision:** Use RSpec (request specs + model specs) instead of Minitest.
**Reason:** User preference; richer DSL for request/model specs matches the domain-heavy CRUD + webhook surface being ported.
**Trade-off:** One extra gem/setup step vs. Rails' Minitest default.
**Impact:** Every feature's `tasks.md` gate check should reference `bundle exec rspec` (or scoped paths), once Tasks phase starts for M0.

---

## Active Blockers

_None yet — planning stage only._

---

## Lessons Learned

_None yet._

---

## Quick Tasks Completed

_None yet._

---

## Deferred Ideas

- [ ] Share-link / tokenless access — needs its own future ADR per ADR-002, do not design prematurely
- [ ] SQLite WAL mode — only after a non-NFS volume exists, per ADR-003
- [ ] Richer RBAC beyond admin/member — only if product needs grow, per ADR-002
- [ ] Real (non-fixture) Wix event detail view — captured during M4 scoping, was fixture-only in the old dashboard

## Todos

- [ ] Decide first-admin bootstrap mechanism (seed task vs. invite flow) during M0 Specify
- [ ] Decide exact public webhook route prefix/naming during M2 Specify (must be the only unauthenticated surface per ADR-004)
- [ ] Confirm Rails + Ruby target versions when M0 implementation starts (check current stable releases via Context7/web at that time, not now)

---

## Preferences

**Model Guidance Shown:** never
