# ADR-001: Use Ruby on Rails for Sitio

- **Date**: 2026-07-15
- **Status**: Accepted
- **Deciders**: Artur Webber
- **Tags**: architecture, stack, rails, monorepo

## Context and Problem Statement

Sitio is early-stage and currently structured as a JavaScript monorepo with a NestJS backend and a React dashboard. That split forces separate toolchains, contracts, deploys, and AI/agent harness for each side. We need a stack whose operational and organizational cost matches the size of the product, while still giving AI-assisted development a mature, convention-heavy framework to lean on.

## Decision Drivers

- Minimize organizational complexity of owning separate frontend and backend stacks
- Prefer ecosystem maturity and strong conventions over assembling many JS libraries
- Reduce harness / scaffolding needed for effective AI-assisted development
- Keep stack churn low (APIs and product surface should not move under us frequently)
- Fit the current size and stage of the project (small team, early product)

## Considered Options

- NestJS + React (current split stack)
- Next.js (full-stack JavaScript)
- Ruby on Rails (unified application)

## Decision Outcome

Chosen option: **"Ruby on Rails (unified application)"**, because it collapses the frontend/backend organizational boundary into one app, and Rails’ mature conventions reduce the amount of glue and harness that a JavaScript split (or even a JS full-stack option) tends to require for productive AI-assisted development.

### Positive Consequences

- One application boundary for routing, views, domain logic, and persistence
- Convention-over-configuration reduces setup and day-to-day decision load
- Mature ecosystem (gems, patterns, docs) suits AI coding without custom agent scaffolding
- Closer match between stack complexity and project stage

### Negative Consequences

- Implies a future port away from the existing NestJS + React codebase
- Temporary dual knowledge of old and new stacks during migration
- Losing existing JS-specific investments (Nx targets, some React UI, Nest modules) until rewritten
- Rails server-rendered or Hotwire-style UI may differ from the current SPA dashboard UX until parity is rebuilt

## Pros and Cons of the Options

### NestJS + React (current split stack)

- ✅ Clear separation of API and UI concerns
- ✅ Team already has working code and patterns in this repo
- ❌ High organizational cost: two apps, two toolchains, shared contract drift
- ❌ Too much complexity for the current size and stage of the project
- ❌ JS ecosystem typically needs more harness for consistent AI-assisted workflows

### Next.js (full-stack JavaScript)

- ✅ Single deployable UI + server surface in one JS framework
- ✅ Avoids a pure SPA + separate API split
- ❌ Still inherits JS ecosystem fragmentation and harness needs
- ❌ Framework APIs have changed frequently, raising migration and learning cost
- ❌ Product/docs noise from the broader Vercel ecosystem adds distraction without clear benefit here

### Ruby on Rails (unified application) ✅ Chosen

- ✅ One cohesive app instead of separately managed frontend and backend
- ✅ Mature conventions and ecosystem suited to AI-assisted development with less custom harness
- ✅ Better fit for early-stage product focus (shipping features over assembling infrastructure)
- ❌ Requires intentional port of existing Nest/React work
- ❌ Different language and UI paradigm from the current monorepo

## Links

- Existing backend ADRs (domain-level, Nest era): `apps/backend/.specs/adr/`
- Follow-up decisions: [ADR-002](./0002-self-contained-auth-admin-member.md) (auth/roles), [ADR-003](./0003-sqlite-without-wal-on-nfs-pvc.md) (SQLite), [ADR-004](./0004-hotwire-tailwind-wix-webhooks-only-public.md) (Hotwire/Tailwind/Wix)
- Follow-up: TLC Spec Driven port plan (to be written after this ADR set)
