# In-App Authentication Context

**Gathered:** 2026-07-15
**Spec:** `.specs/features/inapp-auth/spec.md`
**Status:** Ready for design

---

## Feature Boundary

Email/password session auth with exactly two roles (`admin`, `member`), a working first-admin bootstrap, and route-level protection by default — the walking skeleton every later protected feature depends on. Scope is fixed per `spec.md`; the decisions below clarify HOW, not WHAT.

---

## Implementation Decisions

### First-admin bootstrap mechanism

- A dedicated signup route/form exists that is only usable while zero `User` records exist
- Submitting it creates the first user with `role = admin`
- Once any user exists, this route SHALL stop being usable (redirect to login, or 404/disabled) — it must not be replayable to mint extra admins
- This satisfies AUTH-10/11/12 in `spec.md`

### Member account creation policy

- Admin-only invite/creation: only an `admin`-role user can create new accounts (member or admin)
- No open/self-service signup route exists beyond the one-time first-admin form above
- This satisfies AUTH-13/14 in `spec.md`

### Session lifetime & remember-me

- Fixed expiry (not sliding, no "remember me" checkbox for M0)
- No specific duration was mandated by the user — **Agent's Discretion**: default to a fixed 14-day session cookie expiry unless a shorter value is clearly better practice at implementation time; document the chosen value in Design

### Failed-login handling

- Rate-limit / lockout after repeated failed attempts (not unlimited plain retry)
- No specific threshold/window was mandated — **Agent's Discretion**: use Rails' built-in controller rate limiting (if available in the Rails version chosen during scaffold) with a sensible default (e.g., lock after 5 failed attempts within a rolling window); document the chosen threshold in Design
- Lockout should fail generically (same error message as invalid credentials) to avoid leaking account existence

### Last-admin protection (self-demote/self-delete)

- Explicitly **not handled** in M0 — no block, no warning
- Recorded as a deferred idea (see below), not a bug to fix now

---

## Agent's Discretion

- Exact session cookie expiry duration (default: 14 days fixed)
- Exact failed-login lockout threshold and window (default: 5 attempts / rolling window, using Rails' built-in rate limiting if the chosen Rails version supports it)
- Exact copy/wording of the generic login error and lockout message

---

## Specific References

No specific UI/product references given — standard Rails session-auth conventions apply (e.g., `has_secure_password`, a `sessions` controller, a `Current` attributes pattern for the logged-in user).

---

## Deferred Ideas

- [ ] Last-admin protection (block or warn when the only admin tries to self-demote/self-delete) — captured during: `inapp-auth` discuss, explicitly deferred past M0
- [ ] Password reset flow — already P3 in spec.md, not blocking M0 demo
