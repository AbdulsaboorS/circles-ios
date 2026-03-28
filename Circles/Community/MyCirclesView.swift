import SwiftUI

// MARK: - MyCirclesView

struct MyCirclesView: View {
    let circles: [Circle]
    let onCreateCircle: () -> Void
    let onJoinCircle: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Featured layout: first 3 circles in hero grid
                if !circles.isEmpty {
                    featuredGrid
                }

                // Overflow: 4th circle onward in 2-column grid
                if circles.count > 3 {
                    overflowGrid
                }

                ctaButtons
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Featured grid (first 3 circles)

    private var featuredGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: featured large card
            NavigationLink(destination: CircleDetailView(circle: circles[0])) {
                FeaturedCircleCard(circle: circles[0])
            }
            .buttonStyle(.plain)

            // Right: up to 2 stacked small cards
            VStack(spacing: 12) {
                if circles.count > 1 {
                    NavigationLink(destination: CircleDetailView(circle: circles[1])) {
                        SmallCircleCard(circle: circles[1])
                    }
                    .buttonStyle(.plain)
                }
                if circles.count > 2 {
                    NavigationLink(destination: CircleDetailView(circle: circles[2])) {
                        SmallCircleCard(circle: circles[2])
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 280)
    }

    // MARK: - Overflow grid (4th circle onward)

    private var overflowGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            ForEach(circles.dropFirst(3)) { circle in
                NavigationLink(destination: CircleDetailView(circle: circle)) {
                    SmallCircleCard(circle: circle)
                        .frame(height: 134)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - CTA Buttons

    private var ctaButtons: some View {
        VStack(spacing: 10) {
            Button(action: onCreateCircle) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Create a Circle")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                }
                .foregroundStyle(Color(hex: "F5F0E8"))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(hex: "1A3A2A"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "1A3A2A").opacity(0.25), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            Button(action: onJoinCircle) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Join with Code")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                }
                .foregroundStyle(Color.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .overlay(
                    Capsule()
                        .stroke(Color.accent, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - FeaturedCircleCard

private struct FeaturedCircleCard: View {
    let circle: Circle

    var body: some View {
        ZStack {
            // Card background
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 40,
                topTrailingRadius: 28
            )
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.95), Color(hex: "F5F0E8").opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 28,
                    bottomTrailingRadius: 40,
                    topTrailingRadius: 28
                )
                .stroke(Color.accent, lineWidth: 1.5)
            )
            .shadow(color: Color.accent.opacity(0.15), radius: 16, x: 0, y: 4)

            VStack(spacing: 10) {
                Spacer(minLength: 0)

                // Circle name
                Text(circle.name)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "1A1209"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 12)

                // Member dot avatars
                MemberDots(circleId: circle.id, count: 5, dotSize: 13)

                // Icon with amber glow
                Image(systemName: CircleIconPicker.icon(for: circle.name))
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .shadow(color: Color.accent.opacity(0.5), radius: 6, x: 0, y: 0)

                // Group streak
                if circle.groupStreakDaysSafe > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accent)
                        Text("\(circle.groupStreakDaysSafe) day streak")
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .italic()
                            .foregroundStyle(Color(hex: "6B5B45"))
                    }
                } else if let desc = circle.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color(hex: "6B5B45").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SmallCircleCard

private struct SmallCircleCard: View {
    let circle: Circle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.95), Color(hex: "F5F0E8").opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "1A3A2A").opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

            VStack(spacing: 6) {
                Text(circle.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "1A1209"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)

                MemberDots(circleId: circle.id, count: 3, dotSize: 10)

                Image(systemName: CircleIconPicker.icon(for: circle.name))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .shadow(color: Color.accent.opacity(0.45), radius: 4, x: 0, y: 0)

                if circle.groupStreakDaysSafe > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accent)
                        Text("\(circle.groupStreakDaysSafe)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "6B5B45"))
                    }
                }
            }
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MemberDots

private struct MemberDots: View {
    let circleId: UUID
    let count: Int
    let dotSize: CGFloat

    private static let palette: [Color] = [
        Color(hex: "D4A5A5"), Color(hex: "A5C4A5"),
        Color(hex: "B5A5D4"), Color(hex: "D4C4A5"),
        Color(hex: "9DB5B5"), Color(hex: "D4B5A5"),
        Color(hex: "A5B5C4")
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

private enum CircleIconPicker {
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
                .foregroundStyle(Color.accent.opacity(0.65))

            VStack(spacing: 8) {
                Text("Your Circles")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "1A1209"))
                Text("Create or join a circle to begin your journey.")
                    .font(.appSubheadline)
                    .foregroundStyle(Color(hex: "6B5B45"))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: onCreateCircle) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Create a Circle")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(Color(hex: "F5F0E8"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "1A3A2A"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onJoinCircle) {
                    Text("Join with Code")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .overlay(Capsule().stroke(Color.accent, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
