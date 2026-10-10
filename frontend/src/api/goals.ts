import { countGoalCharacters, GOAL_DESCRIPTION_LIMIT } from '../goalDescription'

export interface Goal {
  id: number
  description: string
}

type GoalResult =
  | { kind: 'saved'; goal: Goal }
  | { kind: 'validation'; messages: string[] }
  | { kind: 'error'; message: string }

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

export async function createGoal(description: string): Promise<GoalResult> {
  let response: Response
  try {
    response = await fetch('/api/goals', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ goal: { description } }),
    })
  } catch {
    return { kind: 'error', message: 'We couldn’t reach Pathfinder. Check your connection and try again.' }
  }

  if (response.status === 400) {
    return { kind: 'error', message: 'We couldn’t process your goal. Please refresh the page and try again.' }
  }

  const unexpected: GoalResult = {
    kind: 'error',
    message: 'We couldn’t confirm that your goal was saved. Please try again in a moment.',
  }
  let body: unknown
  try {
    body = await response.json()
  } catch {
    return unexpected
  }
  if (!isObject(body)) return unexpected

  if (response.status === 201 && isObject(body.goal)) {
    const { id, description: savedDescription } = body.goal
    if (typeof id === 'number' && Number.isSafeInteger(id) && id > 0
      && typeof savedDescription === 'string' && savedDescription.trim()
      && countGoalCharacters(savedDescription) <= GOAL_DESCRIPTION_LIMIT) {
      return { kind: 'saved', goal: { id, description: savedDescription } }
    }
  }

  if (response.status === 422 && isObject(body.errors)) {
    const messages = body.errors.description
    if (Array.isArray(messages) && messages.length > 0
      && messages.every((message): message is string => typeof message === 'string' && Boolean(message.trim()))) {
      return { kind: 'validation', messages }
    }
  }
  return unexpected
}
