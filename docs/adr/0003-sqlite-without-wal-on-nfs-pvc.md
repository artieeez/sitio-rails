# ADR-003: Colocated SQLite3 without WAL on NFS PVC

- **Date**: 2026-07-15
- **Status**: Accepted
- **Deciders**: Artur Webber
- **Tags**: architecture, database, sqlite, ops, rails, oke
- **Related**: [ADR-001](./0001-use-ruby-on-rails-for-sitio.md)

## Context and Problem Statement

Sitio currently uses PostgreSQL via Prisma in the Nest stack. The Rails rewrite aims to be self-contained: one app Deployment without a separate database service. The product is still in development, so preserving existing Postgres data is not required.

On OKE today, Sitio durable storage is an **NFS-backed PVC** (`storageClassName: nfs-client`, `ReadWriteMany`) — see `artr-gitops` staging/production Postgres PVCs. Network filesystems are a poor fit for SQLite **WAL** mode; default rollback-journal mode is the safer choice on this infrastructure for now.

## Decision Drivers

- Colocate persistence with the app to minimize moving parts
- Reuse current OKE NFS PVC pattern (no new storage class required yet)
- Avoid SQLite WAL on NFS (locking / durability pitfalls over network mounts)
- Greenfield schema is acceptable (no production data migration)
- Keep a clear upgrade path to local disk + WAL later if needed

## Considered Options

- Keep managed/cluster PostgreSQL for Rails
- Colocated SQLite3 **with WAL** on a local/non-NFS volume
- Colocated SQLite3 **without WAL** on the existing NFS PVC
- SQLite on ephemeral disk only (no PVC)

## Decision Outcome

Chosen option: **"Colocated SQLite3 without WAL on the existing NFS PVC"**.

Rails will use **SQLite3** in **default journal mode (no WAL)**, with the DB file on an **NFS PVC** (`nfs-client`, RWX), mounted into the single Rails Deployment — same storage class pattern used today for Sitio Postgres data. Data is **greenfield**.

**Still single writer:** NFS RWX does *not* mean multiple Rails replicas may share one SQLite file. Keep **one writer** (one Rails Deployment replica for DB writes / jobs). RWX only reflects how the cluster provisions the volume today.

**Deferred:** if concurrent performance or journal-mode limits become a problem, prepare infrastructure for a **dedicated local (non-NFS) volume** and then switch SQLite to **WAL** in a superseding ADR. Do not enable WAL while the DB lives on NFS.

### Positive Consequences

- No separate Postgres service for the Rails deploy
- Fits current OKE/GitOps storage (`nfs-client`) without new volume types
- Avoids known SQLite+WAL-on-NFS failure modes
- Explicit later path: local volume + WAL when the product needs it

### Negative Consequences

- Default journal mode is typically less concurrent/performant than WAL under load
- NFS + SQLite still needs care (latency, locking, backups); not as robust as local disk
- Horizontal scale-out of writers remains out of scope
- Postgres-specific features from the Nest stack will not carry over

## Pros and Cons of the Options

### Cluster PostgreSQL

- ✅ Familiar; easy multi-replica web
- ❌ Extra service vs self-contained goal
- ❌ Unnecessary for current stage

### SQLite3 with WAL on local/non-NFS volume

- ✅ Better concurrency and the usual SQLite production posture
- ❌ Requires storage/infra work we are not doing yet (dedicated non-NFS volume)
- ❌ Wrong fit for today’s NFS PVC

### SQLite3 without WAL on NFS PVC ✅ Chosen

- ✅ Matches current OKE volume setup
- ✅ Safer than WAL on NFS for v1
- ❌ Weaker concurrency / more NFS sensitivity than local+WAL
- ❌ Still single-writer at the app layer

### Ephemeral SQLite only

- ✅ Fine for throwaway local experiments
- ❌ Unsuitable as the cluster deploy target

## Links

- Current PVC pattern: `artr-gitops/apps/sitio-staging/postgres/pvc.yaml`, `artr-gitops/apps/sitio-production/postgres/pvc.yaml` (`nfs-client`, `ReadWriteMany`)
- Related: one Rails Deployment ([ADR-001](./0001-use-ruby-on-rails-for-sitio.md))
- Explicitly out of scope: Postgres → SQLite data migration; enabling WAL before non-NFS storage exists
