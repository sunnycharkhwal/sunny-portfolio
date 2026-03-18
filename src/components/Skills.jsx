import { useRef } from 'react'
import { SKILLS } from '../data/index.js'
import SectionHeader from './SectionHeader.jsx'
import useFadeIn from '../hooks/useFadeIn.js'

export default function Skills() {
  const ref = useRef()
  useFadeIn(ref)

  return (
    <section id="skills" ref={ref} className="sc-section">
      <SectionHeader num="01" title="Tech Stack" />
      <div className="sc-skills-grid">
        {SKILLS.map(s => (
          <div key={s.title} className="sc-skill-card">
            <div style={{ fontSize: '1.4rem', marginBottom: '.75rem' }}>{s.icon}</div>
            <h3 style={{
              fontFamily: 'var(--mono)', fontSize: 12, color: 'var(--accent)',
              textTransform: 'uppercase', letterSpacing: '.07em', marginBottom: '.75rem',
            }}>
              {s.title}
            </h3>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {s.tags.map(t => (
                <span key={t} style={{
                  fontFamily: 'var(--mono)', fontSize: 11, padding: '3px 10px', borderRadius: 3,
                  background: 'rgba(0,229,255,0.06)', color: 'var(--accent)',
                  border: '1px solid rgba(0,229,255,0.14)',
                }}>
                  {t}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
