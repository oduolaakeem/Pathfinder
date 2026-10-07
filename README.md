# Pathfinder

**AI-powered learning-to-opportunity platform**

Pathfinder helps learners answer one core question:

> **From where I am now, how do I get to where I want to be?**

## Product Promise

> **Pathfinder tells you what you're missing, what to learn next, and how to prove you've learned it.**

## MVP Focus

The initial MVP is focused on **self-directed technical learners**, beginning with software-development learners.

The product will help a learner:

1. Define a concrete technical career goal.
2. Describe their current skills and experience.
3. Identify the skills they are missing.
4. Generate a personalized learning path.
5. Practice through learning activities and projects.
6. Submit evidence of learning.
7. Receive AI evaluation and feedback.
8. Get an adaptive next action.

## Core Product Loop

```text
GOAL
  ↓
CURRENT SKILLS
  ↓
SKILL-GAP ANALYSIS
  ↓
PERSONALIZED LEARNING PATH
  ↓
LEARNING / PRACTICE
  ↓
EVIDENCE
  ↓
AI EVALUATION
  ↓
NEXT ACTION
  ↓
(updated learning state)
```

## Technology Direction

### Backend

* Ruby
* Rails 8
* API-first architecture
* PostgreSQL
* RSpec
* Docker

### Frontend

* React
* TypeScript

### AI

* OpenAI API
* Codex throughout the software-development workflow

## Development Approach

Pathfinder is being developed using:

* Test-driven development where practical
* Small vertical slices
* Clean Git workflows
* Dockerized development
* Automated testing
* Explicit planning, review, and documentation
* Intentional Codex/agentic development workflows

## Docker Development Environment

Pathfinder uses Docker for a reproducible local development environment.

Current foundation:

- Ruby 4.0.7
- Docker Desktop with WSL 2 on Windows
- Docker Compose

Build the development image:

```bash
docker compose build
```

Verify the container:

```bash
docker compose run --rm app
```

Expected output includes:

```text
ruby 4.0.7
```

The Rails application, PostgreSQL configuration, RSpec setup, and frontend will be introduced in later tickets.

## Current Status

**Docker development foundation complete**

Completed tickets:

- **PF-001 — Repository & Project Foundation**
- **PF-002 — Docker Development Environment**

Next ticket:

> **PF-003 — Rails 8 API Foundation**

The repository and Docker development foundations are established. The Rails application has not yet been generated.
