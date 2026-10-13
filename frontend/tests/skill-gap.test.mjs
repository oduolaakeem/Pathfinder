import assert from 'node:assert/strict'
import test from 'node:test'
import { assessSkillGap } from '../src/api/skillGap.ts'

const assessment = {
  goal_id: 3, current_skill_id: 7, profile: 'backend_development', profile_version: '1', method: 'ai_assisted',
  identified_skills: ['Programming language', 'SQL', 'Git'],
  not_identified_skills: ['Automated testing'], uncertain_skills: ['HTTP/API concepts'],
}
const reply = (status, body) => async () => new Response(JSON.stringify(body), { status })
const unexpected = 'We couldn’t confirm your AI assessment. Please try again in a moment.'

const priority = ['Programming language', 'Git', 'SQL', 'HTTP/API concepts', 'Automated testing']
const stepFor = (category, order) => ({ category, order, title: `Practice ${category}`,
  instruction: 'Complete a synthetic practice exercise.', completion_evidence: 'Source files and observed results.' })
function pathFor(skillGap) {
  const categories = priority.filter((category) =>
    (Array.isArray(skillGap.not_identified_skills) && skillGap.not_identified_skills.includes(category))
    || (Array.isArray(skillGap.uncertain_skills) && skillGap.uncertain_skills.includes(category)))
  const steps = (categories.length ? categories : ['Integrated practice']).map((category, i) => stepFor(category, i + 1))
  return { method: 'curated', catalogue_version: '1', steps, next_action: { ...steps[0] } }
}
const combined = (skillGap) => ({ skill_gap: skillGap, learning_path: pathFor(skillGap) })

test('accepts the all-identified integrated fallback', async () => {
  const skillGap = { ...assessment, identified_skills: priority, not_identified_skills: [], uncertain_skills: [] }
  assert.deepEqual(await assessSkillGap(3, reply(200, combined(skillGap))), {
    kind: 'assessed', skillGap, learningPath: pathFor(skillGap),
  })
})

test('rejects missing path and unexpected response or path fields', async () => {
  const valid = combined(assessment)
  for (const body of [{ skill_gap: assessment }, { ...valid, extra: true },
    { ...valid, learning_path: null }, { ...valid, learning_path: [] },
    { ...valid, learning_path: { ...valid.learning_path, extra: true } }]) {
    assert.equal((await assessSkillGap(3, reply(200, body))).message, unexpected)
  }
  for (const field of Object.keys(valid.learning_path)) {
    const path = { ...valid.learning_path }; delete path[field]
    assert.equal((await assessSkillGap(3, reply(200, { ...valid, learning_path: path }))).message, unexpected)
  }
})

test('rejects wrong path method/version and malformed steps', async () => {
  for (const change of [{ method: 'ai_written' }, { catalogue_version: 1 }, { catalogue_version: '2' },
    { steps: [] }, { steps: null }, { steps: {} }]) {
    assert.equal((await assessSkillGap(3, reply(200, { ...combined(assessment),
      learning_path: { ...pathFor(assessment), ...change } }))).message, unexpected)
  }
})

test('requires exact step keys, bounded nonblank strings and matching next action', async () => {
  const mutations = [{ extra: true }, { order: '1' }, { order: 0 }, { order: 1.5 }]
  for (const field of ['title', 'instruction', 'completion_evidence']) {
    for (const value of ['', ' \t\n', null, 42, 'x'.repeat(2001)]) mutations.push({ [field]: value })
  }
  for (const change of mutations) {
    const path = pathFor(assessment); path.steps[0] = { ...path.steps[0], ...change }; path.next_action = { ...path.steps[0] }
    assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).message, unexpected)
  }
  for (const field of Object.keys(stepFor('SQL', 1))) {
    const path = pathFor(assessment); delete path.steps[0][field]; path.next_action = { ...path.steps[0] }
    assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).message, unexpected)
  }
  for (const next of [null, {}, { ...pathFor(assessment).steps[0], title: 'Different' },
    { ...pathFor(assessment).steps[0], extra: true }, pathFor(assessment).steps[1]]) {
    const path = { ...pathFor(assessment), next_action: next }
    assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).message, unexpected)
  }
})

test('rejects contradictory coverage, duplicate categories and wrong ordering', async () => {
  for (const labels of [['Automated testing', 'HTTP/API concepts'], ['HTTP/API concepts'],
    ['HTTP/API concepts', 'HTTP/API concepts'], ['Git', 'Automated testing'], ['Integrated practice'],
    ['HTTP/API concepts', 'Automated testing', 'SQL']]) {
    const steps = labels.map((category, i) => stepFor(category, i + 1))
    const path = { ...pathFor(assessment), steps, next_action: steps[0] }
    assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).message, unexpected)
  }
  const path = pathFor(assessment); path.steps[1].order = 3
  assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).message, unexpected)
})

test('rejects invalid all-identified fallbacks', async () => {
  const skillGap = { ...assessment, identified_skills: priority, not_identified_skills: [], uncertain_skills: [] }
  for (const labels of [[], ['SQL'], ['Integrated practice', 'Integrated practice']]) {
    const steps = labels.map((category, i) => stepFor(category, i + 1))
    const path = { ...pathFor(skillGap), steps, next_action: steps[0] }
    assert.equal((await assessSkillGap(3, reply(200, { skill_gap: skillGap, learning_path: path }))).message, unexpected)
  }
})

test('posts only an empty JSON object to the saved goal URL and returns the assessment', async () => {
  let calls = 0
  const fetcher = async (url, options) => {
    calls++
    assert.equal(url, '/api/goals/3/skill_gap')
    assert.deepEqual(options, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: '{}',
    })
    return new Response(JSON.stringify(combined(assessment)), { status: 200 })
  }
  assert.deepEqual(await assessSkillGap(3, fetcher), { kind: 'assessed', skillGap: assessment, learningPath: pathFor(assessment) })
  assert.equal(calls, 1)
})

test('accepts empty groups and preserves server ordering within each group', async () => {
  const skillGap = { ...assessment, identified_skills: [], not_identified_skills: [],
    uncertain_skills: ['Programming language', 'SQL', 'Git', 'HTTP/API concepts', 'Automated testing'] }
  assert.deepEqual(await assessSkillGap(3, reply(200, combined(skillGap))), { kind: 'assessed', skillGap, learningPath: pathFor(skillGap) })
})

for (const field of ['goal_id', 'current_skill_id']) {
  test(`rejects invalid ${field} identifiers`, async () => {
    for (const value of [0, -1, 1.5, '3', null, Number.MAX_SAFE_INTEGER + 1]) {
      assert.equal((await assessSkillGap(3, reply(200, combined({ ...assessment, [field]: value })))).message, unexpected)
    }
  })
}

test('rejects a response for another goal and invalid goal IDs before fetching', async () => {
  assert.equal((await assessSkillGap(3, reply(200, combined({ ...assessment, goal_id: 4 })))).message, unexpected)
  for (const value of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    let calls = 0
    assert.equal((await assessSkillGap(value, async () => { calls++; throw new Error('must not fetch') })).kind, 'error')
    assert.equal(calls, 0)
  }
})

for (const [field, value] of [['profile', 'frontend_development'], ['profile_version', 1], ['method', 'deterministic']]) {
  test(`rejects invalid ${field}`, async () => {
    assert.equal((await assessSkillGap(3, reply(200, combined({ ...assessment, [field]: value })))).message, unexpected)
  })
}

test('rejects missing, duplicate and unexpected categories and wrong group types', async () => {
  for (const change of [
    { identified_skills: ['SQL', 'Git'] },
    { identified_skills: ['Programming language', 'SQL', 'SQL'] },
    { uncertain_skills: ['HTTP/API concepts', 'Git'] },
    { uncertain_skills: ['Networking'] },
    { uncertain_skills: [42] },
    { uncertain_skills: 'HTTP/API concepts' },
    { uncertain_skills: null },
    { uncertain_skills: {} },
  ]) {
    assert.equal((await assessSkillGap(3, reply(200, combined({ ...assessment, ...change })))).message, unexpected)
  }
})

test('rejects malformed success shapes, missing fields and extra provider data', async () => {
  for (const body of [null, [], {}, { skill_gap: [] }, { skill_gap: null },
    { ...combined(assessment), skill_gap: { ...assessment, provider_response: 'SYNTHETIC_PRIVATE' } },
    { ...combined(assessment), provider_response: 'SYNTHETIC_PRIVATE' }]) {
    assert.equal((await assessSkillGap(3, reply(200, body))).message, unexpected)
  }
  for (const field of Object.keys(assessment)) {
    const incomplete = { ...assessment }
    delete incomplete[field]
    assert.equal((await assessSkillGap(3, reply(200, combined(incomplete)))).message, unexpected)
  }
})

test('accepts 2000 Unicode code points per text field and rejects 2001', async () => {
  for (const field of ['title', 'instruction', 'completion_evidence']) {
    for (const text of ['😀'.repeat(2000), 'a'.repeat(1000) + '😀'.repeat(1000)]) {
      const path = pathFor(assessment)
      path.steps[0][field] = text
      path.next_action = { ...path.steps[0] }
      assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).kind, 'assessed')
      path.steps[0][field] += '😀'
      path.next_action = { ...path.steps[0] }
      assert.equal((await assessSkillGap(3, reply(200, { skill_gap: assessment, learning_path: path }))).message, unexpected)
    }
  }
})

for (const [status, field, serverMessage, message] of [
  [404, 'goal', 'not found', 'Your goal could not be found. Please save a new goal before requesting an assessment.'],
  [422, 'current_skills', 'must be saved before identifying skill gaps', 'Save your current skills before identifying skill gaps.'],
  [422, 'goal', 'is not supported for skill gap identification', 'This assessment supports only the goal “Become a backend developer”.'],
]) {
  test(`handles approved ${status} ${field} errors safely`, async () => {
    assert.deepEqual(await assessSkillGap(3, reply(status, { errors: { [field]: [serverMessage] } })), {
      kind: 'error', status, message,
    })
  })
}

for (const [status, message] of [
  [502, 'The AI assessment could not be processed.'],
  [503, 'The AI service is temporarily unavailable.'],
]) {
  test(`returns a safe ${status} message regardless of provider error body`, async () => {
    for (const body of [{ errors: { skill_gap: ['SYNTHETIC_PRIVATE'] } }, null, {}]) {
      assert.deepEqual(await assessSkillGap(3, reply(status, body)), { kind: 'error', status, message })
    }
    assert.deepEqual(await assessSkillGap(3, async () => new Response('SYNTHETIC_PRIVATE', { status })), {
      kind: 'error', status, message,
    })
  })
}

test('does not expose network exception details', async () => {
  const result = await assessSkillGap(3, async () => { throw new Error('SYNTHETIC_PRIVATE') })
  assert.equal(result.kind, 'error')
  assert.match(result.message, /connection/i)
  assert.ok(!result.message.includes('SYNTHETIC_PRIVATE'))
})

test('rejects malformed error bodies without displaying server content', async () => {
  for (const status of [404, 422]) {
    for (const body of [null, {}, { errors: [] }, { errors: { goal: ['SYNTHETIC_PRIVATE'] } },
      { errors: { goal: ['not found', 'SYNTHETIC_PRIVATE'] } }]) {
      assert.equal((await assessSkillGap(3, reply(status, body))).message, unexpected)
    }
  }
})

test('handles malformed JSON, non-JSON and unexpected statuses', async () => {
  for (const status of [200, 404, 422]) {
    assert.equal((await assessSkillGap(3, async () => new Response('<html>not JSON</html>', { status }))).message, unexpected)
  }
  for (const status of [201, 400, 500]) {
    assert.equal((await assessSkillGap(3, reply(status, { skill_gap: assessment }))).message, unexpected)
  }
})
