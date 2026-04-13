import SwiftUI

// MARK: - MyCirclesView (Focused Stage)

struct MyCirclesView: View {
    let circles: [Circle]
    let onCreateCircle: () -> Void
    let onJoinCircle: () -> Void

    @State private var centeredId: UUID?

    /// Sorted circles: active (highest streak, then alphabetical) first
    private var sortedCircles: [Circle] {
        circles.sorted { a, b in
            if a.groupStreakDaysSafe != b.groupStreakDaysSafe {
                return a.groupStreakDaysSafe > b.groupStreakDaysSafe
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stage carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(sortedCircles) { circle in
                        NavigationLink(destination: CircleDetailView(circle: circle)) {
                            CircleVignetteCard(circle: circle)
                        }
                        .buttonStyle(.plain)
                        .id(circle.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredId)
            .contentMargins(.horizontal, 36, for: .scrollContent)
            .sensoryFeedback(.impact(weight: .medium), trigger: centeredId)

            Spacer(minLength: 0)

            // Gem Bar — pinned above tab bar
            GemBar(
                circles: sortedCircles,
                centeredId: $centeredId,
                onCreateCircle: onCreateCircle,
                onJoinCircle: onJoinCircle
            )
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Gem Bar

private struct GemBar: View {
    let circles: [Circle]
    @Binding var centeredId: UUID?
    let onCreateCircle: () -> Void
    let onJoinCircle: () -> Void

    @State private var showActionSheet = false

    var body: some View {
        HStack(spacing: 14) {
            ForEach(circles) { circle in
                let isActive = circle.id == centeredId
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        centeredId = circle.id
                    }
                } label: {
                    ZStack {
                        // Active glow ring
                        if isActive {
                            SwiftUI.Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.msGold.opacity(0.25), Color.clear],
                                        center: .center,
                                        startRadius: 8,
                                        endRadius: 20
                                    )
                                )
                                .frame(width: 38, height: 38)
                        }

                        // Gem icon
                        Image(systemName: CircleIconPicker.icon(for: circle.name))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isActive ? Color.msGold : Color.msTextMuted.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(
                                SwiftUI.Circle()
                                    .fill(Color.msBackground.opacity(0.8))
                            )
                            .overlay(
                                SwiftUI.Circle()
                                    .stroke(
                                        isActive ? Color.msGold.opacity(0.6) : Color.msGold.opacity(0.12),
                                        lineWidth: isActive ? 1.5 : 1
                                    )
                            )
                    }
                    .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.25), value: isActive)
            }

            // Permanent gold '+' gem
            Button {
                showActionSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "1A2E1E"))
                    .frame(width: 28, height: 28)
                    .background(Color.msGold, in: SwiftUI.Circle())
                    .shadow(color: Color.msGold.opacity(0.3), radius: 6)
            }
            .buttonStyle(.plain)
            .confirmationDialog("Expand the Brotherhood", isPresented: $showActionSheet) {
                Button("Create a Circle") { onCreateCircle() }
                Button("Join with Invite Code") { onJoinCircle() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.msGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Vignette Card (Stage Model)

private struct CircleVignetteCard: View {
    let circle: Circle

    private var iconName: String {
        CircleIconPicker.icon(for: circle.name)
    }

    private var cardGradient: [Color] {
        CircleColorDeriver.gradient(for: circle.name)
    }

    private var accentColor: Color {
        CircleColorDeriver.accent(for: circle.name)
    }

    var body: some View {
        ZStack {
            // Layer 1: Background gradient
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: cardGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Layer 2: Atmospheric radial
            RadialGradient(
                colors: [accentColor.opacity(0.08), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 250
            )

            // Layer 3: Content
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Name + Artifact composite — name sits behind
                ZStack {
                    // Ghost name — massive, behind
                    Text(circle.name)
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary.opacity(0.08))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)

                    // Artifact
                    artifactView
                }

                Spacer().frame(height: 20)

                // Circle name — readable
                Text(circle.name)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Stats bar
                statsBar

                // Description
                if let desc = circle.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                        .padding(.top, 14)
                }

                Spacer(minLength: 24)
            }

            // Layer 4: Gradient border
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.msGold.opacity(0.35),
                            accentColor.opacity(0.15),
                            Color.msGold.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .frame(maxHeight: .infinity)
        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        // Stage focus: center = hero, neighbors = dimmed/scaled/blurred
        .scrollTransition { content, phase in
            content
                .opacity(1.0 - abs(phase.value) * 0.6)
                .scaleEffect(1.0 - abs(phase.value) * 0.2)
                .blur(radius: abs(phase.value) * 15)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Artifact

    private var artifactView: some View {
        ZStack {
            // Outer glow ring
            SwiftUI.Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.2),
                            accentColor.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Inner glow core
            SwiftUI.Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.msGold.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.msGold, accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.msGold.opacity(0.5), radius: 16)
                .shadow(color: accentColor.opacity(0.3), radius: 8)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            if circle.groupStreakDaysSafe > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.msGold)
                    Text("\(circle.groupStreakDaysSafe) day streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.msTextPrimary)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
                MemberDots(circleId: circle.id, count: 5, dotSize: 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Circle Color Deriver

enum CircleColorDeriver {
    private static func nameHash(_ name: String) -> Int {
        abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
    }

    /// Returns a 2-color gradient based on the circle name.
    static func gradient(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "1A2E1E"), Color(hex: "243828")],   // deep forest
            [Color(hex: "1E2A30"), Color(hex: "1A3040")],   // midnight sapphire
            [Color(hex: "2A1E1E"), Color(hex: "3A2828")],   // dark ruby
            [Color(hex: "1E2420"), Color(hex: "2A3830")],   // emerald shadow
            [Color(hex: "2A2818"), Color(hex: "3A3620")],   // dark amber
            [Color(hex: "201E2A"), Color(hex: "2C2838")],   // twilight purple
        ]
        return palettes[nameHash(name) % palettes.count]
    }

    /// Returns a unique accent color for glow/tint per circle.
    static func accent(for name: String) -> Color {
        let accents: [Color] = [
            Color(hex: "4A9E6B"),   // emerald
            Color(hex: "5B8EC9"),   // sapphire
            Color(hex: "C96B5B"),   // ruby
            Color(hex: "8B6BBF"),   // amethyst
            Color(hex: "D4A240"),   // gold
            Color(hex: "5BBFB0"),   // teal
        ]
        return accents[nameHash(name) % accents.count]
    }
}

// MARK: - MemberDots

struct MemberDots: View {
    let circleId: UUID
    let count: Int
    let dotSize: CGFloat

    private static let palette: [Color] = [
        Color(hex: "4A7C59"), Color(hex: "5E9E72"),
        Color(hex: "3D6B4F"), Color(hex: "6BB580"),
        Color(hex: "2E5740"), Color(hex: "7DB894"),
        Color(hex: "527A62")
    ]

    private func color(at index: Int) -> Color {
        let seed = abs(circleId.hashValue &+ index * 1_000_003)
        return Self.palette[seed % Self.palette.count]
    }

    var body: some View {
        HStack(spacing: -(dotSize * 0.4)) {
            ForEach(0..<count, id: \.self) { i in
                SwiftUI.Circle()
                    .fill(color(at: i))
                    .frame(width: dotSize, height: dotSize)
                    .zIndex(Double(count - i))
            }
        }
    }
}

// MARK: - CircleIconPicker

enum CircleIconPicker {
    private static let icons = [
        "moon.stars.fill", "book.fill", "hands.sparkles.fill",
        "heart.fill", "star.fill", "sun.max.fill",
        "leaf.fill", "sparkles", "checkmark.seal.fill"
    ]

    static func icon(for name: String) -> String {
        let hash = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return icons[hash % icons.count]
    }
}

// MARK: - Empty State

struct MyCirclesEmptyView: View {
    let onCreateCircle: () -> Void
    let onJoinCircle: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.msGold.opacity(0.65))

            VStack(spacing: 8) {
                Text("Your Circles")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                Text("Create or join a circle to begin your journey.")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: onCreateCircle) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Create a Circle").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "1A2E1E"))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color.msGold, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onJoinCircle) {
                    Text("Join with Code")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .overlay(Capsule().stroke(Color.msGold, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
