# Gallery App — Frontend

## Project Structure

```
src/
├── assets/
│   └── styles.css          # Global design system (variables, components, utilities)
├── components/
│   ├── AppNavbar.vue         # Top navigation bar
│   ├── CommentThread.vue     # Reusable comment section
│   └── CreateGalleryForm.vue # New gallery creation form
├── views/
│   ├── RegisterView.vue       # Teacher registration
│   ├── LoginView.vue          # Two-step OTP login
│   ├── MetaGalleryView.vue    # Teacher dashboard (list + create galleries)
│   ├── ModerationView.vue     # Teacher moderation (pending / approved panes)
│   ├── StudentGalleryView.vue # Basic student gallery (grid + upload + comments)
│   └── SplitGalleryView.vue   # Split-pane gallery (sidebar list + iframe viewer)
├── App.vue # Root component + page transitions
└── main.ts # App entry, Vue Router setup
```

## Routes

| Path                          | View                  | Who uses it              |
|-------------------------------|-----------------------|--------------------------|
| `/login`                      | LoginView             | Teachers                 |
| `/register`                   | RegisterView          | New teachers             |
| `/galleries/teacher/overview` | MetaGalleryView       | Logged-in teachers       |
| `/moderate/:id`               | ModerationView        | Teacher (moderation)     |
| `/gallery/:id`                | StudentGalleryView    | Students (basic gallery) |
| `/gallery/:id/split`          | SplitGalleryView      | Students (split/iframe)  |

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
