# Pathfinder

Pathfinder is an AI-powered learning-to-opportunity platform designed to help self-directed technical learners turn a career goal into a clear, achievable learning journey.

Many learners know what they want to become but struggle to understand what skills they need, what they should learn next, and whether the work they are doing is actually moving them closer to their goal.

Pathfinder helps bridge that gap.

A learner defines a career goal and shares their current skills. Pathfinder identifies relevant skill gaps and creates a personalized learning path broken into manageable next steps. As the learner completes projects and other practical work, they can provide evidence of their progress and receive AI-assisted feedback. Their learning path can then adapt based on what they have demonstrated rather than simply following a fixed curriculum.

> Pathfinder tells you what you're missing, what to learn next, and how to prove you've learned it.

## Initial Focus

The initial proof of concept focuses on self-directed software-development learners.

The first vertical slice will demonstrate the journey from:

1. Creating a learning goal
2. Adding current skills
3. Analyzing the skill gap
4. Generating a personalized learning path
5. Returning that path to the learner

## Architecture

Pathfinder is structured as a separate frontend and backend:

```text
React + TypeScript
        |
     HTTP/JSON
        |
Rails 8 API
        |
   PostgreSQL
```

The Rails API currently lives under:

```text
backend/
```

The frontend will be introduced in a later ticket.

## Technology Stack

### Backend

- Ruby 4.0.7
- Rails 8.1.4
- PostgreSQL 17
- RSpec 3.13 with rspec-rails 7.1

### Frontend

- React
- TypeScript

### AI

- OpenAI API
- Codex-assisted development workflow

### Development Environment

- Docker
- Docker Compose

## Repository Structure

```text
pathfinder/
├── backend/
├── .dockerignore
├── .gitattributes
├── .gitignore
├── AGENTS.md
├── compose.yaml
├── Dockerfile
└── README.md
```

The repository will expand as additional Pathfinder modules are implemented.

## Development Workflow

Pathfinder follows a ticket-driven development workflow:

```text
Plan → Test/Verify → Implement → Verify → Review → Commit
```

Each ticket should:

1. Identify the intended user or engineering outcome.
2. Define acceptance criteria.
3. Inspect the existing implementation before making changes.
4. Implement the smallest useful change.
5. Verify the change.
6. Review the resulting diff.
7. Update relevant documentation.
8. Commit the completed ticket.

Feature work is developed on dedicated branches and merged into `develop` through pull requests.

## Docker Development Environment

Pathfinder uses Docker to provide a reproducible local development environment.

The current environment includes:

- Ruby 4.0.7
- Rails 8.1.4
- PostgreSQL 17
- Docker Compose

Build the application image:

```bash
docker compose build
```

Start PostgreSQL:

```bash
docker compose up -d db
```

View running services:

```bash
docker compose ps
```

Stop the environment:

```bash
docker compose down
```

PostgreSQL data is stored in a named Docker volume so development data can persist across container restarts.

## PostgreSQL

Pathfinder uses PostgreSQL for Rails development and test environments.

The Docker Compose environment provides the PostgreSQL service as:

```text
db
```

The development and test databases are:

```text
pathfinder_development
pathfinder_test
```

Prepare the databases:

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

Production database configuration is supplied through `DATABASE_URL`. Production credentials must not be stored in the repository.

> When using Git Bash on Windows, `MSYS_NO_PATHCONV=1` prevents Git Bash from converting Linux container paths such as `/app/backend` into Windows paths.

## Automated Testing

Pathfinder uses RSpec for automated backend testing.

RSpec runs inside Docker against the PostgreSQL test database (`pathfinder_test`), keeping tests isolated from the development database.

Run the complete backend test suite from the repository root:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend \
  -e RAILS_ENV=test app \
  bundle exec rspec
```

Run an individual test file:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend \
  -e RAILS_ENV=test app \
  bundle exec rspec spec/integration/database_connection_spec.rb
```

The initial smoke test verifies that Rails runs in the test environment and connects to PostgreSQL using `pathfinder_test`.

The test foundation was established in **PF-005 — RSpec / Test Foundation**.

## Backend

The Rails API is located in:

```text
backend/
```

Verify the Rails version:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails --version
```

Verify that the Rails application boots:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app \
  bin/rails runner 'puts "Pathfinder Rails API booted: #{Rails.version}"'
```

## Security and Configuration

Secrets and private credentials must not be committed to the repository.

In particular:

```text
backend/config/master.key
```

is ignored by Git.

The encrypted Rails credentials file may be version controlled while the corresponding master key remains local.

Local Docker database credentials are development-only. Production database credentials must be supplied through environment configuration.

## Current Status

**RSpec / Test Foundation complete**

Completed tickets:

- **PF-001 — Repository & Project Foundation**
- **PF-002 — Docker Development Environment**
- **PF-003 — Rails 8 API Foundation**
- **PF-004 — PostgreSQL Configuration**
- **PF-005 — RSpec / Test Foundation**

Next ticket:

> **PF-006 — React + TypeScript Frontend Foundation**

The repository, Docker development environment, Rails API, PostgreSQL configuration, and automated backend test foundation are established.
