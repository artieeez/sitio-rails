# In-App Authentication Tasks

**Design**: `.specs/features/inapp-auth/design.md`
**Testing conventions**: `.specs/codebase/TESTING.md`
**Status**: Done

**Prerequisite (external, not a task here):** `rails-app-scaffold` must be executed first — this feature assumes a booting Rails app with SQLite/Tailwind/Hotwire/RSpec already in place.

---

## Execution Plan

### Phase 1: Foundation (Sequential)

```
T1 → T2
```

### Phase 2: Core Implementation (Parallel OK)

```
        ┌→ T3 ─┐
T2 ─────┼→ T4 ─┼──→ (Phase 3)
        ├→ T5 ─┤
        └→ T7 ─┘
```

### Phase 3: Admin Surface + Demo (Sequential — all edit `config/routes.rb`)

```
T6 → T8
```

---

## Task Breakdown

### T1: Run the Rails 8 authentication generator

**What**: Execute `bin/rails generate authentication`, then `bin/rails db:migrate`. Produces `app/models/{user,session,current}.rb`, `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`, `app/controllers/passwords_controller.rb`, `app/mailers/passwords_mailer.rb`, views, migrations for `users`/`sessions`, and adds `bcrypt` to the Gemfile.
**Where**: Whole-app (generator output), `config/routes.rb` (auto-adds `resource :session`, `resources :passwords`)
**Depends on**: None (external prerequisite: `rails-app-scaffold` executed)
**Reuses**: Rails 8 built-in generator — this task *is* the reuse, no hand-written auth code
**Requirement**: AUTH-01, AUTH-02, AUTH-03, AUTH-05 (scaffolding only; verified by tests in T2/T5)

**Tools**:
- MCP: `context7` (if generator output differs from the version researched in design.md, re-verify against installed Rails version)
- Skill: NONE

**Done when**:
- [x] Generator runs without error; `bcrypt` present in `Gemfile.lock`
- [x] `bin/rails db:migrate` creates `users` and `sessions` tables
- [x] `bin/rails server` still boots (no regression from SCAF-01)
- [x] Gate check passes: `bundle exec rspec` (full — first run after generator, confirm zero failures even with no new specs yet)

**Tests**: none (merged forward — model spec → T2, session login/logout request spec → T5, per the coverage matrix's "no direct spec unless non-trivial" + merge-forward rule for freshly-generated framework code)
**Gate**: full

**Commit**: `feat(auth): scaffold Rails 8 authentication generator`

---

### T2: Add `role` enum to User

**What**: Add a migration for `role:integer, null: false, default: 0` on `users`; add `enum :role, { member: 0, admin: 1 }` + presence validation to `app/models/user.rb`; write the first model specs (covering both the generated `has_secure_password` behavior and the new role).
**Where**: `db/migrate/xxx_add_role_to_users.rb`, `app/models/user.rb`, `spec/models/user_spec.rb`
**Depends on**: T1
**Reuses**: Generated `User` model (extends, doesn't replace)
**Requirement**: AUTH-06, AUTH-07 (data shape), spec.md P1 "Two roles"

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Migration adds `role` column, backfills default `member` (0) for any existing rows
- [x] `User#admin?` / `User#member?` work; invalid role value is rejected at the model level
- [x] `User.authenticate_by` (generated) still works unchanged
- [x] Gate check passes: `bundle exec rspec spec/models/user_spec.rb`
- [x] Test count: at least 5 examples pass (valid user, default role, admin?/member? predicates, invalid role rejected, authenticate_by still works)

**Tests**: unit
**Gate**: quick

**Verify**:
```bash
bundle exec rspec spec/models/user_spec.rb
```
Expect all examples green, 0 failures.

**Commit**: `feat(auth): add admin/member role to User`

---

### T3: Authorization concern (`require_admin!`) [P]

**What**: Create `app/controllers/concerns/authorization.rb` with a `require_admin!` method (checks `Current.user&.admin?`, renders/redirects with 403-equivalent if false), designed to be included alongside the generated `Authentication` concern.
**Where**: `app/controllers/concerns/authorization.rb`
**Depends on**: T2
**Reuses**: Same `before_action` shape as the generated `Authentication` concern; `Current.user` from T1's generated `Current` model
**Requirement**: AUTH-09 ("reusable, not duplicated ad hoc")

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `Authorization` concern defines `require_admin!` as a callable `before_action`
- [x] No standalone spec added here (per TESTING.md matrix: concerns are exercised through their first real consumer)
- [x] Gate check passes: `bundle exec rspec` boots without new failures (nothing to exercise yet)

**Tests**: none (matrix-justified — exercised via T6's request specs, the first controller to include this concern; NOT a deferral, this is what the coverage matrix specifies for concerns)
**Gate**: quick

**Commit**: `feat(auth): add Authorization concern with require_admin!`

---

### T4: RegistrationsController — first-admin bootstrap [P]

**What**: Create `RegistrationsController#new/create`, reachable only while `User.count.zero?`; `create` builds the first `User` with `role: :admin` and starts a session (reusing the same session-start pattern as `SessionsController`). Any request when `User.count > 0` redirects to the login page instead of creating a user or 404ing. Add Tailwind-styled view and route.
**Where**: `app/controllers/registrations_controller.rb`, `app/views/registrations/new.html.erb`, `config/routes.rb` (add `resource :registration, only: %i[new create]`), `spec/requests/registrations_spec.rb`
**Depends on**: T1, T2
**Reuses**: `User` model validations (T2); `start_new_session_for` pattern from the generated `SessionsController` (T1); `allow_unauthenticated_access` from the generated `Authentication` concern (T1)
**Requirement**: AUTH-10, AUTH-11, AUTH-12

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] On a fresh (zero-user) DB, visiting the registration form and submitting valid data creates exactly one `admin`-role user and logs them in
- [x] With one or more existing users, `GET`/`POST` to the registration routes redirect to the login page and create no user
- [x] Gate check passes: `bundle exec rspec spec/requests/registrations_spec.rb`
- [x] Test count: at least 3 examples pass (bootstrap succeeds when empty, blocked when not empty, created user has admin role)

**Tests**: integration
**Gate**: quick

**Verify**:
```bash
bundle exec rspec spec/requests/registrations_spec.rb
```
Expect all examples green, 0 failures.

**Commit**: `feat(auth): add first-admin bootstrap registration flow`

---

### T5: Rate-limit login attempts [P]

**What**: Add `rate_limit to: 5, within: 15.minutes, only: :create` to the generated `SessionsController`. Add the first request specs for the login/logout flow itself (deferred forward from T1): valid login, invalid login (generic error, no session), logout, and the rate limit triggering on the 6th rapid attempt.
**Where**: `app/controllers/sessions_controller.rb`, `spec/requests/sessions_spec.rb`
**Depends on**: T1
**Reuses**: Generated `SessionsController` body (`authenticate_by`, `start_new_session_for`) — only the `rate_limit` line is new
**Requirement**: AUTH-01, AUTH-02, AUTH-03, AUTH-04 (login/logout portion), context.md's failed-login decision

**Tools**:
- MCP: `context7` (only if `rate_limit`'s `with:` customization behaves unexpectedly — re-check the API doc queried in design.md)
- Skill: NONE

**Done when**:
- [x] Valid credentials establish a session (secure, HTTP-only cookie)
- [x] Invalid credentials show a generic error, no session established
- [x] Logout destroys the session and redirects to login
- [x] The 6th login attempt within 15 minutes (from the same IP) is rejected distinctly from a normal invalid-credentials response (429 or redirect, still generic wording)
- [x] Gate check passes: `bundle exec rspec spec/requests/sessions_spec.rb`
- [x] Test count: at least 4 examples pass

**Tests**: integration
**Gate**: quick

**Verify**:
```bash
bundle exec rspec spec/requests/sessions_spec.rb
```
Expect all examples green, 0 failures.

**Commit**: `feat(auth): add login rate limiting`

---

### T6: Admin::UsersController — admin-only member/admin creation

**What**: Resourceful controller (`index`, `new`, `create`, `edit`, `update`) under `Admin::` namespace, gated by `require_admin!` (from T3). Admin sets email/password/role directly at creation (no emailed invite in M0, per context.md — SMTP isn't configured). Tailwind views + `namespace :admin do resources :users end` route.
**Where**: `app/controllers/admin/users_controller.rb`, `app/views/admin/users/*`, `config/routes.rb`, `spec/requests/admin/users_spec.rb`
**Depends on**: T2, T3
**Reuses**: `User` model validations (T2); `Authorization#require_admin!` (T3, first real consumer — this is where T3's concern gets exercised)
**Requirement**: AUTH-06, AUTH-07, AUTH-08, AUTH-09, AUTH-13, AUTH-14

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] An admin user can create both `member`- and `admin`-role accounts via the UI
- [x] A `member`-role user hitting any `Admin::UsersController` action is denied (403/redirect), no admin-only content leaked
- [x] A newly created member account can immediately log in with the credentials set by the admin
- [x] Gate check passes: `bundle exec rspec spec/requests/admin/users_spec.rb`
- [x] Test count: at least 4 examples pass (admin creates member, admin creates admin, member denied, new member can log in)

**Tests**: integration
**Gate**: quick

**Verify**:
```bash
bundle exec rspec spec/requests/admin/users_spec.rb
```
Expect all examples green, 0 failures.

**Commit**: `feat(auth): add admin-only user management`

---

### T7: Fixed session expiry (`expires_at`) [P]

**What**: Resolve design.md's open question. Add `expires_at:datetime` to the `sessions` table, default it to `created_at + 14.days` on creation (matches context.md's "fixed expiry" decision). Modify the generated `Authentication` concern's session-resumption logic to treat an expired session the same as no session (destroy or ignore it, redirect to login) rather than fabricating a different mechanism.
**Where**: `db/migrate/xxx_add_expires_at_to_sessions.rb`, `app/models/session.rb`, `app/controllers/concerns/authentication.rb`, `spec/models/session_spec.rb`, `spec/requests/session_expiry_spec.rb`
**Depends on**: T1
**Reuses**: Generated `Session`/`Current`/`Authentication` — modifies session resumption only, doesn't replace the mechanism
**Requirement**: context.md session-lifetime decision (resolves the STATE.md "session-expiry mechanism" todo)

**Tools**:
- MCP: `context7` (re-verify the exact `Authentication` concern method name/shape for session resumption against the installed Rails version before modifying it)
- Skill: NONE

**Done when**:
- [x] New sessions get `expires_at` set to 14 days from creation
- [x] A request presenting an expired session is treated as unauthenticated (redirected to login), and the expired `Session` row is cleaned up (destroyed) rather than left indefinitely valid
- [x] A request presenting a non-expired session continues to work normally
- [x] Gate check passes: `bundle exec rspec spec/models/session_spec.rb spec/requests/session_expiry_spec.rb`
- [x] Test count: at least 3 examples pass (expiry set on create, expired session rejected, valid session accepted)

**Tests**: unit + integration
**Gate**: quick

**Verify**:
```bash
bundle exec rspec spec/models/session_spec.rb spec/requests/session_expiry_spec.rb
```
Expect all examples green, 0 failures.

**Commit**: `feat(auth): add fixed 14-day session expiry`

---

### T8: Protected demo pages (default-deny + admin-only proof)

**What**: Add a minimal authenticated dashboard/root page (no `allow_unauthenticated_access` — proves AUTH-04's default-deny) with a nav showing the logged-in user's email/role and a logout link, plus one admin-only demo action using `require_admin!` (from T3). This is the "Independent Test" fixture the spec.md stories call for.
**Where**: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/*`, `config/routes.rb` (root route), `spec/requests/dashboard_spec.rb`
**Depends on**: T1, T3
**Reuses**: Generated `Authentication` concern's default-deny behavior (T1); `Authorization#require_admin!` (T3)
**Requirement**: AUTH-04, AUTH-06, AUTH-07, AUTH-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] An unauthenticated request to the dashboard redirects to login
- [x] A logged-in `member` is denied the admin-only demo action
- [x] A logged-in `admin` is allowed the admin-only demo action
- [x] Gate check passes: `bundle exec rspec` (full — this is the last task in the feature, run the whole suite)
- [x] Test count: at least 3 examples pass, and total suite test count matches the sum of all tasks' "Test count" minimums with zero unexplained deletions

**Tests**: integration
**Gate**: full

**Verify**:
```bash
bundle exec rspec
```
Expect all examples green, 0 failures, total example count ≥ 5 (T2) + 3 (T4) + 4 (T5) + 4 (T6) + 3 (T7) + 3 (T8) = 22.

**Commit**: `feat(auth): add protected demo dashboard proving default-deny + role gating`

---

## Parallel Execution Map

```
Phase 1 (Sequential):
  T1 ──→ T2

Phase 2 (Parallel, all depend only on T1/T2):
  T2 complete, then:
    ├── T3 [P]
    ├── T4 [P]
    ├── T5 [P]
    └── T7 [P]

Phase 3 (Sequential — all edit config/routes.rb, must not race):
  T3 complete, then:
    T6 ──→ T8
```

**Note on `config/routes.rb` contention:** T1 and T4 both touch `routes.rb` but T4 runs after T1 completes (different phases), so no race. T6 and T8 both touch it too and are deliberately kept sequential (not `[P]`) even though their business logic doesn't depend on each other, purely to avoid two sub-agents editing the same file concurrently.

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1: Run auth generator | 1 generator command (framework boundary) | ⚠️ OK if cohesive — splitting a single generator invocation would fight the tool |
| T2: Add role to User | 1 migration + 1 model (tightly coupled) | ✅ Granular |
| T3: Authorization concern | 1 concern, 1 method | ✅ Granular |
| T4: RegistrationsController | 1 controller + views + 1 route (cohesive single feature) | ⚠️ OK if cohesive |
| T5: Rate-limit login | 1 controller line + its tests | ✅ Granular |
| T6: Admin::UsersController | 1 controller + views + 1 route (cohesive single feature) | ⚠️ OK if cohesive |
| T7: Session expiry | 1 migration + 1 model + 1 concern method (cohesive single mechanism) | ⚠️ OK if cohesive |
| T8: Protected demo pages | 1 controller + views + 1 route (cohesive single feature) | ⚠️ OK if cohesive |

No ❌ — all tasks pass (✅ or ⚠️ OK-if-cohesive, none require splitting).

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None (external prereq only) | No incoming arrow (root of the graph) | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T1, T2 | T1 (via phase ordering) → T4, T2 → T4 | ✅ Match |
| T5 | T1 | T1 (via phase ordering) → T5 | ✅ Match |
| T6 | T2, T3 | T2 → T6 (via phase ordering), T3 → T6 | ✅ Match |
| T7 | T1 | T1 (via phase ordering) → T7 | ✅ Match |
| T8 | T1, T3 | T1 (via phase ordering) → T8, T3 → T8 | ✅ Match |

All match — no mismatches to fix.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1 | Models + Controllers (generated) | unit + integration | none (merged forward to T2/T5) | ✅ OK — merge-forward, not deferral; code is untestable in isolation before role/rate-limit context exists |
| T2 | Model (`User`) | unit | unit | ✅ OK |
| T3 | Concern (`Authorization`) | none (matrix: concerns tested via consumer) | none | ✅ OK — matrix-justified, not deferral |
| T4 | Controller (`RegistrationsController`) | integration | integration | ✅ OK |
| T5 | Controller (`SessionsController`) | integration | integration | ✅ OK |
| T6 | Controller (`Admin::UsersController`) | integration | integration | ✅ OK |
| T7 | Model (`Session`) + Concern (`Authentication`, modified) | unit + integration (non-trivial concern change) | unit + integration | ✅ OK |
| T8 | Controller (`DashboardController`) | integration | integration | ✅ OK |

No ❌ VIOLATION — all tasks are consistent with `.specs/codebase/TESTING.md`.

---

## Requirement Traceability (updated)

| Requirement ID | Story | Task(s) | Status |
|---|---|---|---|
| AUTH-01 | P1: Log in/out | T1 (scaffold), T5 (tested) | Done |
| AUTH-02 | P1: Log in/out | T1 (scaffold), T5 (tested) | Done |
| AUTH-03 | P1: Log in/out | T1 (scaffold), T5 (tested) | Done |
| AUTH-04 | P1: Log in/out | T1 (mechanism), T8 (proven) | Done |
| AUTH-05 | P1: Log in/out | T1 (Rails default CSRF) | Done |
| AUTH-06 | P1: Two roles | T2, T6, T8 | Done |
| AUTH-07 | P1: Two roles | T2, T6, T8 | Done |
| AUTH-08 | P1: Two roles | T6, T8 | Done |
| AUTH-09 | P1: Two roles | T3, T6 | Done |
| AUTH-10 | P1: First-admin bootstrap | T4 | Done |
| AUTH-11 | P1: First-admin bootstrap | T4 | Done |
| AUTH-12 | P1: First-admin bootstrap | T4 | Done |
| AUTH-13 | P2: Member creation | T6 | Done |
| AUTH-14 | P2: Member creation | T6 | Done |
| AUTH-15 | P3: Password reset | — (not tasked; generated `PasswordsController` exists from T1 but SMTP wiring is explicitly deferred past M0) | Deferred |

**Coverage:** 15 total, 14 mapped to tasks, 1 explicitly deferred (AUTH-15) ⚠️ — this is an intentional P3 deferral per spec.md, not an oversight.
