# Routes / Screens — Circles iOS

## Navigation Structure
Root: `ContentView.swift` → routes to auth or main app

```
ContentView
├── AuthView (not authenticated)
└── MainTabView (authenticated)
    ├── Tab 0: HomeView
    │   └── → HabitDetailView (drill-down per habit)
    ├── Tab 1: CommunityView  ← CURRENT FOCUS
    │   ├── Segment 0: My Circles
    │   │   ├── AppCard list of user's circles
    │   │   └── → CircleDetailView (drill-down)
    │   │       └── FeedView (embedded)
    │   └── Segment 1: Explore  ← TARGET PAGE
    │       └── ExploreFloatingView (floating bubble canvas)
    └── Tab 2: ProfileView
```

## Key Source Files
- `Circles/ContentView.swift` — root auth routing
- `Circles/Navigation/MainTabView.swift` — 3-tab shell
- `Circles/Community/CommunityView.swift` — Community screen
- `Circles/Community/ExploreFloatingView.swift` — Explore floating bubbles
- `Circles/Circles/CircleDetailView.swift` — Circle detail + feed
