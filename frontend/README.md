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

The latest completed suite has **42 Node tests passing**, including 25 focused assessment/path API tests. Tests cover goal/skills Unicode boundaries, validation, persisted response parsing, and safe errors. `tests/skill-gap.test.mjs` validates the combined `skill_gap` and `learning_path` envelope, exact fields, category coverage/order, contiguous numbering, fallback, next-action equality, and nonblank text bounded to 2,000 Unicode code points. Injected fetch prevents live Gemini calls. Latest backend verification passed 165 RSpec examples with 0 failures and 0 pending; frontend lint and production build passed.

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

## Curated learning path and next action

PF-015 completes the current vertical slice: career goal → current skills → Gemini-assisted assessment → curated learning path → recommended next action. Gemini classifies five backend-development categories; it does not generate activities. One assessment request returns both objects, with no second Gemini or browser API request for the path.

`api/skillGap.ts` returns the validated `skillGap` and `learningPath` together. The path has `method: "curated"`, `catalogue_version: "1"`, ordered `steps`, and `next_action` equal to the complete first step. `SkillGapAssessment.tsx` renders an accessible ordered list with category, title, instruction, and suggested completion evidence, followed by a highlighted starting activity.

The deterministic, language-flexible catalogue orders Programming language → Git → SQL → HTTP/API concepts → Automated testing, skipping identified categories without declaring mastery. Uncertain categories invite clarification and practice. When all five categories are identified, a single integrated backend exercise is displayed. Recommendations are preliminary and informed by self-reported skills; evidence is suggested, not submitted or evaluated. No progress controls, uploads, learner-project evaluation, or verified job-readiness claims are provided.

Assessment and path share one success state, reset together for a new goal, and are cleared before retry. Existing unchecked consent, explicit submission, loading controls, safe errors, and stale-response protection remain. Neither object is stored in localStorage/sessionStorage or restored after refresh.

PF-015 manual browser Scenario A passed **10/10** checks and Scenario B passed **7/7**, confirming all five categories identified and the integrated-practice fallback. Failed-request retry/reset was not manually exercised; component/lifecycle automation remains a coverage gap. PF-018 offline evaluation is implemented and merged into develop, separate from the learner interface. Remaining roadmap: PF-019 sprint review/demo and submission; advanced adaptive paths remain deferred.

## Limitations

The [submission package](../docs/PF-019-submission.md) addresses **Learning That Stays With You**, primary Track 3 and secondary Track 2 design alignment, with current support/limitations/future work for all seven operating constraints. Accessible controls and clear next actions do not establish measured retention or comprehensive accessibility. The interface remains English-only with no local-opportunity integration. This is an invention-sprint proof of concept; the official October 12–16, 2026 window does not yet have a confirmed closing time/timezone, destination/platform, or mandatory media format.

Saved goal context is held only in the current UI session. Refreshing does not restore the skills form or saved skills; persisted records remain in PostgreSQL, but retrieval and editing are deferred.

Consent, assessment results, and learning paths are session-only: assessments and paths are not persisted or restored after refresh.

This is a localhost-only proof of concept with no authentication, authorization, or rate limiting. Goal IDs do not establish ownership; browser consent is not server-side authorization. Do not expose the endpoint as a production multi-user service. Only “Become a backend developer” is supported, ignoring case and surrounding whitespace. AI classifications may be inaccurate; Gemini free-tier availability and quotas may change. Learner text is transmitted to Google, so avoid sensitive or confidential information. Assessment/path history, retrieval/editing, advanced/adaptive paths, learner-project evaluation, proficiency scoring, and production deployment are outside the current scope.
