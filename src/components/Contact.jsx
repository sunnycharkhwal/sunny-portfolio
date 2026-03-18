import { useRef } from 'react'
import { CONTACT } from '../data/index.js'
import SectionHeader from './SectionHeader.jsx'
import useFadeIn from '../hooks/useFadeIn.js'

export default function Contact() {
  const ref = useRef()
  useFadeIn(ref)

  return (
    <section id="contact" ref={ref} className="sc-section">
      <SectionHeader num="04" title="Get In Touch" />

      <div className="sc-contact-grid">
        {CONTACT.map(c => (
          <a
            key={c.label}
            className="sc-contact-card"
            href={c.href}
            target={c.href.startsWith('http') ? '_blank' : undefined}
            rel="noopener noreferrer"
          >
            <div style={{
              width: 42, height: 42, borderRadius: 8, flexShrink: 0,
              background: 'rgba(0,229,255,.07)', border: '1px solid rgba(0,229,255,.12)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: 'var(--mono)', fontSize: 14, color: 'var(--accent)',
            }}>
              {c.icon}
            </div>
            <div>
              <div style={{ fontSize: 12, color: 'var(--muted)' }}>{c.label}</div>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 13, color: 'var(--text)', marginTop: 2 }}>
                {c.val}
              </div>
            </div>
          </a>
        ))}
      </div>
    </section>
  )
}
