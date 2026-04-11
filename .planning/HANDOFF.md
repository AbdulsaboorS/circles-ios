# Handoff — 2026-04-10 (Session 10 — Wave 3/4 fixes done; Community redesign planned)

## Current Build State
**BUILD SUCCEEDED — zero errors.**

---

## What Was Done This Session

- All 10 dual-camera steps shipped (Stage I complete)
- GroupedCheckinCard: real timestamp + comment button wired
- OwnMomentFullView: PiP swap + CommentDrawerView added
- MomentFeedCard: `#Preview` with mock secondaryPhotoUrl for Xcode canvas testing

---

## Next Task — Community Feed Redesign (4 directives)

Work through these in order. Build must succeed after each one before moving to the next.

---

### Directive 1 — Performance: Concurrent URL Resolution

**File:** `Circles/Services/FeedService.swift`

Replace the serial `for` loop in `resolveMomentPhotoURLsConcurrent` with a real `withTaskGroup`:

```swift
private func resolveMomentPhotoURLsConcurrent(
    for rows: [CircleMomentRow]
) async throws -> [UUID: (primary: String, secondary: String?)] {
    try await withThrowingTaskGroup(
        of: (UUID, String, String?).self
    ) { group in
        for row in rows {
            group.addTask {
                let primary = try await MomentService.shared.resolveMomentPhotoURL(from: row.photoUrl)
                let secondary: String? = if let sec = row.secondaryPhotoUrl {
                    try? await MomentService.shared.resolveMomentPhotoURL(from: sec)
                } else {
                    nil
                }
                return (row.id, primary, secondary)
            }
        }
        var result = [UUID: (primary: String, secondary: String?)]()
        for try await (id, primary, secondary) in group {
            result[id] = (primary: primary, secondary: secondary)
        }
        return result
    }
}
```

**Note:** `MomentService` is `@MainActor`. Swift 6 will reject calling it from inside a detached `TaskGroup` child task unless you hop. To work around without restructuring MomentService, keep the `@MainActor` annotation on `resolveMomentPhotoURLsConcurrent` and use `async let` pairs instead of `withThrowingTaskGroup` if Swift 6 strict concurrency rejects it. Fall back to this pattern (pairs of `async let`, batched):

```swift
// Fallback if TaskGroup hits Swift 6 actor-isolation rejection:
// Fire all primary resolves concurrently via async let array
// (Swift 6-safe: still on MainActor, async let forks within same actor)
var primaries: [UUID: String] = [:]
var secondaries: [UUID: String?] = [:]
await withTaskGroup(of: Void.self) { group in
    // Not viable across actor boundary — use serial fallback if needed
}
// If Swift 6 rejects the TaskGroup approach entirely, leave serial and note it.
// Do NOT break the build trying to force concurrency.
```

**Priority:** Try `withThrowingTaskGroup` first. If Swift 6 rejects it, leave the serial loop and add `// TODO: parallelize when MomentService is nonisolated`. Do not break the build.

---

### Directive 2 — Header: Minimalist Text-Only Switcher

**File:** `Circles/Community/CommunityView.swift`

Replace `stickyHeader` entirely. Keep the same `selectedPage` / `activeFilter` state — only the visual changes.

**Design spec:**
- Tier 1: "Feed" and "Circles" — same labels, no change
- Tier 2: "Posts" and "Check-ins" — same labels, no change
- Active indicator: underline only (2pt rectangle, `Color.msGold`), no capsule/fill/background
- Font: `.system(size: 15, weight: .semibold, design: .serif)` for active, `.system(size: 15, weight: .regular, design: .serif)` for inactive
- Tier 2 font: `.system(size: 12, weight: .semibold, design: .serif)` active, `.system(size: 12, weight: .regular, design: .serif)` inactive
- Foreground: `Color.msTextPrimary` active, `Color.msTextMuted` inactive
- No background material on tier 1 or tier 2 rows
- Thin `Color.msBorder.opacity(0.4)` separator line at bottom of the header block
- Tier 2 row sits 0pt below tier 1 (no extra spacing — they form one compact block)
- Overall header height: tier 1 = 44pt, tier 2 = 34pt (same as before, just visually lighter)

```swift
private var stickyHeader: some View {
    VStack(spacing: 0) {
        // Tier 1: Feed | Circles
        HStack(spacing: 0) {
            tier1Tab(title: "Feed", index: 0)
            tier1Tab(title: "Circles", index: 1)
        }

        // Tier 2: Posts | Check-ins (Feed tab only)
        if selectedPage == 0 {
            HStack(spacing: 0) {
                tier2Tab(title: "Posts", filter: .posts)
                tier2Tab(title: "Check-ins", filter: .checkins)
            }
            .padding(.horizontal, 20)
        }

        Rectangle()
            .fill(Color.msBorder.opacity(0.4))
            .frame(height: 0.5)
    }
}

private func tier1Tab(title: String, index: Int) -> some View {
    let isActive = selectedPage == index
    return Button {
        withAnimation(.easeInOut(duration: 0.22)) { selectedPage = index }
    } label: {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular, design: .serif))
                .foregroundStyle(isActive ? Color.msTextPrimary : Color.msTextMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            Rectangle()
                .fill(isActive ? Color.msGold : Color.clear)
                .frame(height: 2)
        }
    }
    .buttonStyle(.plain)
}

private func tier2Tab(title: String, filter: FeedFilter) -> some View {
    let isActive = activeFilter == filter
    return Button {
        withAnimation(.easeInOut(duration: 0.22)) { activeFilter = filter }
    } label: {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .serif))
                .foregroundStyle(isActive ? Color.msTextPrimary : Color.msTextMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
            Rectangle()
                .fill(isActive ? Color.msGold : Color.clear)
                .frame(height: 2)
        }
    }
    .buttonStyle(.plain)
}
```

---

### Directive 3 — Pinned "Me" Card Redesign

**File:** `Circles/Community/CommunityView.swift` — `ownMomentCard` function

Replace the current 120pt fixed-height strip with a full portrait 2:3 card that shows both camera images.

**Design spec:**
- `aspectRatio(2.0 / 3.0, contentMode: .fit)` — full width minus 16pt margins
- `cornerRadius(24)`
- Primary photo: fills the card (`.scaledToFill()`, `.clipped()`)
- Secondary PiP inset: `80×107pt`, `cornerRadius(12)`, white stroke 2pt, `padding(10)` from bottom-left — same as `MomentFeedCard`. Only show if `moment.secondaryPhotoUrl != nil`.
- "Shared with X Circles" pill: top-right corner, `padding(10)`. Style: gold fill (`Color(hex: "D4A240")`), dark text (`Color(hex: "1A2E1E")`), `font(.system(size: 11, weight: .semibold))`, Capsule shape.
- Gold border overlay: `RoundedRectangle(cornerRadius: 24).stroke(Color.msGold, lineWidth: 1.5)`
- `onTapGesture` stays: opens `OwnMomentFullView`

**Note:** `ownMomentCard` currently receives a `MomentFeedItem` which already has `secondaryPhotoUrl`. No model changes needed.

**Note on PiP state:** The pinned card is a pure display card (no interaction needed for swap — the full-screen view handles swap). Skip the `swapped` state here; just show primary as main and secondary as static PiP inset.

```swift
private func ownMomentCard(_ moment: MomentFeedItem) -> some View {
    ZStack(alignment: .bottomLeading) {
        // Primary photo — fills card
        CachedAsyncImage(url: moment.photoUrl) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color(hex: "243828").overlay(ProgressView().tint(Color(hex: "D4A240")))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipped()

        // Secondary PiP inset
        if let secondaryUrl = moment.secondaryPhotoUrl {
            CachedAsyncImage(url: secondaryUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(hex: "243828")
            }
            .frame(width: 80, height: 107)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .padding(10)
        }
    }
    .overlay(alignment: .topTrailing) {
        // Shared pill — top-right
        Text("Shared with \(moment.circleIds.count) Circle\(moment.circleIds.count == 1 ? "" : "s")")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hex: "1A2E1E"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "D4A240"), in: Capsule())
            .padding(10)
    }
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay(
        RoundedRectangle(cornerRadius: 24)
            .stroke(Color.msGold, lineWidth: 1.5)
    )
}
```

Update the call site in `globalFeedPage` — remove the fixed `frame(height: 120)` wrapper:
```swift
if momentService.hasPostedToday,
   let moment = ownMomentItem(for: userId) {
    ownMomentCard(moment)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .onTapGesture { expandedOwnMoment = moment }
}
```
(The `.onTapGesture` moves to the call site because `ownMomentCard` returns a plain view now — not a Button. If `.onTapGesture` conflicts with the PiP, that's fine; PiP is static in this card.)

---

### Directive 4 — Grouped Check-in: Floating Header Above Card

**File:** `Circles/Feed/FeedView.swift` — `GroupedCheckinCard`

Move `FeedIdentityHeader` out of the card background. The card body contains only the habit pills + count text + reactions + comment button.

```swift
struct GroupedCheckinCard: View {
    let group: UserCheckinGroup
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Floating identity header — NO card background behind this
            FeedIdentityHeader(
                avatarUrl: group.avatarUrl,
                displayName: group.userName,
                circleName: group.circleName,
                timestamp: relativeTimestamp(group.latestTimestamp)
            )
            .padding(.horizontal, 4) // small inset so avatar aligns with card edge

            // Card body
            VStack(alignment: .leading, spacing: 10) {
                if !group.habitCheckins.isEmpty {
                    Text("Completed \(group.habitCheckins.count) intention\(group.habitCheckins.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "8FAF94"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(group.habitCheckins) { checkin in
                                Text(checkin.habitName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color(hex: "1A2E1E"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "D4A240"), in: Capsule())
                            }
                        }
                    }
                }

                ForEach(group.streakMilestones) { milestone in
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "D4A240"))
                        Text("\(milestone.streakDays)-day streak on '\(milestone.habitName)'")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "F0EAD6"))
                    }
                }

                HStack {
                    if let first = group.habitCheckins.first {
                        ReactionBar(itemId: first.id, itemType: "habit_checkin",
                                    currentUserId: currentUserId, viewModel: viewModel)
                    } else if let first = group.streakMilestones.first {
                        ReactionBar(itemId: first.id, itemType: "streak_milestone",
                                    currentUserId: currentUserId, viewModel: viewModel)
                    }
                    Spacer()
                    if let onComment {
                        Button(action: onComment) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "8FAF94"))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "243828"))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1))
            )
        }
    }

    private func relativeTimestamp(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? {
            f.formatOptions = [.withInternetDateTime]; return f.date(from: iso)
        }() else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(max(1, Int(diff / 60)))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
```

---

## Files to Touch

| File | Changes |
|------|---------|
| `Circles/Services/FeedService.swift` | D1: concurrent URL resolution |
| `Circles/Community/CommunityView.swift` | D2: header restyle, D3: Me card |
| `Circles/Feed/FeedView.swift` | D4: GroupedCheckinCard floating header |

No model, DB, or service changes beyond FeedService.

## After All 4 Directives
- Build must succeed (zero errors)
- Update STATE.md: Wave 3/4 marked complete
- Commit + push

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)

## Deferred
- Own-post PiP in the pinned strip now implemented (D3). Full swap interaction lives in OwnMomentFullView only.
- Other-user PiP testing: use MomentFeedCard `#Preview` in Xcode canvas.
- Wave 5 (Circles screen) queued after Wave 3/4 sign-off.
