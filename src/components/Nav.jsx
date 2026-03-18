import { useState, useEffect } from 'react'
import { NAV_LINKS } from '../data/index.js'
import useScrolled from '../hooks/useScrolled.js'
import scrollTo from '../utils/scrollTo.js'

export default function Nav({ active }) {
  const scrolled = useScrolled()
  const [open, setOpen] = useState(false)

  // lock body scroll when drawer open
  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [open])

  const go = (id) => {
    setOpen(false)
    setTimeout(() => scrollTo(id), open ? 320 : 0)
  }

  const linkStyle = (id) => ({
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    fontFamily: 'var(--mono)',
    fontSize: 11,
    letterSpacing: '.1em',
    textTransform: 'uppercase',
    color: active === id ? 'var(--accent)' : 'var(--muted)',
    borderBottom: `1px solid ${active === id ? 'var(--accent)' : 'transparent'}`,
    paddingBottom: 3,
    transition: 'color .2s, border-color .2s',
  })

  return (
    <>
      <nav style={{
        position: 'fixed', top: 0, left: 0, right: 0, zIndex: 200,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 clamp(1.25rem, 4vw, 4rem)', height: 'var(--nav-h)',
        background: scrolled ? 'rgba(9,13,24,0.95)' : 'transparent',
        backdropFilter: scrolled ? 'blur(16px)' : 'none',
        borderBottom: scrolled ? '1px solid var(--border)' : '1px solid transparent',
        transition: 'all .3s ease',
      }}>
        {/* Logo */}
        <button
          onClick={() => scrollTo('hero')}
          style={{ background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--mono)', fontSize: 14, color: 'var(--accent)', letterSpacing: '.06em' }}
        >
          SC<span style={{ color: 'var(--muted)' }}>://</span>portfolio
        </button>

        {/* Desktop links */}
        <ul className="sc-nav-links">
          {NAV_LINKS.map(l => (
            <li key={l}>
              <button
                style={linkStyle(l.toLowerCase())}
                onClick={() => go(l.toLowerCase())}
                onMouseEnter={e => { e.currentTarget.style.color = 'var(--accent)' }}
                onMouseLeave={e => { e.currentTarget.style.color = active === l.toLowerCase() ? 'var(--accent)' : 'var(--muted)' }}
              >
                {l}
              </button>
            </li>
          ))}
        </ul>

        {/* Hire Me — desktop */}
        <a className="sc-hire" href="mailto:sunny.charkhwal@gmail.com">Hire Me</a>

        {/* Hamburger — mobile */}
        <button
          className={`sc-hamburger${open ? ' open' : ''}`}
          onClick={() => setOpen(o => !o)}
          aria-label="Toggle menu"
        >
          <span /><span /><span />
        </button>
      </nav>

      {/* Mobile drawer */}
      <div className={`sc-drawer${open ? ' open' : ''}`}>
        <button
          onClick={() => setOpen(false)}
          style={{ position: 'absolute', top: 20, right: 24, background: 'none', border: 'none', color: 'var(--muted)', fontSize: 28, cursor: 'pointer' }}
        >
          ✕
        </button>

        {NAV_LINKS.map(l => (
          <button
            key={l}
            onClick={() => go(l.toLowerCase())}
            style={{
              background: 'none', border: 'none', cursor: 'pointer',
              fontFamily: 'var(--mono)', fontSize: '1.4rem', letterSpacing: '.1em', textTransform: 'uppercase',
              color: active === l.toLowerCase() ? 'var(--accent)' : 'var(--muted)',
              borderBottom: `1px solid ${active === l.toLowerCase() ? 'var(--accent)' : 'transparent'}`,
              paddingBottom: 4, transition: 'color .2s',
            }}
          >
            {l}
          </button>
        ))}

        <a
          href="mailto:sunny.charkhwal@gmail.com"
          style={{ marginTop: '1rem', fontFamily: 'var(--mono)', fontSize: 13, padding: '10px 28px', border: '1px solid var(--accent)', borderRadius: 4, color: 'var(--accent)', textDecoration: 'none' }}
        >
          Hire Me
        </a>
      </div>
    </>
  )
}
