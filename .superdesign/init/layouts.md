# Layout Components — Circles iOS

## MainTabView
**Source**: `Circles/Navigation/MainTabView.swift`
**Description**: Root 3-tab navigation shell.

```swift
TabView(selection: $selectedTab) {
    HomeView()        .tabItem { Label("Home",      systemImage: "house.fill") }      .tag(0)
    CommunityView()   .tabItem { Label("Community", systemImage: "person.2.fill") }   .tag(1)
    ProfileView()     .tabItem { Label("Profile",   systemImage: "person.circle.fill") }.tag(2)
}
.tint(Color.accent)  // #E8834B
```

## Screen Layout Pattern
Every full screen uses this ZStack pattern:
```swift
ZStack {
    AppBackground()      // blob bg fills entire screen
    VStack(spacing: 0) {
        // navigation bar area (NavigationStack adds ~44pt nav bar)
        // content
    }
}
.navigationTitle("Title")
.navigationBarTitleDisplayMode(.inline)
```

## CommunityView Layout
**Source**: `Circles/Community/CommunityView.swift`

```swift
NavigationStack {
    ZStack {
        AppBackground()
        VStack(spacing: 0) {
            // Segmented picker: "My Circles" | "Explore"
            Picker("", selection: $selectedTab) { ... }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            // Content based on selected tab
            if selectedTab == 0 { myCirclesContent }
            else { exploreContent }
        }
    }
    .navigationTitle("Community")
    .toolbar { /* + button top-right */ }
}
```
