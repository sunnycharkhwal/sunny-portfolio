export default function SectionHeader({ num, title }) {
  return (
    <div style={{ marginBottom: '3rem' }}>
      <div style={{
        fontFamily: 'var(--mono)', fontSize: 11, letterSpacing: '.15em',
        textTransform: 'uppercase', color: 'var(--accent)', marginBottom: '0.4rem',
      }}>
        {`// ${num}`}
      </div>
      <h2 style={{
        fontFamily: 'var(--mono)', fontWeight: 700, color: 'var(--text)',
        fontSize: 'clamp(1.7rem, 3vw, 2.3rem)',
      }}>
        {title}
      </h2>
    </div>
  )
}
