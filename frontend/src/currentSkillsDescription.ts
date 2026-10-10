export const CURRENT_SKILLS_DESCRIPTION_LIMIT = 2000

// Match Rails string length using Unicode code points rather than UTF-16 units.
export function countSkillCharacters(description: string): number {
  return Array.from(description).length
}

export function validateCurrentSkillsDescription(description: string): string {
  if (!description.trim()) return 'Enter your current technical skills before saving.'
  if (countSkillCharacters(description) > CURRENT_SKILLS_DESCRIPTION_LIMIT) {
    return `Keep your skills description to ${CURRENT_SKILLS_DESCRIPTION_LIMIT} characters or fewer.`
  }
  return ''
}
