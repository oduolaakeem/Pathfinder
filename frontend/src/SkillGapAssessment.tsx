import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { assessSkillGap } from './api/skillGap'
import type { SkillGap } from './api/skillGap'

export default function SkillGapAssessment({ goalId }: { goalId: number }) {
  const [consent, setConsent] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [recoverable, setRecoverable] = useState(true)
  const [assessment, setAssessment] = useState<SkillGap | null>(null)
  const submitting = useRef(false)
  const requestVersion = useRef(0)

  useEffect(() => () => {
    // A changed goal unmounts this section; ignore any response still in flight.
    requestVersion.current++
  }, [])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!consent || submitting.current || assessment || !recoverable) return
    submitting.current = true
    const version = ++requestVersion.current
    setLoading(true)
    setError('')
    setAssessment(null)
    try {
      const result = await assessSkillGap(goalId)
      if (version !== requestVersion.current) return
      if (result.kind === 'assessed') {
        setAssessment(result.skillGap)
      } else {
        setError(result.message)
        setRecoverable(result.status !== 404 && result.status !== 422)
      }
    } finally {
      if (version === requestVersion.current) {
        submitting.current = false
        setLoading(false)
      }
    }
  }

  return (
    <section className="goal-card assessment-card" aria-labelledby="assessment-heading">
      <p className="eyebrow">Understand your next steps</p>
      <h2 id="assessment-heading">AI skill-gap assessment</h2>
      <div id="assessment-disclosure" className="hint">
        <p>Pathfinder sends your saved career goal and current-skills description to Google’s Gemini AI service for analysis. Do not submit sensitive or confidential information.</p>
        <p>This is a preliminary interpretation of your description, not a verification of skill proficiency or job readiness.</p>
        <p>Currently supported: “Become a backend developer”. Analysis may take approximately 20–30 seconds.</p>
      </div>
      {!assessment && (
        <form onSubmit={handleSubmit} aria-busy={loading}>
          <label className="assessment-consent" htmlFor="assessment-consent">
            <input
              id="assessment-consent"
              type="checkbox"
              checked={consent}
              required
              disabled={loading}
              aria-describedby="assessment-disclosure"
              onChange={(event) => setConsent(event.target.checked)}
            />
            <span>I consent to sending my saved goal and skills description to Google’s Gemini AI service for this assessment.</span>
          </label>
          {error && <p className="error" role="alert">{error}</p>}
          <button type="submit" disabled={!consent || loading || !recoverable}>
            {loading ? 'Assessing…' : error && recoverable ? 'Retry assessment' : 'Assess my skill gaps'}
          </button>
        </form>
      )}
      <p className="saving-status" role="status" aria-atomic="true">
        {loading ? 'Analyzing your saved goal and skills. This may take 20–30 seconds.'
          : assessment ? 'Your AI skill-gap assessment is ready.' : ''}
      </p>
      {assessment && (
        <div className="assessment-results">
          <p className="eyebrow">Backend development · Profile version {assessment.profile_version}</p>
          <p className="hint">“Not identified” does not necessarily mean you lack a skill. Identified mentions do not prove competence. No proficiency score or learning recommendations are provided.</p>
          {[
            { title: 'Skills identified in your description', labels: assessment.identified_skills,
              empty: 'No skill mentions were identified in this group.' },
            { title: 'Skills not identified in your description', labels: assessment.not_identified_skills,
              empty: 'No categories were classified as not identified.' },
            { title: 'Skills requiring clarification', labels: assessment.uncertain_skills,
              empty: 'No categories were classified as requiring clarification.' },
          ].map((group) => (
            <div className="assessment-group" key={group.title}>
              <h3>{group.title}</h3>
              {group.labels.length > 0
                ? <ul>{group.labels.map((label) => <li key={label}>{label}</li>)}</ul>
                : <p className="hint">{group.empty}</p>}
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
