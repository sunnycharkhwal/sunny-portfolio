/**
 * Smooth-scrolls to a section by id,
 * offsetting for the fixed navbar height.
 */
export default function scrollTo(id) {
  const el = document.getElementById(id)
  if (!el) return
  const top = el.getBoundingClientRect().top + window.scrollY - 64
  window.scrollTo({ top, behavior: 'smooth' })
}
