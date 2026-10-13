const CATEGORIES = ['Programming language', 'SQL', 'Git', 'HTTP/API concepts', 'Automated testing'] as const
type SkillCategory = typeof CATEGORIES[number]
const PATH_PRIORITY: SkillCategory[] = ['Programming language', 'Git', 'SQL', 'HTTP/API concepts', 'Automated testing']

export interface LearningStep {
  category: SkillCategory | 'Integrated practice'
  order: number
  title: string
  instruction: string
  completion_evidence: string
}

export interface LearningPath {
  method: 'curated'
  catalogue_version: '1'
  steps: LearningStep[]
  next_action: LearningStep
}

export interface SkillGapAssessment {
  skillGap: SkillGap
  learningPath: LearningPath
}

export interface SkillGap {
  goal_id: number
  current_skill_id: number
  profile: 'backend_development'
  profile_version: '1'
  method: 'ai_assisted'
  identified_skills: SkillCategory[]
  not_identified_skills: SkillCategory[]
  uncertain_skills: SkillCategory[]
}

type SkillGapResult =
  | ({ kind: 'assessed' } & SkillGapAssessment)
  | { kind: 'error'; message: string; status?: 404 | 422 | 502 | 503 }

type Fetcher = (url: string, options: RequestInit) => Promise<Response>

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isPositiveId(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0
}

function hasExactKeys(value: Record<string, unknown>, keys: string[]): boolean {
  return Object.keys(value).length === keys.length && keys.every((key) => Object.hasOwn(value, key))
}

function isSkillGap(value: unknown, goalId: number): value is SkillGap {
  if (!isObject(value) || !hasExactKeys(value, [
    'goal_id', 'current_skill_id', 'profile', 'profile_version', 'method',
    'identified_skills', 'not_identified_skills', 'uncertain_skills',
  ])) return false
  if (!isPositiveId(value.goal_id) || value.goal_id !== goalId || !isPositiveId(value.current_skill_id)
    || value.profile !== 'backend_development' || value.profile_version !== '1' || value.method !== 'ai_assisted') return false
  const groups = [value.identified_skills, value.not_identified_skills, value.uncertain_skills]
  if (!groups.every((group) => Array.isArray(group))) return false
  const labels: unknown[] = groups.flat()
  return labels.length === CATEGORIES.length && new Set(labels).size === CATEGORIES.length
    && CATEGORIES.every((category) => labels.includes(category))
}

const STEP_KEYS = ['category', 'order', 'title', 'instruction', 'completion_evidence']

function isLearningStep(value: unknown): value is LearningStep {
  return isObject(value) && hasExactKeys(value, STEP_KEYS)
    && (value.category === 'Integrated practice' || CATEGORIES.some((category) => category === value.category))
    && isPositiveId(value.order)
    && ['title', 'instruction', 'completion_evidence'].every((field) => {
      const text = value[field]
      return typeof text === 'string' && text.trim().length > 0 && Array.from(text).length <= 2000
    })
}

function isLearningPath(value: unknown, assessment: SkillGap): value is LearningPath {
  if (!isObject(value) || !hasExactKeys(value, ['method', 'catalogue_version', 'steps', 'next_action'])
    || value.method !== 'curated' || value.catalogue_version !== '1'
    || !Array.isArray(value.steps) || value.steps.length < 1 || value.steps.length > 5
    || !value.steps.every(isLearningStep) || !isLearningStep(value.next_action)) return false

  const selected = PATH_PRIORITY.filter((category) => assessment.not_identified_skills.includes(category)
    || assessment.uncertain_skills.includes(category))
  const expected = selected.length ? selected : ['Integrated practice']
  if (value.steps.length !== expected.length || !value.steps.every((step, index) =>
    step.category === expected[index] && step.order === index + 1)) return false
  const first = value.steps[0]
  const next = value.next_action
  return next.category === first.category && next.order === first.order && next.title === first.title
    && next.instruction === first.instruction && next.completion_evidence === first.completion_evidence
}

export async function assessSkillGap(goalId: number, fetcher: Fetcher = fetch): Promise<SkillGapResult> {
  const unexpected: SkillGapResult = {
    kind: 'error', message: 'We couldn’t confirm your AI assessment. Please try again in a moment.',
  }
  if (!isPositiveId(goalId)) return unexpected
  let response: Response
  try {
    response = await fetcher(`/api/goals/${goalId}/skill_gap`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({}),
    })
  } catch {
    return { kind: 'error', message: 'We couldn’t reach Pathfinder. Check your connection and try again.' }
  }

  // Never display provider details, including when a gateway returns a non-JSON error.
  if (response.status === 502) {
    return { kind: 'error', status: 502, message: 'The AI assessment could not be processed.' }
  }
  if (response.status === 503) {
    return { kind: 'error', status: 503, message: 'The AI service is temporarily unavailable.' }
  }
  let body: unknown
  try {
    body = await response.json()
  } catch {
    return unexpected
  }
  if (!isObject(body)) return unexpected
  if (response.status === 200 && hasExactKeys(body, ['skill_gap', 'learning_path'])
    && isSkillGap(body.skill_gap, goalId) && isLearningPath(body.learning_path, body.skill_gap)) {
    return { kind: 'assessed', skillGap: body.skill_gap, learningPath: body.learning_path }
  }
  if (!hasExactKeys(body, ['errors']) || !isObject(body.errors)) return unexpected

  // Only these approved messages can influence learner-facing feedback.
  const contracts = [
    { status: 404, field: 'goal', error: 'not found',
      message: 'Your goal could not be found. Please save a new goal before requesting an assessment.' },
    { status: 422, field: 'current_skills', error: 'must be saved before identifying skill gaps',
      message: 'Save your current skills before identifying skill gaps.' },
    { status: 422, field: 'goal', error: 'is not supported for skill gap identification',
      message: 'This assessment supports only the goal “Become a backend developer”.' },
  ] as const
  for (const contract of contracts) {
    const messages = body.errors[contract.field]
    if (response.status === contract.status && hasExactKeys(body.errors, [contract.field])
      && Array.isArray(messages) && messages.length === 1 && messages[0] === contract.error) {
      return { kind: 'error', status: contract.status, message: contract.message }
    }
  }
  return unexpected
}
