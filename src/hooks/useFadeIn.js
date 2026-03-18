import { useEffect } from 'react'

export default function useFadeIn(ref) {
  useEffect(() => {
    if (!ref.current) return
    const el = ref.current
    el.classList.add('sc-fade')
    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          el.classList.add('sc-visible')
          obs.disconnect()
        }
      },
      { threshold: 0.08 }
    )
    obs.observe(el)
    return () => obs.disconnect()
  }, [])
}
