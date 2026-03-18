import { useRef } from 'react'
import { PROJECT } from '../data/index.js'
import SectionHeader from './SectionHeader.jsx'
import useFadeIn from '../hooks/useFadeIn.js'

export default function Projects() {
  const ref = useRef()
  useFadeIn(ref)

  return (
    <section id="projects" ref={ref} className="sc-section">
      <SectionHeader num="02" title="Projects" />

      <div style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 10, overflow: 'hidden' }}>
        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '1.75rem 2rem', borderBottom: '1px solid var(--border)',
          flexWrap: 'wrap', gap: '1rem',
        }}>
          <span style={{ fontFamily: 'var(--mono)', fontSize: '1rem', fontWeight: 700, color: 'var(--text)' }}>
            {PROJECT.name}
          </span>
          <span style={{
            fontFamily: 'var(--mono)', fontSize: 11, padding: '5px 14px', borderRadius: 20,
            background: 'rgba(16,185,129,.1)', color: 'var(--green)',
            border: '1px solid rgba(16,185,129,.2)',
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <span style={{
              width: 6, height: 6, borderRadius: '50%', background: 'var(--green)',
              display: 'inline-block', animation: 'pulse 2s ease infinite',
            }} />
            {PROJECT.status}
          </span>
        </div>

        <div style={{ padding: '2rem' }}>
          {/* Tech stack pills */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: '1.75rem' }}>
            {PROJECT.stack.map(t => (
              <span key={t} style={{
                fontFamily: 'var(--mono)', fontSize: 11, padding: '5px 12px',
                borderRadius: 4, background: 'var(--bg3)', color: 'var(--muted)',
                border: '1px solid var(--border)',
              }}>
                {t}
              </span>
            ))}
          </div>

          {/* Bullet points */}
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '.85rem', marginBottom: '2rem' }}>
            {PROJECT.points.map(p => (
              <li key={p.label} style={{ display: 'flex', gap: 12, fontSize: 14, color: 'var(--muted)', lineHeight: 1.7 }}>
                <span style={{ color: 'var(--accent)', flexShrink: 0, marginTop: 2, fontFamily: 'var(--mono)' }}>▸</span>
                <span>
                  <span style={{ color: 'var(--text)', fontWeight: 500 }}>{p.label}: </span>
                  {p.desc}
                </span>
              </li>
            ))}
          </ul>

          {/* Metrics */}
          <div className="sc-metrics">
            {PROJECT.metrics.map(m => (
              <div key={m.label} style={{ background: 'var(--bg3)', padding: '1.5rem', textAlign: 'center' }}>
                <span style={{ fontFamily: 'var(--mono)', fontSize: '2rem', fontWeight: 700, color: 'var(--accent)', display: 'block' }}>
                  {m.val}
                </span>
                <span style={{ fontSize: 12, color: 'var(--muted)' }}>{m.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
