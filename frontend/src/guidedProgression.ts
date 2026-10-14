type Destination = Pick<HTMLElement, 'focus' | 'scrollIntoView'>

export function navigateToHeading(heading: Destination | null, reducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) {
  if (!heading) return
  let reduce: boolean
  try { reduce = Boolean(reducedMotion()) } catch { reduce = true }
  try { heading.focus?.({ preventScroll: true }) } catch { /* Unsupported focus options. */ }
  try { heading.scrollIntoView?.({ block: 'start', behavior: reduce ? 'auto' : 'smooth' }) } catch { /* Scrolling is an enhancement. */ }
}

export function beginProgression(form: HTMLFormElement) {
  let active = true
  let movedAway = false
  const doc = form.ownerDocument
  const onFocus = (event: Event) => {
    if (!form.contains(event.target as Node)) movedAway = true
  }
  doc.addEventListener('focusin', onFocus)
  doc.addEventListener('pointerdown', onFocus)
  const cancel = () => {
    active = false
    doc.removeEventListener('focusin', onFocus)
    doc.removeEventListener('pointerdown', onFocus)
  }
  return {
    cancel,
    finish(heading: Destination | null) {
      const shouldNavigate = active && !movedAway
      cancel()
      if (shouldNavigate) navigateToHeading(heading)
    },
  }
}
