# Pathfinder Frontend

The Pathfinder frontend is a React and TypeScript application built with Vite.

It lets learners define and save a software-development career goal through the Rails API, with accessible validation feedback and saving states.

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

For integrated goal saving, use Docker below: Vite's `/api` proxy targets the Docker service hostname `app`, which is not resolvable by host-local Vite. Local Node tooling can run tests, lint, and builds.

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

The tests cover 500/501 supplementary Unicode characters, mixed ASCII/Unicode counts, and nonblank validation.

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

Authentication, goal retrieval, AI analysis, and learning-path generation are not implemented.
