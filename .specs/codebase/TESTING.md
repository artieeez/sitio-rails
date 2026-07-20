# Testing Conventions

## Framework

- **RSpec** (per STATE.md AD-004), replacing Rails' Minitest default
- No system/feature specs (Capybara) yet — added later if/when Hotwire flows need end-to-end browser-level coverage

## Test Coverage Matrix

| Code layer | Required test type | Parallel-Safe |
|---|---|---|
| Models (e.g. `User`, `Session`) | unit (model spec) | Yes |
| Controllers (e.g. `SessionsController`, `RegistrationsController`, `Admin::UsersController`) | integration (request spec) | Yes — as long as specs use per-example transactional DB isolation (Rails default) |
| Concerns used by controllers (e.g. `Authorization`) | unit (through the controller/model that includes them) — no direct spec unless logic is non-trivial | Yes |
| Rake tasks / generators | none for M0 | n/a |

## Gate Check Commands

| Gate | Command | When |
|---|---|---|
| quick | `bundle exec rspec <changed spec files>` | Per-task, during Execute |
| full | `bundle exec rspec` | Before marking a feature/milestone done |

## Coverage Gates

No enforced numeric coverage threshold yet (greenfield stage, per project decision 2026-07-15). Tests must exist and pass for every task's `Done when` — enforcement via required test presence, not a percentage floor. Revisit once the app has enough surface area for a meaningful baseline.

## Test file location

- Model specs: `spec/models/*_spec.rb`
- Request specs: `spec/requests/*_spec.rb`
- Co-located with the standard RSpec/Rails directory convention (not custom)

## Running

```bash
bundle exec rspec                     # full suite
bundle exec rspec spec/models/user_spec.rb   # scoped/quick
```
