# Sunny Charkhwal — DevOps Portfolio

A production-grade personal portfolio built with **React 18 + Vite**.

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| React 18 | UI framework |
| Vite 5 | Dev server & bundler |
| CSS Variables | Theming & design tokens |
| IntersectionObserver | Scroll-triggered animations |

---

## Project Structure

```
sunny-portfolio/
├── public/
│   └── favicon.svg
├── src/
│   ├── components/
│   │   ├── Nav.jsx          # Fixed navbar + mobile drawer
│   │   ├── Hero.jsx         # Hero section with stats
│   │   ├── Terminal.jsx     # Animated typewriter terminal
│   │   ├── Skills.jsx       # Tech stack grid
│   │   ├── Projects.jsx     # Wanderlust DevSecOps project
│   │   ├── Experience.jsx   # Work history timeline
│   │   ├── Contact.jsx      # Contact card grid
│   │   ├── Footer.jsx       # Footer
│   │   ├── BackToTop.jsx    # Floating back-to-top button
│   │   └── SectionHeader.jsx
│   ├── data/
│   │   └── index.js         # All portfolio content (edit here)
│   ├── hooks/
│   │   ├── useFadeIn.js     # Scroll-reveal hook
│   │   ├── useActiveSection.js  # Active nav link tracker
│   │   └── useScrolled.js   # Navbar scroll state
│   ├── utils/
│   │   └── scrollTo.js      # Smooth scroll helper
│   ├── App.jsx
│   ├── index.css            # Global styles & CSS variables
│   └── main.jsx
├── index.html
├── vite.config.js
├── package.json
└── .gitignore
```

---

## Getting Started

### Prerequisites
- Node.js **v18+**
- npm **v9+**

### Install & Run

```bash
# 1. Install dependencies
npm install

# 2. Start development server
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

### Build for Production

```bash
npm run build      # outputs to /dist
npm run preview    # preview the production build locally
```

---

## Customisation

All portfolio content lives in **`src/data/index.js`** — edit that single file to update:

- `SKILLS` — tech stack cards
- `PROJECT` — project name, tech stack, bullet points, metrics
- `EXPERIENCE` — job title, company, bullet points
- `CONTACT` — email, LinkedIn, phone, portfolio URL

Global colours and fonts are CSS variables in **`src/index.css`** under `:root`.

---

## Deployment

### Vercel (recommended)
```bash
npm install -g vercel
vercel
```

### Netlify
```bash
npm run build
# drag & drop the /dist folder to netlify.com/drop
```

### GitHub Pages
```bash
# Add to vite.config.js: base: '/your-repo-name/'
npm run build
# push /dist to gh-pages branch
```
