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

The latest completed suite has **35 Node tests passing**. Tests cover goal 500/501 and skills 2,000/2,001 Unicode-code-point boundaries, supplementary characters, mixed ASCII/Unicode text, and nonblank validation. Current-skills API tests verify the request URL/body, persisted response parsing, HTTP 400/422/404/409 handling, network failures, and malformed responses. `tests/skill-gap.test.mjs` covers the typed assessment client, exact empty-body request, strict result validation, HTTP 404/422/502/503 errors, network failures, and malformed/non-JSON responses using injected fetch without live Gemini calls.

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

## AI Skill-Gap Assessment

PF-010 adds `SkillGapAssessment.tsx` after successful current-skills submission. To enable the backend's Gemini configuration, follow the [secure setup instructions](../backend/README.md#secure-local-gemini-configuration) and start services with `docker compose --env-file .env.gemini up -d app frontend` from the repository root. Credentials belong only to Rails, never to frontend code.

The interface discloses that saved goal and skills descriptions are sent to Google's Gemini service, warns against sensitive or confidential information, and explains that results are preliminary rather than verification of proficiency or job readiness. An initially unchecked, labelled consent checkbox is required before explicit submission; analysis never starts automatically.

`api/skillGap.ts` sends `{}` to `POST /api/goals/:goal_id/skill_gap` using the saved goal ID, without descriptions or credentials. It strictly validates identifiers, profile metadata, and all five approved catalogue labels appearing exactly once across three groups. Raw provider output is never displayed or stored in localStorage.

While loading, the interface prevents repeated submissions and announces that analysis may take approximately 20–30 seconds. Safe errors cover 404/422/502/503, network failures, and malformed responses. Recoverable failures offer an explicit retry; 404/422 require resolving the saved data or supported goal rather than another assessment attempt.

Results display backend-development profile version 1 and these groups, with explanatory text for empty groups:

- Skills identified in your description
- Skills not identified in your description
- Skills requiring clarification

Identified mentions do not prove competence, and not-identified categories do not prove missing ability. Accessible status/error announcements accompany loading, success, and failure. A new saved goal resets consent, errors, and results; late responses from an unmounted assessment are ignored. Successful assessments do not trigger further requests automatically.

Synthetic live browser acceptance passed, including loading feedback, repeated-click protection, all five categories, and limitation disclosure. Automated frontend coverage focuses on pure validation and API handling; component lifecycle, keyboard interaction, and layout still rely on manual checks. Latest completed lint and production build passed; this documentation step does not rerun them.

## Limitations

Saved goal context is held only in the current UI session. Refreshing does not restore the skills form or saved skills; persisted records remain in PostgreSQL, but retrieval and editing are deferred.

Consent and assessment results are also session-only: assessments are not persisted or restored after refresh.

This is a localhost-only proof of concept with no authentication, authorization, or rate limiting. Goal IDs do not establish ownership; browser consent is not server-side authorization. Do not expose the endpoint as a production multi-user service. Only “Become a backend developer” is supported, ignoring case and surrounding whitespace. AI classifications may be inaccurate; Gemini free-tier availability and quotas may change. Learner text is transmitted to Google, so avoid sensitive or confidential information. Assessment history, retrieval/editing, learning-path generation, proficiency scoring, and production deployment are outside the current scope.
