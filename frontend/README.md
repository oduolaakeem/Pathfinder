# Pathfinder Frontend

The Pathfinder frontend is a React and TypeScript application built with Vite.

It lets learners define and save a software-development career goal, then describe and save their current technical skills through the Rails API, with accessible validation feedback, saving states, and persisted confirmations.

## Technology Stack

- React 19
- TypeScript 6
- Vite 8
- ESLint
- Node.js 24
- Docker and Docker Compose

## Project Structure

```text
frontend/
├── public/
├── src/
├── .dockerignore
├── .gitignore
├── Dockerfile
├── eslint.config.js
├── index.html
├── package.json
├── package-lock.json
├── tsconfig.app.json
├── tsconfig.json
├── tsconfig.node.json
└── vite.config.ts
```

## Local Development

Node.js 24 and npm are required.

From the `frontend/` directory, install dependencies:

```bash
npm ci
```

Start the development server:

```bash
npm run dev
```

Open http://localhost:5173/ in a browser.

For integrated goal and skills saving, use Docker below: Vite's `/api` proxy targets the Docker service hostname `app`, which is not resolvable by host-local Vite. Local Node tooling can run tests, lint, and builds.

## Docker Development

Docker provides an isolated Node.js environment for frontend development.

From the repository root, build the frontend image:

```bash
docker compose build frontend
```

After preparing the database as described in the [root README](../README.md#docker-development-environment), start Rails and the frontend:

```bash
docker compose up -d app frontend
```

Open http://localhost:5173/ in a browser.

Check the service status:

```bash
docker compose ps frontend
```

View frontend logs:

```bash
docker compose logs frontend
```

The frontend source directory is bind-mounted into the container for development. Container dependencies are stored separately at `/app/node_modules` to avoid conflicts with dependencies installed on the host operating system.

Stop the Docker Compose environment:

```bash
docker compose down
```

## Verification

Run the regression tests locally with Node.js 24's built-in test runner:

```bash
npm test
```

The 17 Node regression tests cover goal 500/501 and skills 2,000/2,001 Unicode-code-point boundaries, supplementary characters, mixed ASCII/Unicode text, and nonblank validation. Current-skills API tests verify the request URL/body, persisted response parsing, HTTP 400/422/404/409 handling, network failures, and malformed responses.

Run the production build locally:

```bash
npm run build
```

Run ESLint locally:

```bash
npm run lint
```

Alternatively, with the frontend container running, execute the same checks inside Docker:

```bash
docker compose exec frontend npm test
docker compose exec frontend npm run build
docker compose exec frontend npm run lint
```

The build runs TypeScript compilation followed by Vite's production build.

Generated dependencies and build output, including `node_modules/` and `dist/`, are excluded from version control.

## Current Scope

The frontend foundation was established in **PF-006 — React + TypeScript Frontend Foundation**.

PF-008 provides the goal form, a 500-code-point limit, and display of the persisted goal returned by `POST /api/goals`. See the [API contract](../README.md#goal-creation-api).

PF-009 adds the **Your current technical skills** section after successful goal creation. `CurrentSkillsForm.tsx` uses the actual saved goal ID when calling `POST /api/goals/:goal_id/current_skills`. See the [current-skills API contract](../README.md#current-skills-api).

The labelled textarea provides an example such as “Ruby, SQL, Git; built a small Rails application.” `currentSkillsDescription.ts` requires nonblank text and counts Unicode code points consistently with Rails, up to 2,000. Over-limit text stays editable but cannot be submitted; the counter includes supplementary characters correctly.

`api/currentSkills.ts` provides the typed fetch client and validates response shapes. The form shows saving feedback, prevents duplicate requests while saving, associates field errors with the textarea, announces errors and success accessibly, and restores focus after validation failures. HTTP 400/422/404/409, network failures, and malformed responses receive useful feedback.

On success, the form displays the persisted description returned by Rails and removes the submission form to prevent accidental repeats for that goal. A 409 response also prevents further submissions. Saving a new goal provides a fresh skills form.

Manual browser acceptance passed 6/6 checks for the integrated journey. Automated frontend coverage currently focuses on validation and API handling; form interaction coverage is manual.

## Limitations

Saved goal context is held only in the current UI session. Refreshing does not restore the skills form or saved skills; persisted records remain in PostgreSQL, but retrieval and editing are deferred.

This is a localhost-only proof of concept with no authentication or authorization. A goal ID does not prove ownership; the endpoint must not be exposed as a production multi-user service without access controls. AI analysis or feedback and learning-path generation are not implemented.
