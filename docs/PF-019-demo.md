# Pathfinder four-minute demonstration

Official theme: **Learning That Stays With You**. Primary: **Track 3 — Guidance, Pathways & Opportunity**. Secondary design alignment: **Track 2 — Engagement & Staying in the Learning Journey**, with no demonstrated long-term retention claim. This is an invention-sprint proof of concept, not a production launch.

Official submission window: **October 12–16, 2026**. Closing time/timezone, destination/platform, and mandatory media-format requirements remain **UNCONFIRMED**. Four minutes is this project's demo target, not a confirmed official media requirement.

Use synthetic data only. A live assessment sends synthetic descriptions to Gemini and consumes quota; obtain separate authorization before that action. Preparation commands below do not request inference.

## Completed presentation rehearsal

On October 14, 2026, the user confirmed the PF-019 presentation rehearsal completed with **8/8 checks passed**, a duration of **1 minute**, and **no issues reported**. The assessment was demonstrated using previously verified browser acceptance evidence. **No fresh Gemini request or new live end-to-end assessment occurred during this rehearsal.** The individual eight check descriptions were not supplied, so this aggregate result does not mark every extended checklist item below complete.

Evidence boundaries:

- Previous live browser acceptance: PF-015 scenarios passed **10/10 and 7/7** checks, including the integrated-practice fallback.
- Current presentation rehearsal: user-confirmed **8/8**, **1 minute**, using that prior acceptance evidence.
- Offline synthetic evaluation: previously verified **23/25 simulated comparisons** agreed; no new evaluator execution is claimed for this rehearsal and this is not measured Gemini accuracy.

The four-minute script below remains an **optional extended presentation**, not the duration of the completed rehearsal.

## Preparation and readiness

From the repository root in PowerShell, after Docker Engine is available and the existing images/databases are ready:

```powershell
docker compose --env-file .env.gemini config --quiet
docker compose up -d --no-deps --no-build --no-recreate db
docker exec pathfinder-db-1 timeout 15s pg_isready -h 127.0.0.1 -p 5432
docker compose --env-file .env.gemini up -d --no-deps --no-build app frontend
docker compose ps app db frontend
Invoke-WebRequest -Uri http://127.0.0.1:3000/up -TimeoutSec 30 -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest -Uri http://127.0.0.1:5173/ -TimeoutSec 30 -UseBasicParsing | Select-Object StatusCode
```

The documented AI-enabled Compose startup may recreate app/frontend if configuration changed. If recreation is prohibited for the session, stop and obtain approval rather than forcing it. PostgreSQL is not recreated by its command. First-time setup/build/database preparation is described in the root README; it is not part of this demo and must be authorized separately if needed.

Never display `.env.gemini` or resolved Compose configuration. If database readiness or health fails, pause; do not repeatedly restart services, remove PID files, run migrations, or reset data without a separate diagnosis/approval. Allow a short bounded Rails boot period before concluding failure.

Open [Pathfinder](http://127.0.0.1:5173/). Keep unrelated tabs/apps closed when practical because this Windows machine has limited memory.

## Synthetic inputs

- Goal: **Become a backend developer**
- Current skills: **I wrote Python programs and used Git branches and commits. I have no SQL, HTTP/API, or automated testing experience.**

Live classifications are not guaranteed. Explain the actual returned result rather than promising specific labels. Prior browser evidence covers both a normal path and the all-identified integrated fallback.

## Optional four-minute extended script

| Time | Action and narration |
| --- | --- |
| 0:00–0:25 | “For Learning That Stays With You, Pathfinder addresses Track 3: self-directed learners struggle to turn career ambitions and current skills into practical next actions.” Explain the narrow invention-sprint scope and Track 2 design alignment without claiming measured retention. |
| 0:25–1:05 | Save the synthetic goal, then current skills. Point out persisted confirmations and that the skills belong to the saved goal. |
| 1:05–1:35 | Read the Gemini data-processing disclosure and preliminary-result limitation. Show unchecked consent, then affirm consent and explicitly request assessment only if authorized. Point out loading and duplicate-click protection; allow the request to finish. |
| 1:35–2:35 | Explain identified/not-identified/uncertain groups. Show the ordered curated path, clarification wording, suggested evidence, and recommended next action matching step 1. “Gemini classifies descriptions; these activities are curated, not AI-generated.” |
| 2:35–3:20 | Show the offline report: “Twenty-three of twenty-five simulated comparisons agree; this is not Gemini accuracy.” Cite prior evidence: 165 backend examples, 42 frontend tests, lint/build, and browser checks 10/10 and 7/7. Distinguish automated/acceptance evidence from learning outcomes. |
| 3:20–4:00 | Explain seven tradeoffs: strict validation supports credibility; text and one call limit scope but Gemini still needs connectivity; accessible controls need broader audit; personalization supports one profile; consent/key isolation do not provide production access control; English-only content needs localization; local opportunities are not integrated. Track 2 engagement/retention remains unmeasured. End with the practical suggested starting activity. |

Timing is a target, not an inference guarantee. If latency exceeds the allowance, acknowledge it and use labelled prior evidence; do not retry automatically.

Use the [seven-constraint matrix](PF-019-submission.md#seven-operating-constraints) for follow-up questions: each constraint separates current support, limitations, and proposed future work. Do not present those proposals as implemented features or invent learner research.

## Offline evaluator

PowerShell, from the repository root, using the existing backend image:

```powershell
docker run --rm --network none --mount "type=bind,source=$PWD/backend,target=/app/backend,readonly" -w /app/backend -e GEMINI_API_KEY= pathfinder-app timeout 60s ruby script/skill_gap_evaluation.rb
```

No Rails boot, PostgreSQL, key, or network is needed. Expected formatted JSON: `mode: "offline_simulated"`, `real_model_accuracy_measured: false`, 5 cases, 25 rows/comparisons, 23 matches, 2 mismatches, per-category counts, and all differences. Both deliberate differences are in the ambiguous case. Exit 0 means a valid report completed, not that all comparisons agreed.

**Simulated fixture agreement is not a measurement of Gemini accuracy.** This tool tests reproducible comparison machinery, not real-world AI quality or resistance to prompt injection.

## Safe fallback

- If Gemini fails, show the safe error and explain provider dependence. Do not silently replace live results with fixtures or make repeated calls.
- If local services fail, show a previously recorded synthetic walkthrough or screenshots, clearly labelled with their prior capture context. Such media still needs preparation; none is assumed to exist.
- If no media exists, walk through source-backed response examples and the offline evaluator, explicitly stating that this is not a current live demonstration.
- The offline evaluator works without application services when Docker Engine and the image remain available. If the engine is unavailable and Windows Ruby cannot launch, use a labelled previously captured report, not a claimed fresh execution.

## Privacy and claim checks

- [ ] Use only the synthetic goal/skills above; remove personal browser content from the capture area.
- [ ] Do not show keys, environment files, headers, terminal secrets, resolved Compose configuration, or raw provider bodies.
- [ ] Do not record learner logs or unrelated data; share only reviewed screen regions/report content.
- [ ] Explain explicit consent and third-party text processing before any live assessment.
- [ ] Describe paths as curated and AI-informed, results as preliminary, and evidence as suggested.
- [ ] Make no project-evaluation, mastery/job-readiness, measured Gemini-accuracy, or production-security claim.

## Extended presentation checklist — individual items not confirmed

- [ ] Confirm official submission format and recording requirements.
- [ ] Verify Git baseline and service readiness without exposing secrets.
- [ ] Confirm separate authorization for any live Gemini request.
- [ ] Run the synthetic learner journey and check ordered path/next-action presentation.
- [ ] Confirm disclosure/consent and loading controls remain clear on screen.
- [ ] Demonstrate the offline report and its simulated-data disclaimer.
- [ ] Time the presentation and review keyboard/mobile legibility if relevant.
- [ ] Prepare a clearly labelled fallback capture if useful/required.
- [ ] Review final recording/screenshots for privacy and accurate claims.
- [ ] Record rehearsal date, result, and outstanding issues in the evidence checklist.
