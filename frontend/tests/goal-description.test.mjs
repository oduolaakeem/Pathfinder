import assert from 'node:assert/strict'
import test from 'node:test'
import { countGoalCharacters, validateGoalDescription } from '../src/goalDescription.ts'

test('accepts 500 supplementary Unicode code points', () => {
  const description = '\u{1F680}'.repeat(500)
  assert.equal(countGoalCharacters(description), 500)
  assert.equal(validateGoalDescription(description), '')
})

test('rejects 501 supplementary Unicode code points', () => {
  const description = '\u{1F680}'.repeat(501)
  assert.equal(countGoalCharacters(description), 501)
  assert.equal(validateGoalDescription(description), 'Keep your goal to 500 characters or fewer.')
})

test('counts mixed ASCII and supplementary characters at both boundaries', () => {
  const description = 'a'.repeat(250) + '\u{1F680}'.repeat(250)
  assert.equal(countGoalCharacters(description), 500)
  assert.equal(validateGoalDescription(description), '')
  assert.equal(countGoalCharacters(description + 'b'), 501)
  assert.equal(validateGoalDescription(description + 'b'), 'Keep your goal to 500 characters or fewer.')
})

test('continues to reject empty and whitespace-only descriptions', () => {
  for (const description of ['', ' \t\n ']) {
    assert.equal(validateGoalDescription(description), 'Enter a career goal before saving.')
  }
})
