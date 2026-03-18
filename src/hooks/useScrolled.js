import { useState, useEffect } from 'react'

export default function useScrolled(threshold = 40) {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const h = () => setScrolled(window.scrollY > threshold)
    window.addEventListener('scroll', h)
    return () => window.removeEventListener('scroll', h)
  }, [threshold])

  return scrolled
}
