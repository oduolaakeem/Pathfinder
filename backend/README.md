# Pathfinder Backend

Rails 8 API application for Pathfinder.

The backend validates and persists learner goals and current technical skills in PostgreSQL, used by the React + TypeScript frontend. See the [goal contract](../README.md#goal-creation-api) and [current-skills contract](../README.md#current-skills-api).

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

After preparing the database, start the development server from the repository root:

```bash
docker compose up -d app
```

Rails is available at http://localhost:3000/ with a health check at `/up`. Its host port is restricted to loopback.

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

## Current Skills

`CurrentSkill` belongs to `Goal`; `Goal` has one `CurrentSkill`. The `current_skills` table has a required `goal_id`, a foreign key to `goals`, a unique index on `goal_id`, a non-null text `description`, and timestamps. The unique index enforces one skills submission per goal, including racing inserts.

Description must be a string, cannot be blank or whitespace-only, and allows at most **2,000 Unicode code points**. Exactly 2,000 is valid; supplementary characters count once, while combining marks and emoji sequence components count separately.

Send `Content-Type: application/json` to `POST /api/goals/:goal_id/current_skills` using the saved goal ID:

```json
{"current_skills":{"description":"Ruby, SQL, Git; built a Rails application"}}
```

HTTP **201 Created** returns the persisted values:

```json
{"current_skills":{"id":1,"goal_id":1,"description":"Ruby, SQL, Git; built a Rails application"}}
```

Strong parameters permit only `description`. `goal_id` comes from the URL; client-supplied `id`, `goal_id`, `created_at`, and `updated_at` are ignored.

| Status | Condition | JSON response |
| --- | --- | --- |
| 400 | Missing or malformed `current_skills` object | `{"errors":{"current_skills":["is required"]}}` |
| 422 | Missing or blank description | `{"errors":{"description":["can't be blank"]}}` |
| 422 | Explicit non-string description, including `null` | `{"errors":{"description":["must be a string"]}}` |
| 422 | More than 2,000 code points | `{"errors":{"description":["is too long (maximum is 2000 characters)"]}}` |
| 404 | Unknown goal ID | `{"errors":{"goal":["not found"]}}` |
| 409 | Existing submission or racing duplicate insert | `{"errors":{"current_skills":["already submitted for this goal"]}}` |

Error responses do not persist an additional record or expose internal exception details. Only violations of the goal uniqueness index are translated into the duplicate-submission response.

## Logging Privacy

Rails filters `description` from request parameter logs, including nested goal and current-skills descriptions. Active Record SQL bind logging also redacts descriptions. Development query tags are disabled to retain prepared statements and bind filtering while keeping useful application and SQL logs enabled. Successful API responses still return the saved description.

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

The suite verifies the Rails test environment and PostgreSQL connection, goal and current-skills persistence, API validation/error contracts, Unicode boundaries, protected attributes, required goal association, foreign key, non-null and unique constraints, and request/SQL logging privacy. Privacy regressions also exercise the real development logging configuration against the test database and roll back synthetic records.

The latest reported full suite has 44 examples passing. PF-009 request and constraint tests are in `spec/requests/current_skills_spec.rb`; privacy regressions are in `spec/requests/current_skills_logging_spec.rb`. Sequential duplicate submissions and database uniqueness are covered; concurrent duplicate requests have not been exercised.

RSpec was configured in **PF-005 — RSpec / Test Foundation**.

## Limitations

This is a localhost-only proof of concept with no authentication or authorization. A goal ID does not prove ownership; do not expose the endpoint as a production multi-user service without access controls. Goal/skills retrieval and editing, AI analysis or feedback, and learning-path generation remain deferred.

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
