export const GOAL_DESCRIPTION_LIMIT = 500

// Match Rails string length: Unicode code points, rather than UTF-16 code units.
export function countGoalCharacters(description: string): number {
  return Array.from(description).length
}

export function validateGoalDescription(description: string): string {
  if (!description.trim()) return 'Enter a career goal before saving.'
  if (countGoalCharacters(description) > GOAL_DESCRIPTION_LIMIT) {
    return `Keep your goal to ${GOAL_DESCRIPTION_LIMIT} characters or fewer.`
  }
  return ''
}
