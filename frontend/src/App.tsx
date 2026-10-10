import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { createGoal } from './api/goals'
import type { Goal } from './api/goals'
import { countGoalCharacters, GOAL_DESCRIPTION_LIMIT, validateGoalDescription } from './goalDescription'
import './App.css'

function App() {
  const [description, setDescription] = useState('')
  const [saving, setSaving] = useState(false)
  const [fieldError, setFieldError] = useState('')
  const [requestError, setRequestError] = useState('')
  const [savedGoal, setSavedGoal] = useState<Goal | null>(null)
  const submitting = useRef(false)
  const field = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    if (fieldError && !saving) field.current?.focus()
  }, [fieldError, saving])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (submitting.current) return
    setFieldError('')
    setRequestError('')

    const validationError = validateGoalDescription(description)
    if (validationError) {
      setFieldError(validationError)
      return
    }

    submitting.current = true
    setSaving(true)
    try {
      const result = await createGoal(description)
      if (result.kind === 'saved') {
        setSavedGoal(result.goal)
      } else if (result.kind === 'validation') {
        setFieldError(result.messages.map((message) => `Career goal ${message}`).join('. '))
      } else {
        setRequestError(result.message)
      }
    } finally {
      submitting.current = false
      setSaving(false)
    }
  }

  return (
    <main className="page">
      <header className="intro">
        <p className="brand">Pathfinder <span aria-hidden="true">↗</span></p>
        <p className="eyebrow">Start with your destination</p>
        <h1>Where do you want<br />to go next?</h1>
        <p className="summary">Pathfinder helps you connect what you learn with where you want to be. Start by defining your software-development career goal.</p>
      </header>

      <section className="goal-card" aria-labelledby="form-heading">
        <p className="eyebrow">Your first step</p>
        <h2 id="form-heading">Define your career goal</h2>
        <form onSubmit={handleSubmit} noValidate aria-busy={saving}>
          <label htmlFor="description">Software-development career goal</label>
          <p id="goal-help" className="hint">Describe the role or kind of work you want to pursue.</p>
          <textarea
            ref={field}
            id="description"
            name="description"
            rows={4}
            required
            value={description}
            disabled={saving}
            placeholder="For example: Become a backend developer"
            aria-invalid={Boolean(fieldError)}
            aria-describedby={`goal-help goal-count${fieldError ? ' goal-error' : ''}`}
            onChange={(event) => {
              setDescription(event.target.value)
              setFieldError('')
              setRequestError('')
            }}
          />
          <p id="goal-count" className="character-count">{countGoalCharacters(description)} / {GOAL_DESCRIPTION_LIMIT} characters</p>
          {fieldError && <p id="goal-error" className="error" role="alert">{fieldError}</p>}
          {requestError && <p className="error" role="alert">{requestError}</p>}
          <button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Save my goal'}<span aria-hidden="true"> ↗</span></button>
          <p className="saving-status" role="status">{saving ? 'Saving your career goal…' : ''}</p>
        </form>
      </section>

      <div aria-live="polite" aria-atomic="true">
        {savedGoal && (
          <section className="saved-card" aria-labelledby="saved-heading">
            <p className="eyebrow">Goal saved</p>
            <h2 id="saved-heading">Your destination is set.</h2>
            <p className="saved-description">{savedGoal.description}</p>
            <p className="hint">Saved goal #{savedGoal.id}</p>
          </section>
        )}
      </div>
    </main>
  )
}

export default App
