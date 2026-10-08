# Pathfinder Backend

Rails 8 API application for Pathfinder.

The backend provides the application and API layer for Pathfinder and will expose the functionality used by the React + TypeScript frontend.

## Current Foundation

- Ruby 4.0.7
- Rails 8.1.4
- API-only Rails configuration
- PostgreSQL 17
- Docker-based development environment
- RSpec 3.13 with rspec-rails 7.1

Development and test environments use PostgreSQL through Docker Compose.

## Database

Pathfinder uses PostgreSQL.

The development and test databases are:

```text
pathfinder_development
pathfinder_test
```

When running through Docker Compose, Rails connects to the PostgreSQL service using:

```text
DATABASE_HOST=db
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
```

These credentials are development-only defaults.

Production database configuration is supplied through:

```text
DATABASE_URL
```

Production credentials must not be committed to the repository.

## Prepare the Database

From the repository root, start PostgreSQL:

```bash
docker compose up -d db
```

Prepare the Rails development and test databases:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails db:prepare
```

Verify the active database adapter:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails runner 'puts ActiveRecord::Base.connection.adapter_name'
```

Expected output:

```text
PostgreSQL
```

## Verify the Backend

Verify the Rails version:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails --version
```

Expected output:

```text
Rails 8.1.4
```

Verify that the Rails application boots:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails runner 'puts "Pathfinder Rails API booted: #{Rails.version}"'
```

Expected output:

```text
Pathfinder Rails API booted: 8.1.4
```

## Automated Testing

The backend uses RSpec for automated testing.

Tests run against the PostgreSQL test database (`pathfinder_test`).

From the repository root, run the complete test suite:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend \
  -e RAILS_ENV=test app \
  bundle exec rspec
```

To run an individual spec:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend \
  -e RAILS_ENV=test app \
  bundle exec rspec spec/integration/database_connection_spec.rb
```

The initial integration smoke test verifies the Rails test environment, PostgreSQL adapter, and test database connection.

RSpec was configured in **PF-005 — RSpec / Test Foundation**.

## Windows Git Bash

When running Docker commands from Git Bash on Windows, use:

```text
MSYS_NO_PATHCONV=1
```

for commands that pass Linux paths such as `/app/backend` to Docker.

This prevents Git Bash from automatically converting the container path into a Windows filesystem path.

## Credentials

The Rails master key:

```text
config/master.key
```

must remain local and must not be committed.

The encrypted:

```text
config/credentials.yml.enc
```

file may be version controlled without exposing the master key.
