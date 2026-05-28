# Gallery App — Frontend

## Project Structure

```
src/
├── assets/         # Global design system (variables, components, utilities)
├── components/     # Reusable `.vue` components
├── core/           # Reusable `.ts` modules
├── views/          # Standalone `.vue` components
├── App.vue         # Root component + page transitions
└── main.ts         # App entry, Vue Router setup
```

## How to build

Dev:

```bash
npm install
npm run dev      # Vite dev server on http://localhost:5173
```

Prod preview:

```bash
npm run preview  # Outputs static files to dist/ and launches at http://localhost:4173
```

## Design System

All colours, spacing, and typography are driven by CSS custom properties in
`src/assets/styles.css`. Key variables:

- `--clr-primary`  → golden amber (#c49a0a)
- `--clr-accent`   → sky blue (#3d7ea6)
- `--clr-bg`       → warm white (#fdfaf3)
- `--font-display` → Lora (serif, for headings)
- `--font-body`    → DM Sans (for UI text)

Fonts are loaded from Google Fonts.
