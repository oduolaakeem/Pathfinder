# Pathfinder Backend

Rails 8 API application for Pathfinder.

## Current Foundation

- Ruby 4.0.7
- Rails 8.1.4
- API-only Rails configuration
- Docker-based development environment

The backend currently uses Rails' default SQLite configuration.

PostgreSQL will be introduced in **PF-004 — PostgreSQL Configuration**.

RSpec will be introduced in **PF-005 — RSpec / Test Foundation**.

## Verify the Backend

From the repository root:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app bin/rails --version
```

To verify the Rails application boots:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails runner 'puts "Pathfinder Rails API booted: #{Rails.version}"'
```
