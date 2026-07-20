# State

**Last Updated:** 2026-07-15
**Current Work:** M0 - `inapp-auth` fully planned (Specify → Discuss → Design → Tasks, 8 tasks, T1-T2 sequential then T3/T4/T5/T7 parallel then T6→T8 sequential). `rails-app-scaffold` speced (Medium, no Design/Tasks needed). Execute not yet started for either feature. `.specs/codebase/TESTING.md` established (RSpec, model+request specs, no coverage threshold yet).

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

### AD-005: In-app auth gray areas resolved (2026-07-15)

**Decision:** First-admin bootstrap = one-time signup form usable only while zero users exist. Member creation = admin-only invite, no open signup. Sessions = fixed expiry (no remember-me), exact duration left to agent discretion (default 14 days). Failed logins = rate-limit/lockout (exact threshold left to agent discretion, default 5 attempts/rolling window). Last-admin self-demote/self-delete protection = explicitly not handled in M0.
**Reason:** User decisions captured directly during the M0 `inapp-auth` Discuss pass; see `.specs/features/inapp-auth/context.md` for full detail.
**Trade-off:** Exact session/lockout numeric defaults are agent's discretion, not user-specified — may need revisiting once real usage patterns exist.
**Impact:** Unblocks Design for `inapp-auth`. Resolves the M0 bootstrap-mechanism todo below.

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

- [ ] Decide exact public webhook route prefix/naming during M2 Specify (must be the only unauthenticated surface per ADR-004)
- [ ] Confirm Rails + Ruby target versions when M0 implementation starts (check current stable releases via Context7/web at that time, not now)
- [x] ~~Decide the fixed-session-expiry mechanism for `inapp-auth`~~ — resolved in Tasks phase as T7: DB-driven `expires_at` column + check in `Authentication` concern. Not yet implemented (Execute pending).

---

## Preferences

**Model Guidance Shown:** never
