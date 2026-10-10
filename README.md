# Pathfinder

Pathfinder is an AI-powered learning-to-opportunity platform designed to help self-directed technical learners turn a career goal into a clear, achievable learning journey.

Many learners know what they want to become but struggle to understand what skills they need, what they should learn next, and whether the work they are doing is actually moving them closer to their goal.

Pathfinder helps bridge that gap.

The planned journey lets a learner define a career goal and share their current skills, then receive skill-gap analysis, a personalized learning path, and AI-assisted feedback on practical work. These AI capabilities are not implemented yet.

PF-008 and PF-009 implement this journey: define and save a software-development career goal → describe current technical skills → save → view confirmation. React displays the persisted descriptions returned by Rails, with accessible validation feedback, saving states, and Unicode code-point counters. Goals allow 500 code points; current skills allow 2,000.

> Pathfinder tells you what you're missing, what to learn next, and how to prove you've learned it.

## Initial Focus

The initial proof of concept focuses on self-directed software-development learners.

The broader planned journey is:

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

The Rails API is located in `backend/`.

The React + TypeScript frontend is located in `frontend/`.

Vite proxies `/api` requests to `http://app:3000` on Docker's internal network. Rails owns validation and persistence.

## Technology Stack

### Backend

- Ruby 4.0.7
- Rails 8.1.4
- PostgreSQL 17
- RSpec 3.13 with rspec-rails 7.1

### Frontend

- React 19
- TypeScript 6
- Vite 8
- ESLint
- Node.js 24

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
├── frontend/
│   ├── public/
│   ├── src/
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
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
- Node.js 24
- React + TypeScript frontend with Vite
- Docker Compose

Build the application images:

```bash
docker compose build
```

Start PostgreSQL:

```bash
docker compose up -d db
```

Prepare the databases on first setup or after new migrations, then start Rails and Vite:

```bash
MSYS_NO_PATHCONV=1 docker compose run --rm -w /app/backend app bin/rails db:prepare
docker compose up -d app frontend
```

Open the React interface at [http://localhost:5173/](http://localhost:5173/). Rails runs at [http://localhost:3000/](http://localhost:3000/), with a health check at `/up`. Both published ports are restricted to host loopback. If PostgreSQL is still starting, wait until it is ready before running `db:prepare`.

The command examples use Git Bash syntax. In PowerShell, omit `MSYS_NO_PATHCONV=1`; it is only needed for Git Bash path conversion.

View running services:

```bash
docker compose ps
```

Stop the environment:

```bash
docker compose down
```

PostgreSQL data is stored in a named Docker volume so development data can persist across container restarts.

The frontend uses a separate Docker-managed `/app/node_modules` volume to avoid conflicts between Linux and Windows dependencies.

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

The suite covers PostgreSQL connectivity, goal and current-skills creation and validation, Unicode boundaries, protected attributes, database constraints, and request/SQL log redaction. Development-logging regressions run against the test database and roll back their synthetic records.

The test foundation was established in **PF-005 — RSpec / Test Foundation**.

## Frontend

The React + TypeScript application is located in:

```text
frontend/
```

The frontend uses Vite for development and production builds.

### Docker Frontend Development

Build the frontend Docker image from the repository root:

```bash
docker compose build frontend
```

Start the frontend development server:

```bash
docker compose up -d app frontend
```

Open the application in your browser:

[http://localhost:5173/](http://localhost:5173/)

Verify the frontend container:

```bash
docker compose ps frontend
```

View the frontend logs:

```bash
docker compose logs --tail=30 frontend
```

Run the production build:

```bash
docker compose exec frontend npm run build
```

Run ESLint:

```bash
docker compose exec frontend npm run lint
```

Run the frontend regression tests using Node's built-in test runner:

```bash
docker compose exec frontend npm test
```

These tests cover goal and skills Unicode boundaries, nonblank client validation, and the current-skills API client's requests, persisted response parsing, and error handling.

### Local Frontend Development

Node.js 24 and npm are required.

From the repository root:

```bash
cd frontend
npm ci
npm run dev
```

Open http://localhost:5173/ in your browser.

To run local verification:

```bash
npm test
npm run build
npm run lint
```

The integrated goal-and-skills saving flow requires Docker development: the existing Vite proxy uses the Docker service hostname `app`, which is not available to a host-local Vite process. Local Node commands remain useful for frontend tests, linting, and builds.

See `frontend/README.md` for additional setup and development instructions.

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

## Goal Creation API

Send JSON to `POST /api/goals`, either through Vite at `http://localhost:5173/api/goals` or directly to Rails at `http://localhost:3000/api/goals`, with `Content-Type: application/json`:

```json
{"goal":{"description":"Become a backend developer"}}
```

Success returns HTTP **201 Created** and the persisted record (the ID is server-generated):

```json
{"goal":{"id":1,"description":"Become a backend developer"}}
```

Description must be a nonblank string of at most 500 Unicode code points. Combining marks and emoji sequence components count separately. Invalid descriptions return HTTP **422** without creating a record:

```json
{"errors":{"description":["can't be blank"]}}
```

Non-string descriptions return `"must be a string"`; descriptions over the limit return `"is too long (maximum is 500 characters)"` in the same error structure. A missing top-level goal object returns HTTP **400**:

```json
{"errors":{"goal":["is required"]}}
```

Only `description` is permitted; client-supplied IDs and timestamps are ignored.

## Current Skills API

After saving a goal, send JSON to `POST /api/goals/:goal_id/current_skills`, replacing `:goal_id` with the saved goal's ID. Use `Content-Type: application/json`; the endpoint is available through the same Vite proxy or directly through Rails.

```json
{"current_skills":{"description":"Ruby, SQL, Git; built a Rails application"}}
```

Success returns HTTP **201 Created** with server-generated IDs and the persisted description:

```json
{"current_skills":{"id":1,"goal_id":1,"description":"Ruby, SQL, Git; built a Rails application"}}
```

Each goal permits one current-skills submission. Description must be a nonblank string of at most **2,000 Unicode code points**, using the same counting rule as goals. Only `description` is permitted; the goal association comes from the URL and client-supplied IDs and timestamps cannot override server-controlled values.

| Status | Condition | JSON response |
| --- | --- | --- |
| 400 | Missing or malformed `current_skills` object | `{"errors":{"current_skills":["is required"]}}` |
| 422 | Missing, empty, or whitespace-only description | `{"errors":{"description":["can't be blank"]}}` |
| 422 | Explicit non-string description, including `null` | `{"errors":{"description":["must be a string"]}}` |
| 422 | More than 2,000 code points | `{"errors":{"description":["is too long (maximum is 2000 characters)"]}}` |
| 404 | Unknown goal ID | `{"errors":{"goal":["not found"]}}` |
| 409 | Skills already submitted for this goal | `{"errors":{"current_skills":["already submitted for this goal"]}}` |

Failures do not create an additional record. The database unique index also prevents duplicate submissions from racing inserts.

## Security and Configuration

Secrets and private credentials must not be committed to the repository.

In particular:

```text
backend/config/master.key
```

is ignored by Git.

The encrypted Rails credentials file may be version controlled while the corresponding master key remains local.

Local Docker database credentials are development-only. Production database credentials must be supplied through environment configuration.

Goal and current-skills descriptions are filtered from Rails request parameters and Active Record SQL bind logs. Development query tags are disabled to preserve prepared statements and bind filtering while retaining application and SQL logging.

## Current Limitations

This is a localhost-only proof of concept with no authentication or authorization. A goal ID does not prove ownership; the endpoint must not be exposed as a production multi-user service without access controls.

Goal/skills retrieval and editing, goal listing/deletion, AI analysis or feedback, and learning-path generation remain deferred. Saved goal context and confirmations exist only in the current UI session. Refreshing does not restore the skills form or saved skills, although persisted records remain in PostgreSQL.

## Current Status

**PF-009 — Learner Current Skills implemented; awaiting merge.**

Completed tickets:

- **PF-001 — Repository & Project Foundation**
- **PF-002 — Docker Development Environment**
- **PF-003 — Rails 8 API Foundation**
- **PF-004 — PostgreSQL Configuration**
- **PF-005 — RSpec / Test Foundation**
- **PF-008 — Learner Goal Definition (merged into develop)**

Current ticket:

- **PF-009 — Learner Current Skills**

The repository contains the integrated React goal-to-skills flow, Rails API, PostgreSQL persistence, and backend/frontend regression tests. Latest reported PF-009 verification: 44 backend examples and 17 frontend tests passing, frontend lint and production build passing, and 6/6 manual browser acceptance checks passing. Coverage includes request validation, database constraints, privacy logging, and the journey through the Vite proxy. Concurrent duplicate requests have not been exercised; sequential duplicates and database uniqueness are covered.

Repository engineering instructions are in `AGENTS.md`.

Both backend and frontend development environments are supported through Docker Compose.
