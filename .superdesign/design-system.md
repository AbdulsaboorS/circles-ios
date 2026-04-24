# Circles iOS — Design System

## Product Context
Circles is a native iOS app — an Islamic social accountability tool for Muslims. BeReal-style daily check-ins anchored to prayer times, habit tracking, and small private circles.

## Framework
- **Platform**: iOS 17+ native SwiftUI app
- **SuperDesign Output**: HTML/CSS mockups (translated to SwiftUI after approval)
- **No Tailwind / No React** — translate design tokens to inline CSS equivalents
- **Theme**: Always Dark (Premium Islamic Aesthetic)

---

## Color Tokens

### Deep Green & Luminous Gold (Always Dark)
```css
--bg-deep:        #0A120D;  /* Deep forest green / near black */
--bg-spotlight:   #122217;  /* Lighter forest green for radial gradients */
--card-glass:     rgba(255, 255, 255, 0.05); /* Ultra-thin material base */
--text-primary:   #FFFFFF;  /* Pure white */
--text-secondary: rgba(255, 255, 255, 0.6); /* Muted white/gray */
--text-gold-muted: rgba(212, 175, 55, 0.6); /* Muted gold for inactive/secondary elements */
--accent-gold:    #D4AF37;  /* Luminous Gold */
--accent-glow:    rgba(212, 175, 55, 0.3); /* Gold glow for shadows */
--border-highlight: rgba(212, 175, 55, 0.2); /* Edge highlight for glass cards */
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
--glow-subtle:   0 0 8px rgba(212, 175, 55, 0.15)
--glow-strong:   0 0 16px rgba(212, 175, 55, 0.3)
--border-glass:  0.5px solid rgba(212, 175, 55, 0.2)
```

---

## Core Components

### AppBackground
- Full-screen background
- Base: `#0A120D` (Deep Forest Green)
- Lighting: Subtle radial gradients using `#122217` (Lighter Forest) to create a "spotlight" effect behind key content areas, replacing flat background colors.
- Animation: Subtle breathing animations on the radial gradients.

### AppCard
- `border-radius: 16px`
- Material: `.ultraThinMaterial` equivalent (`background: rgba(255, 255, 255, 0.05); backdrop-filter: blur(20px)`)
- Border: `0.5px solid rgba(212, 175, 55, 0.2)` (Edge Highlight)
- Shadow: Subtle gold glow instead of black drop shadow.

### PrimaryButton
- Full width, `height: 52px`, `border-radius: 14px`
- `background: #D4AF37`, `color: #0A120D` (Dark text on gold for contrast), `font: 17px/600`
- Glow: `box-shadow: 0 0 16px rgba(212, 175, 55, 0.3)`

### ChipButton
- Pill shape, `padding: 8px 14px`
- Selected: `background: #D4AF37`, dark text, with gold glow.
- Default: `background: rgba(212, 175, 55, 0.1)`, `color: #D4AF37`, thin gold border.

---

## Mobile Frame Spec
- Design for **iPhone** portrait: `390px wide × 844px tall` (iPhone 14/15 size)
- Safe area top: ~59px (status bar + nav), bottom: ~34px (home indicator)
- Tab bar: ~83px from bottom
- Available content area: ~702px height (minus nav + tab bar)

---

## Islamic Design Language
- Premium, spiritual, nighttime aesthetic — reminiscent of Ramadan nights and Taraweeh.
- Deep forest greens and luminous gold accents connote warmth, luxury, and Islamic art.
- Serif fonts for headers connote depth and tradition.
- Lighting: "Inner light" glowing effects rather than flat shadows.
- SF Symbols used: `moon.stars.fill`, `book.fill`, `hands.sparkles.fill`, `heart.fill`, `star.fill`, `person.2.fill`, `sparkles`. Rendered hierarchically or with palettes for a two-tone gold look.

---

## Navigation Structure
3-tab bottom navigation:
1. **Home** (house.fill) — habit check-ins
2. **Community** (person.2.fill) — My Circles + Explore tab
3. **Profile** (person.circle.fill) — stats + habits + settings
