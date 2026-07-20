# sitio-rails

Ruby on Rails rewrite of Sitio (school-trip payment management), replacing the NestJS + React stack in `sitio-monorepo`. See ADRs in `docs/adr/` for the accepted architecture decisions, and `.specs/project/` for the port plan.

## Stack

- Ruby 4.0 / Rails 8.1
- SQLite3 (rollback journal, no WAL — ADR-003)
- Hotwire (Turbo + Stimulus) + Tailwind CSS
- Minitest + fixtures
- Solid Cache / Queue / Cable

## Local setup

```bash
bundle install
bin/rails db:prepare
bin/dev          # or: bin/rails server
```

- App: http://localhost:3000/
- Health: http://localhost:3000/up

```bash
bin/rails test
```

Optional DB path override (used later for the OKE PVC mount):

```bash
SQLITE_DATABASE=/path/to/storage/development.sqlite3 bin/rails server
```

## Docker

```bash
docker build -t sitio .
docker run --rm -p 80:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e SQLITE_DATABASE=/rails/storage/production.sqlite3 \
  sitio
```

## Docs

- `docs/adr/` — architecture decisions
- `.specs/project/PROJECT.md` — vision, scope, constraints
- `.specs/project/ROADMAP.md` — milestone breakdown (M0–M5)
- `.specs/project/STATE.md` — decisions, blockers, todos
- `.specs/codebase/PORT-INVENTORY.md` — parity checklist from the NestJS/React app
