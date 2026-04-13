import SwiftUI

// MARK: - MyCirclesView (Focused Stage)

struct MyCirclesView: View {
    let circles: [Circle]
    let cardDataMap: [UUID: CircleCardData]
    let onCreateCircle: () -> Void
    let onJoinCircle: () -> Void
    let onNudge: (UUID) -> Void

    @State private var centeredId: UUID?
    @State private var selectedCircle: Circle?

    private var sortedCircles: [Circle] {
        circles.sorted { a, b in
            if a.groupStreakDaysSafe != b.groupStreakDaysSafe {
                return a.groupStreakDaysSafe > b.groupStreakDaysSafe
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private var activeGradientColors: [Color] {
        if let id = centeredId,
           let circle = sortedCircles.first(where: { $0.id == id }) {
            return CircleColorDeriver.gradient(for: circle.name)
        }
        return [Color.msBackground, Color.msBackgroundDeep]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: activeGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: centeredId)

            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 24) {
                        ForEach(sortedCircles) { circle in
                            CircleVignetteCard(
                                circle: circle,
                                data: cardDataMap[circle.id],
                                onOpen: { selectedCircle = circle },
                                onEncourage: { onNudge(circle.id) }
                            )
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

                GemBar(
                    circles: sortedCircles,
                    centeredId: $centeredId,
                    onCreateCircle: onCreateCircle,
                    onJoinCircle: onJoinCircle
                )
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            if centeredId == nil {
                centeredId = sortedCircles.first?.id
            }
        }
        .onChange(of: sortedCircles.map(\.id)) { _, ids in
            if centeredId == nil || !ids.contains(centeredId ?? UUID()) {
                centeredId = ids.first
            }
        }
        .navigationDestination(item: $selectedCircle) { circle in
            CircleDetailView(circle: circle)
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

// MARK: - Vignette Card

private struct CircleVignetteCard: View {
    let circle: Circle
    let data: CircleCardData?
    let onOpen: () -> Void
    let onEncourage: () -> Void

    private var cardGradient: [Color] {
        CircleColorDeriver.gradient(for: circle.name)
    }

    private var accentColor: Color {
        CircleColorDeriver.accent(for: circle.name)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: cardGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), .clear, accentColor.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let data {
                liveCardContent(data: data)
            } else {
                skeletonContent
            }

            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.msGold.opacity(0.28),
                            Color.white.opacity(0.08),
                            accentColor.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .frame(maxHeight: .infinity)
        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: accentColor.opacity(0.28), radius: 20, x: 0, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture(perform: onOpen)
        .scrollTransition { content, phase in
            content
                .opacity(1.0 - abs(phase.value) * 0.6)
                .scaleEffect(1.0 - abs(phase.value) * 0.18)
                .blur(radius: abs(phase.value) * 14)
                .offset(x: phase.value * -28)
        }
        .padding(.vertical, 16)
    }

    private func liveCardContent(data: CircleCardData) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PulseDotView(color: data.pulseDotColor)
                        Text(data.statusLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(.uppercase)
                    }

                    Text(circle.name)
                        .font(.system(size: 29, weight: .bold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                MomentumBadge(text: data.momentumLabel, accentColor: accentColor)
            }

            HStack(alignment: .bottom, spacing: 16) {
                HeroPanel(
                    data: data,
                    accentColor: accentColor
                )

                SupportingMembersRail(
                    hero: data.primaryHero,
                    supportingMembers: data.supportingMembers,
                    accentColor: accentColor
                )
                .frame(width: 94)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(data.headline)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .lineLimit(2)

                Text(data.supportingLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.msTextMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                CircleActionChip(
                    title: "Open Circle",
                    systemImage: "arrow.up.right",
                    tint: Color.white.opacity(0.12),
                    foreground: Color.msTextPrimary,
                    action: onOpen
                )

                if data.showEncourageCTA {
                    CircleActionChip(
                        title: data.encourageTitle,
                        systemImage: "hand.wave.fill",
                        tint: Color.msGold,
                        foreground: Color(hex: "1A2E1E"),
                        action: onEncourage
                    )
                } else {
                    StatusChip(
                        text: data.activeSummary,
                        accentColor: accentColor
                    )
                }
            }
        }
        .padding(24)
    }

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 72, height: 16)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 180, height: 30)
                }

                Spacer()

                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 88, height: 34)
            }

            HStack(alignment: .bottom, spacing: 16) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 218)

                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SwiftUI.Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 44, height: 44)
                    }
                }
                .frame(width: 94)
            }

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.12))
                .frame(width: 220, height: 28)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.1))
                .frame(width: 190, height: 16)

            Spacer()

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 122, height: 42)
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 132, height: 42)
            }
        }
        .padding(24)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Hero Panel

private struct HeroPanel: View {
    let data: CircleCardData
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.14))

            if let imageURL = data.heroImageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.28), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 14) {
                    if let hero = data.primaryHero {
                        AvatarView(
                            avatarUrl: hero.avatarUrl,
                            name: hero.displayName,
                            size: 72
                        )
                        .overlay(
                            SwiftUI.Circle()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }

                    Spacer(minLength: 0)

                    Text(data.primaryHero?.displayName ?? circleFallbackName)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)

                    Text(data.heroCaption ?? "Open the circle and bring someone back into the room.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.msTextMuted)
                        .lineLimit(2)
                }
                .padding(18)
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let timestamp = data.latestSignalTimestamp {
                        MiniPill(
                            text: CircleCardData.relativeTimestamp(timestamp),
                            accentColor: accentColor
                        )
                    }
                    if data.latestMoment != nil {
                        MiniPill(text: "Moment", accentColor: Color.msGold)
                    }
                }

                if let caption = data.heroCaption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.94))
                        .lineLimit(2)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 218)
    }

    private var circleFallbackName: String {
        data.circle.name
    }
}

// MARK: - Supporting Rail

private struct SupportingMembersRail: View {
    let hero: CircleCardMember?
    let supportingMembers: [CircleCardMember]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(supportingMembers.prefix(3).enumerated()), id: \.element.id) { _, member in
                AvatarView(
                    avatarUrl: member.avatarUrl,
                    name: member.displayName,
                    size: 44
                )
                .overlay(
                    SwiftUI.Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            }

            if supportingMembers.count > 3 {
                Text("+\(supportingMembers.count - 3)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msTextMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            } else if supportingMembers.isEmpty, let hero {
                Text(hero.isCurrentUser ? "Just you" : "Lead")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msTextMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }

            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
                )
                .frame(height: 74)
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Circle")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(.uppercase)

                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accentColor)
                    }
                    .padding(12),
                    alignment: .topLeading
                )
        }
    }
}

// MARK: - Chips

private struct MomentumBadge: View {
    let text: String
    let accentColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.msTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
    }
}

private struct CircleActionChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct StatusChip: View {
    let text: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 7) {
            SwiftUI.Circle()
                .fill(accentColor.opacity(0.85))
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(Color.msTextMuted)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

private struct MiniPill: View {
    let text: String
    let accentColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(accentColor.opacity(0.28), in: Capsule())
    }
}

// MARK: - Pulse Dot

private struct PulseDotView: View {
    let color: Color

    @State private var isPulsing = false

    var body: some View {
        SwiftUI.Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(color == .green && isPulsing ? 1.35 : 1.0)
            .opacity(color == .green && isPulsing ? 0.7 : 1.0)
            .animation(
                color == .green
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                if color == .green { isPulsing = true }
            }
    }
}

// MARK: - Circle Color Deriver

enum CircleColorDeriver {
    private static func nameHash(_ name: String) -> Int {
        abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
    }

    static func gradient(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "1A2E1E"), Color(hex: "243828")],
            [Color(hex: "1E2A30"), Color(hex: "1A3040")],
            [Color(hex: "2A1E1E"), Color(hex: "3A2828")],
            [Color(hex: "1E2420"), Color(hex: "2A3830")],
            [Color(hex: "2A2818"), Color(hex: "3A3620")],
            [Color(hex: "201E2A"), Color(hex: "2C2838")]
        ]
        return palettes[nameHash(name) % palettes.count]
    }

    static func accent(for name: String) -> Color {
        let accents: [Color] = [
            Color(hex: "4A9E6B"),
            Color(hex: "5B8EC9"),
            Color(hex: "C96B5B"),
            Color(hex: "8B6BBF"),
            Color(hex: "D4A240"),
            Color(hex: "5BBFB0")
        ]
        return accents[nameHash(name) % accents.count]
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.msGold, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onJoinCircle) {
                    Text("Join with Code")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
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
