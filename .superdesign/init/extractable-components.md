# Extractable Components — Circles iOS

## Layout Components

### BottomTabBar
- Source: `Circles/Navigation/MainTabView.swift`
- Category: layout
- Description: 3-tab bottom nav with Home/Community/Profile
- Extractable props: activeTab (string, default: "community")
- Hardcoded: tab labels, SF Symbol names, amber tint color

### NavigationBar
- Source: CommunityView navigationTitle + toolbar (inline in views)
- Category: layout
- Description: Inline nav title + optional trailing toolbar button
- Extractable props: title (string, default: "Community"), showPlusButton (boolean, default: true)
- Hardcoded: title style, amber plus button color

## Basic Components

### AppCard
- Source: `Circles/DesignSystem/Components.swift`
- Category: basic
- Description: Rounded white card with soft shadow (light) or glassmorphism (dark)
- Extractable props: none (purely structural wrapper)
- Hardcoded: border-radius 16px, shadow, glassmorphism style

### PrimaryButton
- Source: `Circles/DesignSystem/Components.swift`
- Category: basic
- Description: Full-width amber CTA button
- Extractable props: label (string, default: "Continue"), isLoading (boolean, default: false)
- Hardcoded: amber background #E8834B, white text, height 52px

### ChipButton
- Source: `Circles/DesignSystem/Components.swift`
- Category: basic
- Description: Pill-shaped chip, filled or outlined
- Extractable props: label (string, default: "Label"), isSelected (boolean, default: false)
- Hardcoded: amber color, pill radius

### FloatingBubble
- Source: `Circles/Community/ExploreFloatingView.swift`
- Category: basic
- Description: Circle-shaped bubble card with icon, name, member count, Join button
- Extractable props: circleName (string, default: "Morning Prayer"), memberCount (string, default: "1.2k members"), isJoined (boolean, default: false), icon (string, default: "moon.stars")
- Hardcoded: bubble size, glass background, amber accent, shadow
