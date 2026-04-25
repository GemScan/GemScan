import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/app/**/*.{ts,tsx}',
    './src/components/**/*.{ts,tsx}',
  ],
  darkMode: 'media',
  theme: {
    extend: {
      colors: {
        gemscan: {
          safe: 'var(--color-safe)',
          suspicious: 'var(--color-suspicious)',
          scam: 'var(--color-scam)',
          primary: 'var(--color-primary)',
          surface: 'var(--color-surface)',
          'on-surface': 'var(--color-on-surface)',
        },
      },
    },
  },
  plugins: [],
}

export default config
