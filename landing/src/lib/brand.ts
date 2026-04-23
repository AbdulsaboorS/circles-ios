/**
 * Brand constants.
 *
 * Phase 16 (Naming/Branding) is not yet complete — the product name
 * may change. Every public-facing reference to the name should go
 * through this file so the rename is a single-line change.
 */
export const BRAND = {
  name: 'Circles',
  tagline: 'Your circle. Your moment. Nothing public.',
  email: 'hello@circles.app', // placeholder
  appStoreUrl: '#',           // placeholder until Phase 19
} as const;

export type Brand = typeof BRAND;
