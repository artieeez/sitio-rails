# ADR-004: Hotwire and Tailwind UI; Wix Webhooks Only Public HTTP

- **Date**: 2026-07-15
- **Status**: Accepted
- **Deciders**: Artur Webber
- **Tags**: architecture, ui, hotwire, tailwind, wix, api
- **Related**: [ADR-001](./0001-use-ruby-on-rails-for-sitio.md), [ADR-002](./0002-self-contained-auth-admin-member.md)

## Context and Problem Statement

ADR-001 chooses Rails to avoid a separately managed frontend and backend. The current dashboard is a React SPA calling a Nest JSON API. For the rewrite we need a default UI approach, styling approach, and a clear rule for what may be reached without a session.

## Decision Drivers

- Prefer one Rails Deployment and same-origin HTML over a SPA + API split
- Keep the public attack surface minimal
- Use a mature, convention-friendly UI stack for AI-assisted development
- Preserve Wix integration via inbound webhooks

## Considered Options

- Keep Rails as API-only + separate JS SPA
- Hotwire/Turbo (+ Stimulus as needed) with Tailwind; HTML UI for the app
- Inertia.js (or React islands) on Rails

## Decision Outcome

Chosen option: **"Hotwire/Turbo with Tailwind; Wix webhooks as the only public HTTP surface"**.

The product UI will be built with **Hotwire/Turbo** (Stimulus where needed) and **Tailwind CSS**, served by the single Rails app. There will be **no public dashboard JSON API**.

The **only** intentionally public HTTP endpoints are **Wix webhooks** (verified by Wix’s mechanism, e.g. JWT), outside normal session auth. All other routes require an authenticated **admin** or **member** session ([ADR-002](./0002-self-contained-auth-admin-member.md)), until a future share-link ADR says otherwise.

Internal Turbo/fetch endpoints used by authenticated pages are allowed; they are not a product API for third parties.

### Positive Consequences

- One UI + server codebase; OpenAPI/SPA contract churn goes away
- Small public surface: webhooks only
- Tailwind + Hotwire fits Rails conventions and reduces custom frontend harness

### Negative Consequences

- Rich React dashboard UX must be rebuilt in Hotwire patterns
- Webhook verification and CSRF exceptions must be carefully scoped
- Highly interactive widgets may need Stimulus (or rare islands) instead of current React libraries

## Pros and Cons of the Options

### Rails API + JS SPA

- ✅ Could reuse some dashboard patterns
- ❌ Recreates the FE/BE split ADR-001 rejected
- ❌ Would expand public or cross-origin API surface

### Hotwire/Turbo + Tailwind ✅ Chosen

- ✅ Aligns with self-contained Rails and one Deployment
- ✅ Minimal public HTTP beyond Wix
- ❌ Learning/port cost away from React SPA

### Inertia / React islands as default

- ✅ Easier reuse of React mental model
- ❌ More JS harness than we want for this stage
- ❌ Blurs the “HTML-first Rails” boundary unless tightly limited

## Links

- Auth for non-webhook routes: [ADR-002](./0002-self-contained-auth-admin-member.md)
- Deferred: share-link URLs without account
