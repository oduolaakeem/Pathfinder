import { validateCurrentSkillsDescription } from '../currentSkillsDescription.ts'

export interface CurrentSkills {
  id: number
  goal_id: number
  description: string
}

type CurrentSkillsResult =
  | { kind: 'saved'; currentSkills: CurrentSkills }
  | { kind: 'validation'; messages: string[] }
  | { kind: 'error'; message: string; status?: 400 | 404 | 409 }

type Fetcher = (url: string, options: RequestInit) => Promise<Response>

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isPositiveId(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0
}

export async function createCurrentSkills(
  goalId: number,
  description: string,
  fetcher: Fetcher = fetch,
): Promise<CurrentSkillsResult> {
  let response: Response
  try {
    response = await fetcher(`/api/goals/${goalId}/current_skills`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ current_skills: { description } }),
    })
  } catch {
    return { kind: 'error', message: 'We couldn’t reach Pathfinder. Check your connection and try again.' }
  }

  const unexpected: CurrentSkillsResult = {
    kind: 'error', message: 'We couldn’t confirm that your skills were saved. Please try again in a moment.',
  }
  let body: unknown
  try {
    body = await response.json()
  } catch {
    return unexpected
  }
  if (!isObject(body)) return unexpected

  if (response.status === 201 && isObject(body.current_skills)) {
    const { id, goal_id: savedGoalId, description: savedDescription } = body.current_skills
    if (isPositiveId(id) && isPositiveId(savedGoalId) && savedGoalId === goalId
      && typeof savedDescription === 'string' && !validateCurrentSkillsDescription(savedDescription)) {
      return { kind: 'saved', currentSkills: { id, goal_id: savedGoalId, description: savedDescription } }
    }
  }

  if (!isObject(body.errors)) return unexpected
  if (response.status === 422) {
    const messages = body.errors.description
    if (Array.isArray(messages) && messages.length > 0
      && messages.every((message): message is string => typeof message === 'string' && Boolean(message.trim()))) {
      return { kind: 'validation', messages }
    }
    return unexpected
  }

  const status = response.status
  if (status === 400 || status === 404 || status === 409) {
    const field = status === 404 ? 'goal' : 'current_skills'
    const expected = status === 400 ? 'is required' : status === 404 ? 'not found' : 'already submitted for this goal'
    const messages = body.errors[field]
    if (!Array.isArray(messages) || messages.length !== 1 || messages[0] !== expected) return unexpected
    const message = status === 400
      ? 'We couldn’t process your skills. Please refresh the page and try again.'
      : status === 404
        ? 'Your goal could not be found. Please save a goal before adding your skills.'
        : 'Skills have already been saved for this goal.'
    return { kind: 'error', status, message }
  }
  return unexpected
}
