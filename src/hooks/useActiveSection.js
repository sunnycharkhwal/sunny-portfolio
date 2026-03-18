import { useState, useEffect } from 'react'
import { NAV_LINKS } from '../data/index.js'

export default function useActiveSection() {
  const [active, setActive] = useState('')

  useEffect(() => {
    const els = NAV_LINKS
      .map(l => document.getElementById(l.toLowerCase()))
      .filter(Boolean)

    const obs = new IntersectionObserver(
      entries => {
        entries.forEach(e => {
          if (e.isIntersecting) setActive(e.target.id)
        })
      },
      { threshold: 0.3, rootMargin: '-60px 0px -40% 0px' }
    )

    els.forEach(s => obs.observe(s))
    return () => obs.disconnect()
  }, [])

  return active
}
