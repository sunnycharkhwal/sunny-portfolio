import { useState, useEffect, useRef } from 'react'
import { TERMINAL_LINES } from '../data/index.js'

export default function Terminal() {
  const [lines, setLines] = useState([])
  const [tick, setTick] = useState(true)
  const idx = useRef(0)

  useEffect(() => {
    const next = () => {
      if (idx.current >= TERMINAL_LINES.length) return
      const l = TERMINAL_LINES[idx.current++]
      setLines(prev => [...prev, l])
      const delay = l.type === 'blank' ? 80 : l.type === 'prompt' ? 280 : 140
      setTimeout(next, delay)
    }

    const t = setTimeout(next, 500)
    const b = setInterval(() => setTick(v => !v), 530)
    return () => { clearTimeout(t); clearInterval(b) }
  }, [])

  return (
    <div className="sc-terminal">
      {/* Title bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '10px 14px', background: 'var(--bg2)', borderBottom: '1px solid var(--border)' }}>
        {['#ff5f56', '#ffbd2e', '#27c93f'].map(c => (
          <span key={c} style={{ width: 10, height: 10, borderRadius: '50%', background: c, display: 'inline-block' }} />
        ))}
        <span style={{ flex: 1, textAlign: 'center', fontFamily: 'var(--mono)', fontSize: 11, color: 'var(--muted)' }}>
          sunny@devops ~ zsh
        </span>
      </div>

      {/* Body */}
      <div style={{ padding: '1.25rem 1.4rem', minHeight: 260, fontFamily: 'var(--mono)', fontSize: 12, lineHeight: 1.9 }}>
        {lines.map((l, i) => {
          if (l.type === 'blank') return <div key={i} style={{ height: 8 }} />

          if (l.type === 'cursor') return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <span style={{ color: 'var(--green)' }}>sunny@aws</span>
              <span style={{ color: 'var(--muted)' }}>:~$</span>
              <span style={{
                display: 'inline-block', width: 8, height: 14,
                background: tick ? 'var(--accent)' : 'transparent',
                marginLeft: 6, verticalAlign: 'middle', transition: 'background .1s',
              }} />
            </div>
          )

          if (l.type === 'prompt') return (
            <div key={i} style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
              <span style={{ color: 'var(--green)' }}>sunny@aws</span>
              <span style={{ color: 'var(--muted)' }}>:~$</span>
              <span style={{ color: 'var(--text)', marginLeft: 6 }}>{l.cmd}</span>
            </div>
          )

          return (
            <div key={i} style={{ color: 'var(--muted)' }}>
              {l.text}
              {l.hi   && <span style={{ color: 'var(--accent)' }}>{l.hi}</span>}
              {l.rest && <span>{l.rest}</span>}
            </div>
          )
        })}
      </div>
    </div>
  )
}
