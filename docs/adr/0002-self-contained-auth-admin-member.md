# ADR-002: Self-Contained Auth with Admin and Member Roles

- **Date**: 2026-07-15
- **Status**: Accepted
- **Deciders**: Artur Webber
- **Tags**: architecture, security, auth, rails
- **Related**: [ADR-001](./0001-use-ruby-on-rails-for-sitio.md), [ADR-004](./0004-hotwire-tailwind-wix-webhooks-only-public.md)

## Context and Problem Statement

ADR-001 adopts a unified Rails app to reduce organizational complexity. Sitio today authenticates via Traefik → TinyAuth (and related IdP plumbing), which adds an external component and ingress coupling. For an early-stage, self-contained product, identity and authorization should live inside the Rails app.

## Decision Drivers

- Prefer a self-contained deployment path (no forwardAuth / TinyAuth in Sitio’s request path)
- Keep authorization simple for current team size and product stage
- Support email/password login as the v1 identity method
- Leave room for share-link access later without designing it now

## Considered Options

- Keep TinyAuth / edge OIDC in front of Rails
- In-app Rails authentication (email/password) with admin and member roles
- Richer RBAC / multi-tenant ACL from day one

## Decision Outcome

Chosen option: **"In-app Rails authentication (email/password) with admin and member roles"**.

Sitio will authenticate users with **email/password** sessions owned by the Rails app. TinyAuth (and Sitio-specific forwardAuth) will be removed from the Sitio ingress path. Authorization v1 is exactly two roles: **admin** and **member**.

**Deferred (explicit non-decision):** share-link URL access without an account will be designed in a later ADR when needed. Do not invent tokenized public routes until then, except for Wix webhooks ([ADR-004](./0004-hotwire-tailwind-wix-webhooks-only-public.md)).

### Positive Consequences

- One fewer external dependency for local and cluster deploys
- Auth behavior is reviewable and testable inside the app
- Simple role model is easy for humans and AI agents to apply consistently

### Negative Consequences

- Rails owns password storage, reset flow, session cookies, and CSRF
- Lose SSO / shared IdP convenience with other cluster apps unless reintroduced later
- First-admin bootstrap and invite/signup policy must be defined in implementation

## Pros and Cons of the Options

### Keep TinyAuth / edge OIDC

- ✅ Reuses existing GitOps auth plumbing
- ✅ Shared login with other cluster apps
- ❌ External component conflicts with “self-contained” goal
- ❌ Ingress/auth debugging spans Traefik, TinyAuth, and the app

### In-app email/password + admin/member ✅ Chosen

- ✅ Self-contained; matches ADR-001 direction
- ✅ Minimal authorization surface for current stage
- ❌ Password and session lifecycle are application responsibilities
- ❌ Share links still need a future ADR

### Richer RBAC from day one

- ✅ More expressive permissions later without redesign
- ❌ Overbuilt for current needs; slows the port

## Links

- Supersedes (Sitio path only): TinyAuth forwardAuth usage for dashboard/backend ingress
- Follow-up ADR (planned): share-link access without account
