# Rails App Scaffold Specification

**Milestone:** M0 — Rails Bootstrap & In-App Auth
**Scope size:** Medium (clear feature, <10 tasks) — design inline, tasks implicit, no Discuss needed (infrastructure work, not user-facing ambiguity)

## Problem Statement

Before any domain feature (schools, trips, auth, Wix) can be built, we need a working Rails app skeleton wired to this project's specific stack choices: SQLite3 without WAL, Tailwind, Hotwire, and RSpec instead of Rails' Minitest default. Getting this foundation right once avoids rework across every later milestone.

## Goals

- [ ] A new Rails app boots locally and via Docker with zero errors
- [ ] SQLite3 is configured in default (non-WAL) journal mode, matching ADR-003
- [ ] Tailwind CSS and Hotwire (Turbo + Stimulus) are installed and render a real page
- [ ] RSpec replaces Minitest as the test framework and runs successfully
- [ ] A health check endpoint exists and is reachable without auth

## Out of Scope

| Feature | Reason |
|---|---|
| Deployment manifests / OKE PVC wiring | Belongs to M5 (Cutover); this feature only needs the app to *support* that config, not deploy it |
| Any domain model (School/Trip/Passenger/Payment) | Belongs to M1 |
| Authentication / sessions / roles | Separate feature spec: `inapp-auth` (this same milestone, specified alongside this one) |
| CI pipeline setup | Not blocking for M0's own demo; can be added opportunistically |
| Production secrets management | Deferred to M5 when real deploy manifests are written |

---

## User Stories

### P1: Boot a working Rails app locally and in Docker ⭐ MVP

**User Story**: As the developer, I want a Rails app that boots cleanly with our chosen stack (SQLite, Tailwind, Hotwire, RSpec) so that every later milestone has a stable foundation to build on.

**Why P1**: Nothing else in the roadmap can start without this.

**Acceptance Criteria**:

1. WHEN `bin/rails server` runs locally THEN the app SHALL boot without error and serve a page at `/`
2. WHEN the app boots THEN it SHALL use the `sqlite3` adapter with the database file at a configurable path (env-driven, so it can later point at the OKE PVC mount)
3. WHEN `PRAGMA journal_mode;` is queried against the configured database THEN it SHALL report `delete` (default rollback-journal mode), never `wal`
4. WHEN a Docker image is built from the app's `Dockerfile` THEN it SHALL produce a runnable production image without dev/test-only gems bundled
5. WHEN the container starts with no existing database file THEN `db:prepare` (or equivalent) SHALL create it at the configured path

**Independent Test**: Run `bin/rails server`, hit `/`, confirm 200 + rendered HTML. Build the Docker image, run it, confirm it serves too.

---

### P1: Tailwind + Hotwire render on a real page ⭐ MVP

**User Story**: As the developer, I want Tailwind and Hotwire (Turbo + Stimulus) working end-to-end so that every later UI feature can rely on them without re-verifying the setup.

**Why P1**: ADR-004 mandates Hotwire/Tailwind as the UI approach; this must be proven before M1 UI work starts.

**Acceptance Criteria**:

1. WHEN the root page renders THEN Tailwind utility classes SHALL visibly apply (not just be present in markup)
2. WHEN the root page renders THEN the Turbo Drive `<meta>`/import SHALL be present and a same-page navigation SHALL not trigger a full page reload (verified via a two-link demo page)
3. WHEN a minimal Stimulus controller is attached to an element THEN it SHALL execute (e.g., a click toggles visible state), proving the JS pipeline works

**Independent Test**: Click a Stimulus-controlled toggle and a Turbo-Drive link on the demo page; confirm both work without a full reload and with Tailwind styling visible.

---

### P1: RSpec is the test framework ⭐ MVP

**User Story**: As the developer, I want RSpec configured instead of Minitest so that every later feature's tests follow one consistent framework (per STATE.md AD-004).

**Why P1**: Every subsequent milestone's Tasks/Execute phases need a working, agreed-upon test runner.

**Acceptance Criteria**:

1. WHEN `bundle exec rspec` runs on a fresh checkout THEN it SHALL execute successfully (even with zero or placeholder specs)
2. WHEN `rails generate` is used for models/controllers THEN it SHALL generate RSpec spec files, not Minitest test files
3. WHEN request specs are added later THEN `rails_helper.rb`/`spec_helper.rb` SHALL already be configured to support them (e.g., `rack-test` available)

**Independent Test**: Generate a throwaway scaffold, confirm an RSpec spec file (not a Minitest test file) is generated, then delete the scaffold.

---

### P2: Health check endpoint

**User Story**: As an operator, I want a public health check route so that the app can be probed by Kubernetes liveness/readiness checks later (M5) without needing auth.

**Why P2**: Needed before M5, not needed to demo M0, but cheap to add now while scaffolding.

**Acceptance Criteria**:

1. WHEN `GET /up` (Rails' built-in health check route, or an equivalent) is requested THEN it SHALL return 200 without requiring authentication
2. WHEN the database is unreachable THEN the health check SHALL reflect a non-200 status (basic DB connectivity check)

**Independent Test**: `curl` the health route with the app up, then with the DB file path misconfigured, and confirm the status code differs.

---

## Edge Cases

- WHEN the SQLite database file's parent directory doesn't exist yet THEN app boot SHALL fail with a clear error rather than a silent crash (this matters once the app runs against an NFS PVC mount in M5)
- WHEN `RAILS_ENV=test` THEN the test database SHALL be separate from development (standard Rails behavior, verify it isn't accidentally shared)
- WHEN the Docker image is built without a `.env`/secrets file THEN it SHALL still build (secrets are injected at runtime, not build time)

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SCAF-01 | P1: Boot locally + Docker | Implicit (Medium) | Pending |
| SCAF-02 | P1: Boot locally + Docker | Implicit (Medium) | Pending |
| SCAF-03 | P1: Tailwind + Hotwire | Implicit (Medium) | Pending |
| SCAF-04 | P1: RSpec | Implicit (Medium) | Pending |
| SCAF-05 | P2: Health check | Implicit (Medium) | Pending |

**Coverage:** 5 total, 0 mapped to tasks, 5 unmapped ⚠️ (Tasks phase not yet run for this feature)

---

## Success Criteria

- [ ] `bin/rails server` boots and serves `/` locally
- [ ] Docker image builds and runs the same app
- [ ] SQLite confirmed in non-WAL journal mode
- [ ] Tailwind + Turbo + Stimulus all demonstrably working on one page
- [ ] `bundle exec rspec` runs clean on a fresh checkout
- [ ] `/up` health check reachable without auth
