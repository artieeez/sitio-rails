# Testing Conventions

## Framework

- **Minitest + fixtures** (per STATE.md AD-004 / AD-006), matching rails-dev. No RSpec, no FactoryBot.
- No system/feature specs (Capybara) yet — added later if/when Hotwire flows need end-to-end browser-level coverage

## Test Coverage Matrix

| Code layer | Required test type | Parallel-Safe |
|---|---|---|
| Models (e.g. `User`, `Session`, `School`) | model tests under `test/models/` | Yes |
| Controllers / request flows | integration tests under `test/integration/` | Yes — transactional fixtures (Rails default) |
| Concerns used by controllers | covered through the including controller/model unless logic is non-trivial | Yes |
| Rake tasks / generators | none for M0 | n/a |

## Gate Check Commands

| Gate | Command | When |
|---|---|---|
| quick | `bin/rails test <changed test files>` | Per-task, during Execute |
| full | `bin/rails test` | Before marking a feature/milestone done |

## Coverage Gates

No enforced numeric coverage threshold yet (greenfield stage, per project decision 2026-07-15). Tests must exist and pass for every task's `Done when` — enforcement via required test presence, not a percentage floor. Revisit once the app has enough surface area for a meaningful baseline. rails-dev targets roughly 1:1 test-to-code line ratio on domain logic.

## Test file location

- Model tests: `test/models/*_test.rb`
- Integration tests: `test/integration/*_test.rb`
- Fixtures: `test/fixtures/*.yml` (namespaced models mapped via `set_fixture_class` in `test/test_helper.rb`)

## Running

```bash
bin/rails test                              # full suite
bin/rails test test/models/user_test.rb     # scoped/quick
```
