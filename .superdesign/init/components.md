# Shared UI Components — Circles iOS

Note: This is a SwiftUI project. Components are translated to HTML/CSS for SuperDesign mockups.

---

## AppCard
**Source**: `Circles/DesignSystem/Components.swift`
**Description**: Rounded card with automatic light/dark surface treatment.

```html
<!-- AppCard — light mode -->
<div style="
  background: white;
  border-radius: 16px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
  overflow: hidden;
">
  <!-- content -->
</div>

<!-- AppCard — dark mode -->
<div style="
  background: rgba(255,255,255,0.08);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 16px;
">
  <!-- content -->
</div>
```

---

## PrimaryButton
**Source**: `Circles/DesignSystem/Components.swift`
**Description**: Full-width amber CTA, 52pt height, loading state.

```html
<button style="
  width: 100%;
  height: 52px;
  background: #E8834B;
  color: white;
  font-size: 17px;
  font-weight: 600;
  font-family: -apple-system, system-ui;
  border: none;
  border-radius: 14px;
  cursor: pointer;
">Continue</button>
```

---

## ChipButton
**Source**: `Circles/DesignSystem/Components.swift`
**Description**: Pill-shaped chip, filled (selected) or outlined (default).

```html
<!-- Selected chip -->
<button style="
  padding: 8px 14px;
  background: #E8834B;
  color: white;
  font-size: 13px;
  font-weight: 500;
  border: none;
  border-radius: 999px;
  cursor: pointer;
">Salah</button>

<!-- Default chip -->
<button style="
  padding: 8px 14px;
  background: rgba(232,131,75,0.15);
  color: #E8834B;
  font-size: 13px;
  font-weight: 500;
  border: none;
  border-radius: 999px;
  cursor: pointer;
">Quran</button>
```

---

## SectionHeader
**Source**: `Circles/DesignSystem/Components.swift`
**Description**: Section label in New York serif headline.

```html
<div style="text-align: left;">
  <h2 style="
    font-family: Georgia, serif;
    font-size: 22px;
    font-weight: 600;
    color: #1A1209;
    margin: 0 0 2px 0;
  ">Daily Intentions</h2>
  <p style="
    font-size: 13px;
    color: #6B5B45;
    margin: 0;
  ">3 habits today</p>
</div>
```

---

## AppBackground
**Source**: `Circles/DesignSystem/AppBackground.swift`
**Description**: Full-screen animated blob background.

```html
<div style="
  position: fixed; inset: 0;
  background: #F5F0E8;
  overflow: hidden;
  z-index: 0;
">
  <!-- Primary blob — top-left -->
  <div style="
    position: absolute;
    width: 75%; height: 45%;
    background: #EDE0C8;
    border-radius: 50%;
    filter: blur(80px);
    opacity: 0.55;
    top: -15%; left: -20%;
  "></div>
  <!-- Secondary blob — bottom-right -->
  <div style="
    position: absolute;
    width: 55%; height: 30%;
    background: #EDE0C8;
    border-radius: 50%;
    filter: blur(70px);
    opacity: 0.45;
    bottom: -10%; right: -15%;
  "></div>
</div>
```

---

## BottomTabBar
**Source**: `Circles/Navigation/MainTabView.swift`
**Description**: 3-tab bottom navigation. Active tab tinted `#E8834B`.

```html
<div style="
  position: fixed; bottom: 0; left: 0; right: 0;
  height: 83px;
  background: rgba(245,240,232,0.9);
  backdrop-filter: blur(20px);
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding-bottom: 20px;
  border-top: 1px solid rgba(0,0,0,0.06);
">
  <div style="text-align:center; color:#1A1209; opacity:0.5;">
    <div style="font-size:22px;">🏠</div>
    <div style="font-size:11px; font-family:system-ui;">Home</div>
  </div>
  <div style="text-align:center; color:#E8834B;">
    <div style="font-size:22px;">👥</div>
    <div style="font-size:11px; font-family:system-ui; font-weight:500;">Community</div>
  </div>
  <div style="text-align:center; color:#1A1209; opacity:0.5;">
    <div style="font-size:22px;">👤</div>
    <div style="font-size:11px; font-family:system-ui;">Profile</div>
  </div>
</div>
```
