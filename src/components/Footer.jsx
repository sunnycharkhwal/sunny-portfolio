export default function Footer() {
  return (
    <footer style={{
      position: 'relative', zIndex: 1, textAlign: 'center',
      padding: '2rem 1.5rem', borderTop: '1px solid var(--border)',
      fontFamily: 'var(--mono)', fontSize: 12, color: 'var(--muted)',
    }}>
      <span style={{ color: 'var(--green)' }}>sunny@devops</span>
      <span>:~$ </span>
      <span style={{ color: 'var(--amber)' }}>echo </span>
      <span>&quot;Built with passion · New Delhi, India · 2025&quot;</span>
    </footer>
  )
}
