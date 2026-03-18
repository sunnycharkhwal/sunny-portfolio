import { useRef } from 'react'
import { EXPERIENCE } from '../data/index.js'
import SectionHeader from './SectionHeader.jsx'
import useFadeIn from '../hooks/useFadeIn.js'

export default function Experience() {
  const ref = useRef()
  useFadeIn(ref)

  return (
    <section id="experience" ref={ref} className="sc-section">
      <SectionHeader num="03" title="Experience" />

      <div style={{
        background: 'var(--bg2)', border: '1px solid var(--border)',
        borderRadius: 10, padding: '2rem',
        display: 'flex', gap: '2rem', flexWrap: 'wrap',
      }}>
        {/* Timeline dot + line */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 }}>
          <div style={{
            width: 12, height: 12, borderRadius: '50%',
            background: 'var(--accent)', marginTop: 4,
            animation: 'pulse 2.5s ease infinite',
          }} />
          <div style={{ width: 1, flex: 1, background: 'var(--border)', marginTop: 8, minHeight: 80 }} />
        </div>

        {/* Content */}
        <div style={{ flex: 1, minWidth: 240 }}>
          <span style={{ fontFamily: 'var(--mono)', fontSize: 11, color: 'var(--accent)' }}>
            {EXPERIENCE.period}
          </span>
          <div style={{ fontFamily: 'var(--mono)', fontSize: '1rem', fontWeight: 700, color: 'var(--text)', margin: '6px 0 4px' }}>
            {EXPERIENCE.title}
          </div>
          <div style={{ fontSize: 13, color: 'var(--muted)', marginBottom: '1.25rem' }}>
            {EXPERIENCE.company} · {EXPERIENCE.location}
          </div>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '.6rem' }}>
            {EXPERIENCE.points.map((p, i) => (
              <li key={i} style={{ display: 'flex', gap: 10, fontSize: 14, color: 'var(--muted)', lineHeight: 1.7 }}>
                <span style={{ color: 'var(--green)', flexShrink: 0, fontFamily: 'var(--mono)' }}>▸</span>
                {p}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}
