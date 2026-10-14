import assert from 'node:assert/strict'
import test from 'node:test'
import { navigateToHeading, beginProgression } from '../src/guidedProgression.ts'

test('focuses without scrolling then scrolls smoothly to the heading', () => {
  const calls = []
  navigateToHeading({ focus: (o) => calls.push(['focus', o]), scrollIntoView: (o) => calls.push(['scroll', o]) }, () => false)
  assert.deepEqual(calls, [['focus', { preventScroll: true }], ['scroll', { block: 'start', behavior: 'smooth' }]])
})
test('reduced motion uses auto scrolling', () => {
  let options
  navigateToHeading({ focus() {}, scrollIntoView(o) { options = o } }, () => true)
  assert.equal(options.behavior, 'auto')
})
test('missing or unsupported browser features do not throw', () => {
  assert.doesNotThrow(() => navigateToHeading(null))
  assert.doesNotThrow(() => navigateToHeading({}))
  assert.doesNotThrow(() => navigateToHeading({ focus() { throw Error() }, scrollIntoView() { throw Error() } }, () => { throw Error() }))
})
function fixture() {
  const listeners = new Map()
  const doc = { addEventListener: (n, f) => listeners.set(n, f), removeEventListener: (n) => listeners.delete(n) }
  const inside = {}
  const form = { ownerDocument: doc, contains: (node) => node === inside }
  let focuses = 0
  const heading = { focus: () => focuses++, scrollIntoView() {} }
  return { form, heading, listeners, inside, focuses: () => focuses }
}
test('successful progression finishes once and removes its listener', () => {
  const f = fixture(), pending = beginProgression(f.form)
  pending.finish(f.heading)
  pending.finish(f.heading)
  assert.equal(f.focuses(), 1)
  assert.equal(f.listeners.size, 0)
})
test('focus within submitting form permits progression', () => {
  const f = fixture(), pending = beginProgression(f.form)
  f.listeners.get('focusin')({ target: f.inside })
  pending.finish(f.heading)
  assert.equal(f.focuses(), 1)
})
test('focus outside submitting form prevents stealing focus', () => {
  const f = fixture(), pending = beginProgression(f.form)
  f.listeners.get('focusin')({ target: {} })
  pending.finish(f.heading)
  assert.equal(f.focuses(), 0)
})
test('cancellation on failure or unmount prevents navigation', () => {
  const f = fixture(), pending = beginProgression(f.form)
  pending.cancel()
  pending.finish(f.heading)
  assert.equal(f.focuses(), 0)
  assert.equal(f.listeners.size, 0)
})
test('pointer interaction outside the form prevents navigation', () => {
  const f = fixture(), pending = beginProgression(f.form)
  f.listeners.get('pointerdown')({ target: {} })
  pending.finish(f.heading)
  assert.equal(f.focuses(), 0)
})
