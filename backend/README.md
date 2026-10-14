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

### Development Rails PID storage

The Compose app service mounts `/app/backend/tmp/pids` as container-private temporary storage (`tmpfs`). Rails PID files are discarded when the container stops, preventing stale files from surviving container shutdown and restart. The mount masks this directory inside the container; it does not delete or change existing files in the host project directory.

Applying this configuration requires recreating only the app container; restarting an existing container does not apply a new mount. No image rebuild or database change is required. This is a development configuration, not a production deployment guarantee. A future non-root production configuration must provide appropriate runtime-directory permissions. Restarting Rails within a still-running container does not clear the temporary directory.

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

## AI Skill-Gap Assessment

`POST /api/goals/:goal_id/skill_gap` accepts JSON `{}`. Rails loads the persisted `Goal` and its `CurrentSkill`; client-supplied replacement descriptions are not used. Only **Become a backend developer** is supported, ignoring case and surrounding whitespace. Assessment requests do not create or modify records, and results are not persisted.

HTTP **200** returns the following shape (IDs are those of the saved records; classifications vary):

```json
{
  "skill_gap": {
    "goal_id": 1, "current_skill_id": 1,
    "profile": "backend_development", "profile_version": "1", "method": "ai_assisted",
    "identified_skills": ["Programming language", "SQL", "Git", "HTTP/API concepts"],
    "not_identified_skills": ["Automated testing"], "uncertain_skills": []
  },
  "learning_path": {
    "method": "curated", "catalogue_version": "1",
    "steps": [{
      "category": "Automated testing", "order": 1,
      "title": "Test input-validation behavior",
      "instruction": "Using an appropriate testing framework for your chosen language, test valid, blank, maximum-length, and over-limit inputs in a practice program.",
      "completion_evidence": "Automated test files and passing results covering all four input-validation cases."
    }],
    "next_action": {
      "category": "Automated testing", "order": 1,
      "title": "Test input-validation behavior",
      "instruction": "Using an appropriate testing framework for your chosen language, test valid, blank, maximum-length, and over-limit inputs in a practice program.",
      "completion_evidence": "Automated test files and passing results covering all four input-validation cases."
    }
  }
}
```

| Status | Condition | JSON response |
| --- | --- | --- |
| 404 | Unknown goal | `{"errors":{"goal":["not found"]}}` |
| 422 | Unsupported goal | `{"errors":{"goal":["is not supported for skill gap identification"]}}` |
| 422 | No saved skills | `{"errors":{"current_skills":["must be saved before identifying skill gaps"]}}` |
| 502 | Unusable AI response | `{"errors":{"skill_gap":["invalid provider result"]}}` |
| 503 | Provider unavailable | `{"errors":{"skill_gap":["provider unavailable"]}}` |

`GeminiSkillGapProvider.classify` uses standard-library Net::HTTP and JSON, verified HTTPS, a server-controlled endpoint, and the `x-goog-api-key` header. It requests structured JSON for exactly five categories, each classified as `identified`, `not_identified`, or `uncertain`. Validation rejects duplicate/missing/unexpected keys, unsupported values, blocked or incomplete output, and oversized responses. Final-text metadata is ignored. Connection/read/write timeouts are 3/30/5 seconds; payloads are bounded to 64 KiB and output to 1,024 tokens. No automatic retries occur. Typed failures map to generic errors without raw provider details.

### Curated learning path

The vertical slice is career goal → current skills → Gemini-assisted assessment → curated learning path → recommended next action. Gemini only classifies the five categories; it does not write activities. One provider request is made per assessment. After validation, the pure `LearningPathBuilder.call(classifications:)` derives a path without network or database access.

Catalogue version `"1"` uses language-flexible activities in fixed priority: Programming language → Git → SQL → HTTP/API concepts → Automated testing. Identified categories are omitted from immediate gap activities, without implying mastery. Not-identified categories receive practice; uncertain categories request clarification and practical evidence. Selected steps have contiguous orders starting at 1. All-identified assessments receive exactly one `Integrated practice` backend exercise.

The success envelope has exactly `skill_gap` and `learning_path`. The path contains exactly `method`, `catalogue_version`, `steps`, and `next_action`; each step contains exactly `category`, `order`, `title`, `instruction`, and `completion_evidence`. `next_action` equals the complete first step. Error contracts above are unchanged and contain no path. Evidence is suggested, not submitted or evaluated. Neither assessment nor path is persisted; no migration was added. These preliminary recommendations do not verify competence or job readiness.

### Secure local Gemini configuration

Privately create `.env.gemini` at the repository root with `GEMINI_API_KEY` and `GEMINI_MODEL=gemini-3.5-flash-lite`. The key must remain local: do not commit, print, or disclose it. Git ignores this file and Docker build exclusions cover `.env` and `.env.*`. Compose forwards Gemini variables only to the Rails service; they are never frontend configuration.

After ordinary database setup, run from the repository root:

```bash
docker compose --env-file .env.gemini config --quiet
docker compose --env-file .env.gemini up -d app frontend
```

Use `--quiet` when validating configuration to avoid printing resolved credentials. Compose and the provider default to `gemini-3.5-flash-lite`; `GEMINI_MODEL` can override it. Model access and free-tier quotas are project-dependent and may change.

### Explicit live checks

These are manual synthetic checks, separate from offline RSpec. Each command below initiates a real Gemini request and consumes quota. Run only with explicit authorization; neither script retries. Both require the exact `--live` argument and configured credentials. In PowerShell, omit `MSYS_NO_PATHCONV=1`.

Standalone connectivity and structured-output check:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env.gemini run --rm --no-deps \
  -w /app/backend app bundle exec ruby script/gemini_smoke_test.rb --live
```

Actual Rails endpoint check, using only synthetic records in the test database:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env.gemini run --rm \
  -w /app/backend -e RAILS_ENV=test app \
  bundle exec ruby script/skill_gap_live_test.rb --live
```

The endpoint harness requires the test environment/database, validates both assessment and path (including coverage, ordering, fallback, and next-action equality), rolls back synthetic records on success or failure, and verifies rollback. Scripts print only safe outcome, status, model, elapsed time, and predefined failure categories. They verify integration and response structure, not model accuracy. The standalone smoke script checks Gemini classification only; it does not derive a path.

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

The latest completed full suite has **165 examples, 0 failures, 0 pending**, exit code 0. PF-009 request and constraint tests are in `spec/requests/current_skills_spec.rb`; privacy regressions are in `spec/requests/current_skills_logging_spec.rb`. Sequential duplicate submissions and database uniqueness are covered; concurrent duplicate requests have not been exercised.

PF-015 has 23 builder examples, 26 assessment/path request examples, and five privacy examples; the provider retains 42 mocked examples. Coverage includes deterministic paths, clarification, fallback, exact response contracts, generic errors without paths, and sensitive-value exclusion from logs/responses using real development logging configuration. Automated tests use fake credentials and guarded/mocked transport, not live Gemini. The full suite now includes the previously pending PF-010 provider verification. Frontend verification passed 42 tests, lint, and build. Manual browser Scenario A passed 10/10 checks and Scenario B passed 7/7, including the all-identified fallback. Failed-request retry/reset was not manually exercised. The builder spec's focused RuboCop check passed; pre-existing style offenses elsewhere remain outside scope.

RSpec was configured in **PF-005 — RSpec / Test Foundation**.

## Offline evaluation foundation (PF-018)

This developer-only tool compares human-authored expected classifications with separately authored, explicitly simulated actual classifications. It is not part of the interactive learner journey. It uses the existing five categories and three labels, rejects invalid coverage and duplicate JSON keys, and returns complete comparison rows, differences, per-category counts, and aggregate totals in stable order.

Files:

- Evaluator: `app/services/skill_gap_evaluator.rb`
- CLI: `script/skill_gap_evaluation.rb`
- Annotated cases: `spec/fixtures/skill_gap_evaluation_cases.json`
- Simulated actuals: `spec/fixtures/skill_gap_evaluation_actuals.json`
- Regression specs: `spec/services/skill_gap_evaluator_spec.rb`

Run from the repository root using the already built backend image, with network disabled and the backend source mounted read-only (PowerShell):

```powershell
docker run --rm --network none --mount "type=bind,source=$PWD/backend,target=/app/backend,readonly" -w /app/backend -e GEMINI_API_KEY= pathfinder-app timeout 60s ruby script/skill_gap_evaluation.rb
```

This needs Docker Engine and the existing image, but no application services, Rails boot, PostgreSQL, Gemini credentials, or network access. With a working local Ruby interpreter, `ruby backend/script/skill_gap_evaluation.rb` also runs from the repository root. Fixture paths are fixed relative to the script; it accepts no arbitrary paths or URLs.

The CLI prints formatted JSON with `mode: "offline_simulated"`, `real_model_accuracy_measured: false`, and `agreement_basis: "simulated fixture agreement, not Gemini accuracy"`. The bundled report has **5 synthetic cases, 25 comparisons, 23 agreements (`matches`), and 2 disagreements (`mismatches`)**. Programming language, Git, and Automated testing each have 5 matches/0 mismatches; SQL and HTTP/API concepts each have 4/1. All 25 `rows` retain case ID, category, expected label, actual label, and match status; `differences` lists the two deliberately simulated disagreements.

Exit status is 0 for any valid completed report, including mismatches. Invalid fixtures or execution failure produce a nonzero exit and concise predefined stderr diagnostics without stack traces or unnecessary fixture contents. No API key or learner records are read; no network calls, database operations, project evaluation, or mastery assessment occur.

**Simulated fixture agreement is not a measurement of Gemini accuracy.** Human annotations can be subjective, and these five cases do not establish real-world model quality. Future model-quality evaluation requires separately obtained model outputs and an approved evaluation protocol.

PF-018 verification: **25 focused evaluator examples passed**, all three new Ruby files passed syntax and focused RuboCop, and the CLI produced identical output on two runs. Full backend regression passed: **165 examples, 0 failures, 0 pending, exit code 0**. No live Gemini requests were made; only existing Rack deprecation warnings were emitted. The previously completed 140-example PF-015 suite above remains historical evidence. PF-018 is implemented and merged into develop; PF-019 demo/submission preparation remains outstanding.

## Limitations

Capstone alignment and the seven operating-constraint tradeoffs are documented in the [submission package](../docs/PF-019-submission.md): **Learning That Stays With You**, primary Track 3 and secondary Track 2 design alignment. Offline fixture comparison does not establish model quality or learning retention. This backend is an invention-sprint proof of concept; the October 12–16, 2026 submission window has an unconfirmed closing time/timezone and submission platform/media requirements.

This is a localhost-only proof of concept with no authentication, authorization, or rate limiting. Goal IDs do not prove ownership. Consent is enforced in the browser UI, not by server-side authorization. Do not expose this as a production multi-user service. Learner text goes to Google's Gemini service; do not submit sensitive or confidential information. Classifications may be inaccurate and do not verify competence or job readiness. Only the supported backend-development goal is assessed. Retrieval, editing, assessment/path history, proficiency scoring, learner-project evaluation, advanced/adaptive paths, and production deployment remain deferred. PF-018 offline evaluation is implemented and merged into develop; PF-019 sprint review/demo and submission remains outstanding.

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
