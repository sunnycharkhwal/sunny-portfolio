import useActiveSection from './hooks/useActiveSection.js'
import Nav        from './components/Nav.jsx'
import Hero       from './components/Hero.jsx'
import Skills     from './components/Skills.jsx'
import Projects   from './components/Projects.jsx'
import Experience from './components/Experience.jsx'
import Contact    from './components/Contact.jsx'
import Footer     from './components/Footer.jsx'
import BackToTop  from './components/BackToTop.jsx'

export default function App() {
  const active = useActiveSection()

  return (
    <>
      <Nav active={active} />
      <Hero />
      <Skills />
      <Projects />
      <Experience />
      <Contact />
      <Footer />
      <BackToTop />
    </>
  )
}
