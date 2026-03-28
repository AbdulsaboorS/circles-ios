# Circles iOS — Design System

## Product Context
Circles is a native iOS app — an Islamic social accountability tool for Muslims. BeReal-style daily check-ins anchored to prayer times, habit tracking, and small private circles.

## Framework
- **Platform**: iOS 17+ native SwiftUI app
- **SuperDesign Output**: HTML/CSS mockups (translated to SwiftUI after approval)
- **No Tailwind / No React** — translate design tokens to inline CSS equivalents

---

## Color Tokens

### Light Mode (PRIMARY — use this by default)
```css
--bg:           #F5F0E8;  /* warm cream background */
--blob:         #EDE0C8;  /* warm beige blob shapes */
--card:         #FFFFFF;  /* white card surface */
--card-shadow:  rgba(0,0,0,0.06);
--text-primary: #1A1209;  /* near-black warm */
--text-secondary: #6B5B45; /* warm brown-grey */
--accent:       #E8834B;  /* amber — same in both modes */
--accent-light: rgba(232,131,75,0.12); /* amber tint for backgrounds */
--accent-light2: rgba(232,131,75,0.20);
--border:       rgba(232,131,75,0.15);
```

### Dark Mode (secondary)
```css
--bg:           #0E0B08;  /* warm near-black */
--blob:         #1A3A2A;  /* forest green blob */
--card:         rgba(255,255,255,0.08); /* ultra-thin material glass */
--text-primary: #FFFFFF;
--text-secondary: rgba(255,255,255,0.6);
--accent:       #E8834B;
```

---

## Typography

### Serif Headers (New York / Georgia equivalent for web)
```css
--font-hero:    34px / regular / serif (Georgia, 'Times New Roman', serif)
--font-title:   28px / regular / serif
--font-headline: 22px / 600 / serif
```

### SF Pro / System UI (for body)
```css
--font-body:       17px / 400 / -apple-system, system-ui
--font-subhead:    15px / 500 / -apple-system, system-ui
--font-caption:    13px / 400 / -apple-system, system-ui
--font-caption-md: 13px / 500 / -apple-system, system-ui
```

---

## Spacing & Shape
```css
--radius-card:   16px
--radius-button: 14px
--radius-chip:   999px  /* full pill */
--radius-bubble: 50%    /* full circle */
--shadow-card:   0 2px 8px rgba(0,0,0,0.06)
--shadow-bubble: 0 6px 16px rgba(232,131,75,0.12)
```

---

## Core Components

### AppBackground
- Full-screen background
- Light: `#F5F0E8` base + two `#EDE0C8` ellipse blobs (gaussian blur 60-80px, opacity 0.4-0.6)
- Primary blob: top-left, 75% width, slowly breathing animation
- Secondary blob: bottom-right, 55% width, offset timing
- Blobs are subtle — they should NOT overpower content

### AppCard
- `border-radius: 16px`
- Light: `background: white; box-shadow: 0 2px 8px rgba(0,0,0,0.06)`
- Dark: `backdrop-filter: blur(20px); background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.1)`

### PrimaryButton
- Full width, `height: 52px`, `border-radius: 14px`
- `background: #E8834B`, `color: white`, `font: 17px/600`

### ChipButton
- Pill shape, `padding: 8px 14px`
- Selected: `background: #E8834B`, white text
- Default: `background: rgba(232,131,75,0.15)`, amber text

---

## Mobile Frame Spec
- Design for **iPhone** portrait: `390px wide × 844px tall` (iPhone 14/15 size)
- Safe area top: ~59px (status bar + nav), bottom: ~34px (home indicator)
- Tab bar: ~83px from bottom
- Available content area: ~702px height (minus nav + tab bar)

---

## Islamic Design Language
- Warm, spiritual, calm — NOT sterile tech
- Amber/gold accent connotes warmth and Islamic art
- Serif fonts for headers connote depth and tradition
- Organic blob shapes = organic/natural feel
- SF Symbols used: `moon.stars.fill`, `book.fill`, `hands.sparkles.fill`, `heart.fill`, `star.fill`, `person.2.fill`, `sparkles`

---

## Navigation Structure
3-tab bottom navigation:
1. **Home** (house.fill) — habit check-ins
2. **Community** (person.2.fill) — My Circles + Explore tab
3. **Profile** (person.circle.fill) — stats + habits + settings
