# Page Dependency Trees — Circles iOS

## Community → Explore Tab (TARGET PAGE)
Entry: `Circles/Community/CommunityView.swift`
Dependencies:
- `Circles/Community/ExploreFloatingView.swift`
  - `Circles/DesignSystem/DesignTokens.swift` (Color.accent, Font.appHeadline, etc.)
- `Circles/DesignSystem/AppBackground.swift`
- `Circles/DesignSystem/Components.swift` (AppCard, PrimaryButton, ChipButton)
- `Circles/DesignSystem/DesignTokens.swift`
- `Circles/Models/Circle.swift`
- `Circles/Circles/CirclesViewModel.swift`

**Files to pass as --context-file for this page:**
- `.superdesign/design-system.md`
- `Circles/Community/CommunityView.swift`
- `Circles/Community/ExploreFloatingView.swift`
- `Circles/DesignSystem/DesignTokens.swift`
- `Circles/DesignSystem/Components.swift`
- `Circles/DesignSystem/AppBackground.swift`
- `Circles/Navigation/MainTabView.swift`

## Home Tab
Entry: `Circles/Home/HomeView.swift`
Dependencies:
- `Circles/Home/HomeViewModel.swift`
- `Circles/Home/HabitDetailView.swift`
- `Circles/DesignSystem/*`
- `Circles/Models/Habit.swift`, `HabitLog.swift`, `Streak.swift`

## Profile Tab
Entry: `Circles/Profile/ProfileView.swift`
Dependencies:
- `Circles/DesignSystem/*`
- `Circles/Auth/AuthManager.swift`
