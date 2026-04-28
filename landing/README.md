# Circles Landing Page

Astro marketing site for Circles. This workspace is separate from the iOS app and currently holds the branded single-page landing experience in [`src/pages/index.astro`](./src/pages/index.astro).

## Current Structure

```text
landing/
├── public/                   # Favicons and static assets
├── src/components/           # Section components + mockups
├── src/components/islands/   # Small React/TS motion islands
├── src/layouts/              # Shared page shell
├── src/lib/brand.ts          # Brand constants
├── src/styles/               # Design tokens + globals
└── src/pages/index.astro     # Main landing page
```

## Commands

Run these from `landing/`:

| Command | Action |
| :------ | :----- |
| `npm run dev` | Start the Astro dev server |
| `npm run build` | Build the production landing site |
| `npm run preview` | Preview the built site locally |

## Notes

- Node requirement: `>=22.12.0`
- Typography currently uses `@fontsource/fraunces` and `@fontsource/inter`
- Motion islands live in `src/components/islands/` and should stay small and page-specific
