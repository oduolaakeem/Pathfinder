import assert from 'node:assert/strict'
import test from 'node:test'
import { countSkillCharacters, validateCurrentSkillsDescription } from '../src/currentSkillsDescription.ts'
import { createCurrentSkills } from '../src/api/currentSkills.ts'

const saved = { id: 7, goal_id: 3, description: 'Synthetic persisted Ruby skills' }
const reply = (status, body) => async () => new Response(JSON.stringify(body), { status })

test('skills validation rejects blank text', () => {
  for (const value of ['', ' \t\n ']) {
    assert.equal(validateCurrentSkillsDescription(value), 'Enter your current technical skills before saving.')
  }
})

for (const [label, value] of [
  ['supplementary', '\u{1F680}'.repeat(2000)],
  ['mixed', 'a'.repeat(1000) + '\u{1F680}'.repeat(1000)],
]) {
  test(`skills validation accepts 2000 ${label} code points and rejects 2001`, () => {
    assert.equal(countSkillCharacters(value), 2000)
    assert.equal(validateCurrentSkillsDescription(value), '')
    assert.equal(countSkillCharacters(value + '\u{1F680}'), 2001)
    assert.equal(validateCurrentSkillsDescription(value + '\u{1F680}'), 'Keep your skills description to 2000 characters or fewer.')
  })
}

test('sends the exact nested URL, headers and JSON, and returns persisted values', async () => {
  let calls = 0
  const fetcher = async (url, options) => {
    calls++
    assert.equal(url, '/api/goals/3/current_skills')
    assert.deepEqual(options, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ current_skills: { description: 'Synthetic submitted skills' } }),
    })
    return new Response(JSON.stringify({ current_skills: saved }), { status: 201 })
  }
  assert.deepEqual(await createCurrentSkills(3, 'Synthetic submitted skills', fetcher), { kind: 'saved', currentSkills: saved })
  assert.equal(calls, 1)
})

test('accepts a persisted 2000 supplementary-code-point description', async () => {
  const currentSkills = { ...saved, description: '\u{1F680}'.repeat(2000) }
  assert.deepEqual(await createCurrentSkills(3, 'Synthetic skills', reply(201, { current_skills: currentSkills })), {
    kind: 'saved', currentSkills,
  })
})

test('returns field-specific 422 validation messages', async () => {
  const messages = ["can't be blank"]
  assert.deepEqual(await createCurrentSkills(3, '', reply(422, { errors: { description: messages } })), {
    kind: 'validation', messages,
  })
})

for (const [status, field, message] of [
  [400, 'current_skills', 'is required'],
  [404, 'goal', 'not found'],
  [409, 'current_skills', 'already submitted for this goal'],
]) {
  test(`handles the approved ${status} error without exposing response details`, async () => {
    const result = await createCurrentSkills(3, 'Synthetic skills', reply(status, { errors: { [field]: [message] } }))
    assert.equal(result.kind, 'error')
    assert.equal(result.status, status)
    assert.ok(result.message.length > 0)
  })
}

test('handles a network failure', async () => {
  const result = await createCurrentSkills(3, 'Synthetic skills', async () => { throw new Error('Synthetic private detail') })
  assert.equal(result.kind, 'error')
  assert.match(result.message, /connection/i)
  assert.ok(!result.message.includes('Synthetic private detail'))
})

test('rejects malformed success responses', async () => {
  for (const body of [
    null, [], {}, { current_skills: [] },
    { current_skills: { ...saved, id: '7' } },
    { current_skills: { ...saved, id: 0 } },
    { current_skills: { ...saved, id: 1.5 } },
    { current_skills: { ...saved, id: Number.MAX_SAFE_INTEGER + 1 } },
    { current_skills: { ...saved, goal_id: '3' } },
    { current_skills: { ...saved, goal_id: 4 } },
    { current_skills: { ...saved, description: null } },
    { current_skills: { ...saved, description: ['Ruby'] } },
    { current_skills: { ...saved, description: ' \t ' } },
    { current_skills: { ...saved, description: '\u{1F680}'.repeat(2001) } },
  ]) {
    assert.equal((await createCurrentSkills(3, 'Synthetic skills', reply(201, body))).kind, 'error')
  }
})

test('handles invalid JSON and unexpected HTTP statuses', async () => {
  assert.equal((await createCurrentSkills(3, 'Synthetic skills', async () => new Response('not JSON', { status: 201 }))).kind, 'error')
  assert.equal((await createCurrentSkills(3, 'Synthetic skills', reply(500, { current_skills: saved }))).kind, 'error')
  assert.equal((await createCurrentSkills(3, 'Synthetic skills', reply(200, { current_skills: saved }))).kind, 'error')
})

test('rejects malformed 422 messages and malformed error bodies', async () => {
  for (const messages of [null, [], [''], [42], "can't be blank"]) {
    assert.equal((await createCurrentSkills(3, 'Synthetic skills', reply(422, { errors: { description: messages } }))).kind, 'error')
  }
  for (const status of [400, 404, 409]) {
    const result = await createCurrentSkills(3, 'Synthetic skills', reply(status, { exception: 'Synthetic private detail' }))
    assert.equal(result.kind, 'error')
    assert.equal(result.status, undefined)
    assert.ok(!result.message.includes('Synthetic private detail'))
  }
})
