# Theme — Circles iOS Design Tokens

## Source File: `Circles/DesignSystem/DesignTokens.swift`

```swift
// LIGHT MODE (primary)
darkBackground   = #0E0B08  // near-black warm (dark bg)
lightBackground  = #F5F0E8  // warm cream (light bg) — PRIMARY
darkBlob         = #1A3A2A  // forest green (dark blob)
lightBlob        = #EDE0C8  // warm beige (light blob)
accent           = #E8834B  // amber — same both modes
lightTextPrimary = #1A1209  // near-black warm
lightTextSecondary = #6B5B45 // warm brown-grey
lightCardSurface = #FFFFFF

// Typography (serif = New York / Georgia)
appHeroTitle  = 34px serif regular
appTitle      = 28px serif regular
appHeadline   = 22px serif semibold
appBody       = 17px system regular
appSubheadline = 15px system medium
appCaption    = 13px system regular
appCaptionMedium = 13px system medium
```

## CSS Equivalents for SuperDesign
```css
:root {
  /* Light mode — use by default */
  --bg: #F5F0E8;
  --blob: #EDE0C8;
  --card: #FFFFFF;
  --text-primary: #1A1209;
  --text-secondary: #6B5B45;
  --accent: #E8834B;
  --accent-tint: rgba(232, 131, 75, 0.12);
  --accent-tint2: rgba(232, 131, 75, 0.20);
  --shadow: rgba(0,0,0,0.06);
  --accent-shadow: rgba(232, 131, 75, 0.15);

  /* Typography */
  --font-serif: Georgia, 'Times New Roman', serif;
  --font-sans: -apple-system, BlinkMacSystemFont, 'SF Pro Display', system-ui, sans-serif;

  /* Shape */
  --radius-lg: 16px;
  --radius-md: 14px;
  --radius-pill: 999px;
}
```
