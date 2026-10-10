import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { createCurrentSkills } from './api/currentSkills'
import type { CurrentSkills } from './api/currentSkills'
import {
  countSkillCharacters,
  CURRENT_SKILLS_DESCRIPTION_LIMIT,
  validateCurrentSkillsDescription,
} from './currentSkillsDescription'

export default function CurrentSkillsForm({ goalId }: { goalId: number }) {
  const [description, setDescription] = useState('')
  const [saving, setSaving] = useState(false)
  const [fieldError, setFieldError] = useState('')
  const [requestError, setRequestError] = useState('')
  const [savedSkills, setSavedSkills] = useState<CurrentSkills | null>(null)
  const [alreadySubmitted, setAlreadySubmitted] = useState(false)
  const submitting = useRef(false)
  const field = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    if (fieldError && !saving) field.current?.focus()
  }, [fieldError, saving])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (submitting.current || savedSkills || alreadySubmitted) return
    setFieldError('')
    setRequestError('')
    const validationError = validateCurrentSkillsDescription(description)
    if (validationError) {
      setFieldError(validationError)
      return
    }

    submitting.current = true
    setSaving(true)
    try {
      const result = await createCurrentSkills(goalId, description)
      if (result.kind === 'saved') {
        setSavedSkills(result.currentSkills)
      } else if (result.kind === 'validation') {
        setFieldError(result.messages.map((message) => `Skills description ${message}`).join('. '))
      } else {
        setRequestError(result.message)
        if (result.status === 409) setAlreadySubmitted(true)
      }
    } finally {
      submitting.current = false
      setSaving(false)
    }
  }

  return (
    <section className="goal-card skills-card" aria-labelledby="skills-heading">
      <p className="eyebrow">Your next step</p>
      <h2 id="skills-heading">Your current technical skills</h2>
      {!savedSkills && (
        <form onSubmit={handleSubmit} noValidate aria-busy={saving}>
          <label htmlFor="skills-description">Current technical skills</label>
          <p id="skills-help" className="hint">Describe the tools you know and what you have built. For example: Ruby, SQL, Git; built a small Rails application.</p>
          <textarea
            ref={field}
            id="skills-description"
            name="description"
            rows={4}
            required
            value={description}
            disabled={saving || alreadySubmitted}
            aria-invalid={Boolean(fieldError)}
            aria-describedby={`skills-help skills-count${fieldError ? ' skills-error' : ''}`}
            onChange={(event) => {
              setDescription(event.target.value)
              setFieldError('')
              setRequestError('')
            }}
          />
          <p id="skills-count" className="character-count">{countSkillCharacters(description)} / {CURRENT_SKILLS_DESCRIPTION_LIMIT} characters</p>
          {fieldError && <p id="skills-error" className="error" role="alert">{fieldError}</p>}
          {requestError && <p className="error" role="alert">{requestError}</p>}
          <button type="submit" disabled={saving || alreadySubmitted}>{saving ? 'Saving…' : 'Save my skills'}<span aria-hidden="true"> ↗</span></button>
          <p className="saving-status" role="status">{saving ? 'Saving your current skills…' : ''}</p>
        </form>
      )}
      <div aria-live="polite" aria-atomic="true">
        {savedSkills && (
          <div className="skills-confirmation">
            <p className="eyebrow">Skills saved</p>
            <p className="saved-description">{savedSkills.description}</p>
            <p className="hint">Your current skills have been saved for this goal.</p>
          </div>
        )}
      </div>
    </section>
  )
}
