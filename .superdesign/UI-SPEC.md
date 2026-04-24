# Circles iOS — Visual Specification (Deep Green & Luminous Gold)

## Aesthetic Vision
The visual language of Circles is shifting to a premium, spiritual, nighttime aesthetic. It evokes the feeling of Ramadan nights, Taraweeh, and quiet reflection. The core elements are deep forest greens, luminous gold accents, and "inner light" glowing effects rather than flat shadows.

## Color Palette (SwiftUI Hex Equivalents)

### Backgrounds
*   **Deep Forest Green (Base)**: `#0A120D`
*   **Lighter Forest (Spotlights)**: `#122217`
*   **Card Surface (Glass)**: `rgba(255, 255, 255, 0.05)`

### Accents & Text
*   **Luminous Gold (Primary Accent)**: `#D4AF37`
*   **Text Primary**: `#FFFFFF` (Pure White)
*   **Text Secondary**: `rgba(255, 255, 255, 0.6)` (Muted White)
*   **Text Tertiary / Inactive**: `rgba(212, 175, 55, 0.5)` (Muted Gold)

## Materials & Borders (Glassmorphism)

To achieve the premium glass look without heavy backgrounds:
*   **Surfaces**: Use `.ultraThinMaterial` (or `rgba(255, 255, 255, 0.05)` with `backdrop-filter: blur(20px)` in CSS) with a subtle dark green tint.
*   **Edge Highlights**: Apply a 0.5pt border using `rgba(212, 175, 55, 0.2)` (Low-opacity gold) to define shapes and catch the light.

## Glow Effects (Inner Light)

Instead of standard black drop shadows, use the gold accent to create a glowing effect:
*   **Subtle Glow**: `color: rgba(212, 175, 55, 0.15), radius: 8, x: 0, y: 0`
*   **Strong Glow**: `color: rgba(212, 175, 55, 0.30), radius: 16, x: 0, y: 0`

## Iconography & Rings

*   **SF Symbols**: Use `.symbolRenderingMode(.hierarchical)` or `.palette`. 
    *   Primary layer: Luminous Gold (`#D4AF37`)
    *   Secondary layer: Translucent Gold (`rgba(212, 175, 55, 0.4)`)
*   **Progress Rings**: 
    *   Track: `rgba(212, 175, 55, 0.15)`
    *   Progress: `#D4AF37` with a Subtle Glow applied to the stroke.

## Background Gradients

Replace flat background colors with radial gradients to create a "spotlight" effect behind key content areas:
*   **Center**: `#122217` (Lighter Forest)
*   **Edge**: `#0A120D` (Deep Forest)
*   **Animation**: Apply subtle breathing animations (opacity/scale changes) to the radial gradients to make the app feel alive.
