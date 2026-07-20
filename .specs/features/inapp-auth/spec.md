# In-App Authentication Specification

**Milestone:** M0 — Rails Bootstrap & In-App Auth
**Scope size:** Complex (new domain for this app, real user-facing gray areas) — full spec + Discuss required before Design
**Related ADRs:** ADR-002 (self-contained auth, admin/member roles)

## Problem Statement

Sitio today has no in-app identity at all — Traefik + TinyAuth handle auth at the edge and the Nest backend only reads trusted headers. ADR-002 requires Rails to own email/password authentication with exactly two roles (`admin`, `member`), with TinyAuth removed from Sitio's path entirely. This feature is the walking skeleton every other protected feature (M1-M4) depends on.

## Goals

- [ ] Any user can log in with email/password and get a persistent session
- [ ] Every route is protected by default; only an explicit allowlist (future Wix webhook routes, health check) is public
- [ ] Exactly two roles exist — `admin` and `member` — and at least one authorization check demonstrably distinguishes them
- [ ] A first admin can always be created without needing an existing admin (no chicken-and-egg lockout)

## Out of Scope

| Feature | Reason |
|---|---|
| SSO / external IdP / OIDC | ADR-002 explicitly removes TinyAuth from Sitio's path; no edge auth going forward |
| Share-link / tokenless access | Explicitly deferred to a future ADR per ADR-002 — do not design this now |
| Richer RBAC beyond admin/member | ADR-002 caps v1 authorization at exactly two roles |
| Multi-factor authentication | Not mentioned in ADR-002; adds scope not requested for v1 |
| Wix webhook auth (JWT) | Separate mechanism, separate feature (M2) — webhooks are the one intentionally public surface per ADR-004, not part of this session-based auth |

---

## User Stories

### P1: Log in and out with email/password ⭐ MVP

**User Story**: As a user (admin or member), I want to log in with my email and password and stay logged in across requests, so I can use the protected app without re-authenticating constantly.

**Why P1**: Nothing else in the app is reachable without this.

**Acceptance Criteria**:

1. WHEN a user submits valid email/password on the login form THEN a session SHALL be established via a secure, HTTP-only cookie
2. WHEN a user submits an invalid email/password combination THEN the system SHALL show a generic error (not revealing whether the email exists) and SHALL NOT establish a session
3. WHEN an authenticated user clicks logout THEN the session SHALL be destroyed and they SHALL be redirected to the login page
4. WHEN any request is made without a valid session AND the route is not on the public allowlist THEN the system SHALL redirect to the login page
5. WHEN a CSRF token is missing or invalid on a state-changing request THEN the request SHALL be rejected

**Independent Test**: Log in with valid credentials, confirm access to a protected demo page; log out, confirm redirect to login on next protected request.

---

### P1: Exactly two roles — admin and member ⭐ MVP

**User Story**: As the system, I want every user to have exactly one role (`admin` or `member`) so that authorization checks are simple and consistent everywhere.

**Why P1**: ADR-002's entire authorization model rests on this being true from day one.

**Acceptance Criteria**:

1. WHEN a `User` record is created THEN it SHALL have exactly one role value, either `admin` or `member` (no null, no other value)
2. WHEN a member-role user requests an admin-only action (demo: a dummy admin-only page) THEN the system SHALL deny access (403 or redirect) without exposing admin-only content
3. WHEN an admin-role user requests the same admin-only action THEN the system SHALL allow it
4. WHEN a role check is written THEN it SHALL be reusable (a single authorization helper/concern), not duplicated ad hoc per controller

**Independent Test**: Create one admin and one member user; confirm the member is denied the admin-only demo page and the admin is allowed.

---

### P1: First-admin bootstrap ⭐ MVP

**User Story**: As the operator standing up a fresh environment, I want a way to create the first admin account without already having an admin session, so the app isn't locked out of itself on day one.

**Why P1**: Without this, a fresh deploy (or fresh dev checkout) has literally no way to log in.

**Acceptance Criteria**:

1. WHEN the app has zero users THEN a bootstrap mechanism SHALL allow creating exactly one admin account
2. WHEN at least one admin already exists THEN the bootstrap mechanism SHALL no longer be usable (cannot be replayed to mint extra admins)
3. WHEN the bootstrap mechanism is used THEN the created user SHALL have `role = admin`

**Independent Test**: On a fresh database, run the bootstrap mechanism, confirm exactly one admin user exists and log in as them; confirm re-running the mechanism does not create a second admin.

*(Exact mechanism — seed task vs. UI signup flow vs. rake task — is a gray area, see Discuss below.)*

---

### P2: Member account creation

**User Story**: As an admin, I want to create member accounts for my team so that they can log in without needing database access.

**Why P2**: Needed for the app to be usable by more than one person, but not needed to demo the M0 walking skeleton (one admin logging in is enough to prove the mechanism).

**Acceptance Criteria**:

1. WHEN an admin creates a new user THEN they SHALL be able to set that user's role (`admin` or `member`)
2. WHEN a member is created THEN they SHALL be able to log in with the credentials set at creation time

**Independent Test**: As an admin, create a member account, log out, log in as that member, confirm member-level (not admin-level) access.

*(Whether this is self-service signup vs. admin-only invite is a gray area, see Discuss below.)*

---

### P3: Password reset

**User Story**: As a user who forgot their password, I want to reset it via email so I'm not permanently locked out.

**Why P3**: Real need eventually, but not required to prove the M0 walking skeleton and can be added once core session/role auth is solid.

**Acceptance Criteria**:

1. WHEN a user requests a password reset with a valid email THEN a reset link SHALL be sent (mechanism TBD — may be deferred past M0 if no email delivery is configured yet)

---

## Edge Cases

- WHEN a logged-in user's session cookie is tampered with THEN the request SHALL be treated as unauthenticated, not crash
- WHEN two browser tabs are open and the user logs out in one THEN the other tab's next request SHALL also be treated as unauthenticated
- WHEN a password is submitted THEN it SHALL be stored only as a `bcrypt` (or equivalent) digest, never in plaintext or in logs
- WHEN the audit log (M4) is eventually wired in THEN login/logout events SHOULD be attributable to a user id — note this dependency, don't build the audit log itself here
- WHEN an admin demotes/deletes themselves and is the only admin THEN the system SHOULD warn or block this to avoid re-triggering the bootstrap problem (behavior TBD — see Discuss)

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| AUTH-01 | P1: Log in/out | Design | Pending |
| AUTH-02 | P1: Log in/out | Design | Pending |
| AUTH-03 | P1: Log in/out | Design | Pending |
| AUTH-04 | P1: Log in/out | Design | Pending |
| AUTH-05 | P1: Log in/out | Design | Pending |
| AUTH-06 | P1: Two roles | Design | Pending |
| AUTH-07 | P1: Two roles | Design | Pending |
| AUTH-08 | P1: Two roles | Design | Pending |
| AUTH-09 | P1: Two roles | Design | Pending |
| AUTH-10 | P1: First-admin bootstrap | Design | Pending |
| AUTH-11 | P1: First-admin bootstrap | Design | Pending |
| AUTH-12 | P1: First-admin bootstrap | Design | Pending |
| AUTH-13 | P2: Member account creation | Design | Pending |
| AUTH-14 | P2: Member account creation | Design | Pending |
| AUTH-15 | P3: Password reset | Design | Pending |

**Coverage:** 15 total, 0 mapped to tasks, 15 unmapped ⚠️ (Design/Tasks not yet run — spec is pending Discuss first)

---

## Success Criteria

- [ ] A user can log in, reach a protected page, and log out
- [ ] A member is denied an admin-only demo action; an admin is allowed
- [ ] A first admin can be created on a fresh database with no prior users
- [ ] No plaintext passwords anywhere (DB, logs)
- [ ] Every route is protected by default except an explicit, small public allowlist

---

## Open Gray Areas (→ Discuss before Design)

These are HOW-to-implement questions the spec above deliberately left open. Per the spec-driven workflow, Discuss must run before Design/Tasks for this feature:

1. **First-admin bootstrap mechanism** — seed task (`rails db:seed` creates admin from `ENV` vars), one-time rake task, or a UI signup form that only works when zero users exist?
2. **Member account creation policy** — admin-only invite (admin creates account + sets temp password) vs. open self-service signup that defaults new accounts to `member`?
3. **Session lifetime & remember-me** — fixed expiry, sliding expiry, or "remember me" checkbox with longer-lived cookie?
4. **Failed-login handling** — plain retry with no lockout, or rate-limit/lockout after N failed attempts?
5. **Last-admin protection** — block demoting/deleting the only remaining admin, warn only, or don't handle it in M0?
