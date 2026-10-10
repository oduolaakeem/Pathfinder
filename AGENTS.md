# Pathfinder — Codex Repository Instructions

## 1. Project

Pathfinder is an AI-powered learning-to-opportunity platform.

Its core mission is to help a learner answer:

> “From where I am now, how do I get to where I want to be?”

Product promise:

> “Pathfinder tells you what you're missing, what to learn next, and how to prove you've learned it.”

The initial product focus is self-directed technical learners, beginning with software-development learners.

The project source of truth is the Pathfinder bootstrap/project document. These repository instructions govern how engineering work is performed.

---

## 2. Scope and Active Work

Work must be driven by the current Pathfinder ticket and its acceptance criteria.

Before changing the repository:

1. Identify the active ticket.
2. Read the relevant project requirements.
3. Understand the intended user outcome.
4. Define the smallest useful implementation.
5. Identify tests and verification steps.
6. Implement only the agreed scope.

Do not silently invent requirements.

If a requested change would materially affect architecture, product scope, security, data modeling, or the project roadmap, stop and surface the decision before implementing it.

Do not begin future-ticket work merely because it is technically convenient.

---

## 3. Engineering Principles

Follow these principles throughout the project:

- Build the smallest useful thing.
- Prefer vertical slices over isolated infrastructure work.
- Use TDD for meaningful application behavior.
- Keep boundaries explicit.
- Prefer simple, conventional solutions.
- Avoid premature abstraction and over-engineering.
- Validate AI-generated output rather than trusting it blindly.
- Make important behavior observable and testable.
- Keep prompts and AI context reproducible.
- Document important architectural and product decisions.
- Optimize for a clear learner outcome.
- Do not move to the next ticket until the current ticket is verified.

---

## 4. Development Workflow

Use this workflow for substantive changes:

1. **Plan**
   - Confirm scope.
   - Identify affected components.
   - Define acceptance criteria.
   - Identify risks and assumptions.

2. **Test**
   - Write or update the relevant tests first when behavior is being introduced or changed.

3. **Implement**
   - Make the smallest change required to satisfy the tests and acceptance criteria.

4. **Verify**
   - Run focused tests first.
   - Run the broader relevant test suite.
   - Check formatting, linting, or other project checks when applicable.

5. **Review**
   - Inspect the diff.
   - Check for unnecessary complexity.
   - Check security implications.
   - Check documentation impact.
   - Confirm the implementation matches the ticket.

6. **Commit**
   - Create a small, meaningful commit.
   - Keep unrelated changes out of the commit.

---

## 5. TDD and Testing

Testing is part of implementation, not an afterthought.

For behavior changes, follow:

> Fail → Implement → Pass → Refactor

Prefer tests that verify observable behavior rather than implementation details.

Tests should be:

- deterministic;
- focused;
- readable;
- independent;
- meaningful to the acceptance criteria.

Use RSpec for backend testing.

When fixing a bug, add or update a regression test whenever practical.

A ticket is not complete merely because the code runs; its intended behavior must be verified.

---

## 6. Technology Direction

The planned technology stack is:

### Backend

- Ruby
- Rails 8
- API-first architecture
- PostgreSQL
- RSpec
- Docker

### Frontend

- React
- TypeScript

### AI

- OpenAI API
- Codex-oriented development workflow

Use the technologies defined by the project unless an explicit architectural decision changes them.

Do not introduce additional frameworks, libraries, services, or infrastructure without a concrete need.

Detailed technology conventions should be established when the relevant implementation is introduced.

---

## 7. Architecture Boundaries

Pathfinder follows an API-first architecture:

> React + TypeScript → HTTP/JSON → Rails 8 API → PostgreSQL / AI services

Keep frontend and backend responsibilities clearly separated.

The backend owns:

- business rules;
- persistence;
- authentication and authorization;
- API contracts;
- AI orchestration;
- validation of important AI outputs.

The frontend owns:

- presentation;
- user interaction;
- client-side state and behavior;
- communication with the backend API.

Do not duplicate core business rules unnecessarily across frontend and backend.

Architecture should remain as simple as the current product scope allows.

---

## 8. Rails and API Conventions

When Rails implementation is introduced:

- Prefer conventional Rails patterns.
- Keep responsibilities focused.
- Avoid unnecessary service-object or abstraction layers.
- Validate input at appropriate boundaries.
- Keep domain behavior testable.
- Keep controllers thin.
- Keep API responses predictable and explicit.
- Treat API contracts as deliberate interfaces.

Detailed Rails and API conventions should evolve with the actual application rather than being prematurely specified here.

---

## 9. Frontend Conventions

When the React/TypeScript application is introduced:

- Prefer clear component responsibilities.
- Keep reusable components genuinely reusable.
- Keep API communication explicit.
- Keep domain logic out of purely presentational components where practical.
- Prefer typed interfaces for API data.
- Test meaningful user-facing behavior.

Do not introduce a large frontend architecture before the product requires it.

---

## 10. AI and OpenAI Integration

AI is a core product capability, not an uncontrolled dependency.

AI-related implementation must:

- define the purpose of each AI operation;
- provide explicit context;
- use reproducible prompts or prompt structures where practical;
- validate structured AI output;
- handle invalid, incomplete, or unexpected output;
- avoid treating generated content as automatically correct;
- keep important AI behavior testable;
- document significant prompt or behavior changes.

The initial AI capabilities are conceptually:

- Goal Analyzer
- Skill Gap Analyzer
- Path Planner
- Learning Evaluator

Do not create a large multi-agent system unless the product requirements demonstrate a concrete need.

Codex should be used to improve planning, implementation, debugging, refactoring, testing, review, and documentation rather than merely generating large amounts of code.

---

## 11. Security

Security is a first-class concern.

Never commit:

- API keys;
- passwords;
- tokens;
- private credentials;
- production secrets;
- sensitive user data.

Use environment variables or appropriate secret-management mechanisms for credentials.

Validate untrusted input.

Do not expose secrets through:

- API responses;
- logs;
- error messages;
- test fixtures;
- source control.

Authentication, authorization, AI credentials, and user-submitted content must be treated as security-sensitive boundaries.

Security requirements must be considered whenever a ticket introduces a new data flow or external integration.

---

## 12. Git Workflow

Use the repository branches defined by the project:

- `main`
- `develop`
- `feature/PF-XXX-short-description`

Keep commits:

- small;
- focused;
- meaningful;
- related to one logical change.

Prefer commit messages that clearly describe the purpose of the change.

Use conventional, descriptive commit messages where practical, for example:

- `feat: add learner goal creation`
- `test: cover skill gap analysis`
- `fix: validate learning path response`
- `docs: complete repository agent instructions`

### Pull Requests

For each completed feature ticket:

1. Push the feature branch to the remote repository.
2. Open a pull request targeting `develop`.
3. Describe the problem, implementation, and verification performed.
4. Review the changes for correctness, security, and unnecessary complexity.
5. Merge only after the ticket's acceptance criteria are satisfied.
6. Return to `develop`, pull the merged changes, and remove the completed feature branch when appropriate.

Do not commit feature work directly to `main` or `develop`.

---

## 13. Verification Requirements

Before declaring a ticket complete:

- Run relevant automated tests.
- Run linting or formatting checks where applicable.
- Verify the intended user-facing behavior.
- Inspect `git diff` for unintended changes.
- Confirm that no secrets or sensitive data are included.
- Check that documentation reflects significant behavior changes.
- Record any tests that could not be executed and explain why.

Do not claim that a test or verification step passed unless it was actually executed successfully.

---

## 14. Definition of Done

A Pathfinder ticket is complete when:

1. Its acceptance criteria are satisfied.
2. Relevant tests pass.
3. The implementation has been reviewed.
4. Security and architecture implications have been considered.
5. Required documentation is updated.
6. Changes are committed to the ticket's feature branch.
7. A pull request has been reviewed and merged into `develop`.
8. The local `develop` branch is synchronized with the remote.

If any requirement cannot be met, explicitly document the outstanding work.

---

## 15. Working With AI Coding Agents

AI coding agents must:

- Read this file before making repository changes.
- Identify the active ticket and its scope.
- Explain the intended implementation before substantial changes.
- Make focused, reviewable changes.
- Prefer incremental implementation over large rewrites.
- Use tests and verification to support claims of correctness.
- Ask for clarification when requirements are ambiguous.
- Avoid modifying unrelated files.
- Avoid committing, pushing, or merging without explicit authorization.
- Report what changed, what was verified, and what remains incomplete.

The human developer retains responsibility for architectural decisions, security-sensitive changes, and final approval.
