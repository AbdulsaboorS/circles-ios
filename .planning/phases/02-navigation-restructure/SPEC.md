# Phase 2 — Navigation Restructure + Home Cleanup

**Goal:** Establish the correct product feel from the moment the app opens. App entry → Circles tab. Home → quiet Daily Intentions only.

---

## Changes

### 1. App Entry Point → Circles Tab
**File:** `Circles/Navigation/MainTabView.swift`
- Change `@State private var selectedTab = 0` → `@State private var selectedTab = 1`
- Tab order stays the same (Home=0, Community=1, Profile=2) — just the default changes
- Update tab labels: "Community" → "Circles"
- Update tab icon: keep `person.2.fill`

### 2. Home Tab → Daily Intentions Only
**File:** `Circles/Home/HomeView.swift`
- Remove: any remaining social feed references
- Update navigation title from implicit to explicit: "Daily Intentions"
- Update `SectionHeader` for habits section to "Daily Intentions" (Muslim-native copy)
- Remove `communitySection` (already removed in pivot — confirm gone)
- Keep: greeting header, streak card, habit list, HabitDetailView navigation

### 3. Tab Labels + Copy
**File:** `Circles/Navigation/MainTabView.swift`
- Tab 0: "Home" → label stays but purpose is now "Daily Intentions"
- Tab 1: "Community" → rename to "Circles"
- Tab 2: "Profile" → stays

### 4. CommunityView Title
**File:** `Circles/Community/CommunityView.swift`
- `.navigationTitle("Community")` → `.navigationTitle("Circles")`

---

## Success Criteria
- App launches directly to Circles tab (Global Feed)
- Home tab shows only habit check-ins, no feed
- "Circles" label on tab 1
- Build succeeds, no regressions
