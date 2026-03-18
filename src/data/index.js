export const NAV_LINKS = ['Skills', 'Projects', 'Experience', 'Contact']

export const SKILLS = [
  { icon: '☁',  title: 'Cloud',         tags: ['AWS', 'EKS', 'Secrets Manager', 'CloudWatch', 'IAM'] },
  { icon: '📦', title: 'Containers',    tags: ['Kubernetes', 'Docker', 'Helm'] },
  { icon: '⚙',  title: 'CI / CD',      tags: ['Jenkins', 'ArgoCD', 'GitLab CI', 'GitHub Actions', 'Azure DevOps'] },
  { icon: '🏗',  title: 'IaC',          tags: ['Terraform', 'Ansible'] },
  { icon: '📊', title: 'Observability', tags: ['Prometheus', 'Grafana', 'CloudWatch'] },
  { icon: '🔒', title: 'Security',      tags: ['SonarQube', 'Trivy', 'OWASP', 'IAM Roles'] },
  { icon: '🖥',  title: 'Scripting',    tags: ['Python', 'Bash', 'Shell'] },
  { icon: '⚡', title: 'Frontend',      tags: ['React.js', 'Next.js', 'JavaScript', 'HTML', 'CSS3'] },
]

export const PROJECT = {
  name: 'Wanderlust — End-to-End DevSecOps Pipeline',
  status: 'Production',
  stack: [
    'AWS EKS', 'Jenkins', 'ArgoCD', 'Terraform',
    'Prometheus', 'Grafana', 'SonarQube', 'Trivy', 'Docker', 'Kubernetes',
  ],
  points: [
    {
      label: 'CI/CD Automation',
      desc: 'Multi-stage Jenkins pipeline reducing manual deployment effort by ~60% and accelerating release cycles.',
    },
    {
      label: 'Infrastructure as Code',
      desc: 'EKS clusters via Terraform supporting 5+ microservices with fully version-controlled, reproducible environments.',
    },
    {
      label: 'GitOps Delivery',
      desc: 'ArgoCD syncing Git to the live cluster continuously — zero manual intervention.',
    },
    {
      label: 'DevSecOps',
      desc: 'SonarQube, Trivy, and OWASP dependency checks integrated at every pipeline stage.',
    },
    {
      label: 'Observability Stack',
      desc: 'Prometheus + Grafana dashboards tracking system health, resource utilisation, and alerting thresholds.',
    },
    {
      label: 'Container Strategy',
      desc: 'Optimised multi-stage Docker builds and image lifecycle management within Kubernetes.',
    },
  ],
  metrics: [
    { val: '~60%', label: 'Deployment effort reduced' },
    { val: '5+',   label: 'Microservices orchestrated' },
    { val: '0',    label: 'Manual cluster interventions' },
  ],
}

export const EXPERIENCE = {
  title: 'Lead Front-End Developer',
  company: 'Maxlence Digital (OPC) Pvt. Ltd.',
  location: 'Gurgaon',
  period: 'Apr 2022 – Nov 2024',
  points: [
    'Built and maintained a modular React component library improving reusability across 30+ projects.',
    'Developed high-performance responsive web apps with React.js and Next.js.',
    'Optimised performance via lazy loading, code splitting, and bundle optimisation — reducing load time by ~30%.',
    'Enforced code quality through structured reviews, documentation, and team feedback loops.',
    'Collaborated with UI/UX and product teams to ship user-centric interfaces.',
  ],
}

export const CONTACT = [
  { icon: '✉',  label: 'Email',     val: 'sunny.charkhwal@gmail.com',     href: 'mailto:sunny.charkhwal@gmail.com' },
  { icon: 'in', label: 'LinkedIn',  val: 'linkedin.com/in/sunnycharkhwal', href: 'https://www.linkedin.com/in/sunnycharkhwal' },
  { icon: '☎',  label: 'Phone',     val: '+91 9013030173',                 href: 'tel:+919013030173' },
  { icon: '⬡',  label: 'Portfolio', val: 'sunnycharkhwal.in',              href: 'https://www.sunnycharkhwal.in' },
]

export const TERMINAL_LINES = [
  { type: 'prompt', cmd: 'kubectl get nodes' },
  { type: 'out',    text: 'NAME        STATUS   ROLES    AGE' },
  { type: 'out',    text: 'node-01     ', hi: 'Ready', rest: '    master   14d' },
  { type: 'out',    text: 'node-02     ', hi: 'Ready', rest: '    worker   14d' },
  { type: 'out',    text: 'node-03     ', hi: 'Ready', rest: '    worker   14d' },
  { type: 'blank' },
  { type: 'prompt', cmd: 'terraform apply --auto-approve' },
  { type: 'out',    text: 'Plan: ', hi: '5 to add', rest: ', 0 to change, 0 to destroy' },
  { type: 'out',    text: '',       hi: 'Apply complete!', rest: ' Resources: 5 added.' },
  { type: 'blank' },
  { type: 'prompt', cmd: 'argocd app sync wanderlust' },
  { type: 'out',    text: '', hi: 'SYNCED', rest: '  Healthy  wanderlust' },
  { type: 'blank' },
  { type: 'cursor' },
]
