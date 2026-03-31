import SwiftUI

// MARK: - MyCirclesView

struct MyCirclesView: View {
    let circles: [Circle]
    let onCreateCircle: () -> Void
    let onJoinCircle: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if !circles.isEmpty { featuredGrid }
                if circles.count > 3 { overflowGrid }
                ctaButtons.padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Featured grid (first 3 circles)

    private var featuredGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(destination: CircleDetailView(circle: circles[0])) {
                FeaturedCircleCard(circle: circles[0])
            }
            .buttonStyle(.plain)

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

    // MARK: - Overflow grid

    private var overflowGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(circles.dropFirst(3)) { circle in
                NavigationLink(destination: CircleDetailView(circle: circle)) {
                    SmallCircleCard(circle: circle).frame(height: 134)
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
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                    Text("Create a Circle").font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "1A2E1E"))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(hex: "D4A240"), in: Capsule())
                .shadow(color: Color(hex: "D4A240").opacity(0.35), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: onJoinCircle) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus").font(.system(size: 15, weight: .semibold))
                    Text("Join with Code").font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "D4A240"))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .overlay(Capsule().stroke(Color(hex: "D4A240"), lineWidth: 1.5))
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
            UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 28,
                bottomTrailingRadius: 40, topTrailingRadius: 28
            )
            .fill(Color(hex: "243828"))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28, bottomLeadingRadius: 28,
                    bottomTrailingRadius: 40, topTrailingRadius: 28
                )
                .stroke(Color(hex: "D4A240").opacity(0.35), lineWidth: 1.5)
            )

            VStack(spacing: 10) {
                Spacer(minLength: 0)

                Text(circle.name)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "F0EAD6"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 12)

                MemberDots(circleId: circle.id, count: 5, dotSize: 13)

                Image(systemName: CircleIconPicker.icon(for: circle.name))
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(hex: "D4A240"))
                    .shadow(color: Color(hex: "D4A240").opacity(0.5), radius: 6)

                if circle.groupStreakDaysSafe > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "D4A240"))
                        Text("\(circle.groupStreakDaysSafe) day streak")
                            .font(.system(size: 11, weight: .medium))
                            .italic()
                            .foregroundStyle(Color(hex: "8FAF94"))
                    }
                } else if let desc = circle.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(Color(hex: "8FAF94").opacity(0.8))
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
                .fill(Color(hex: "1E3122"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1.5)
                )

            VStack(spacing: 6) {
                Text(circle.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "F0EAD6"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)

                MemberDots(circleId: circle.id, count: 3, dotSize: 10)

                Image(systemName: CircleIconPicker.icon(for: circle.name))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: "D4A240"))
                    .shadow(color: Color(hex: "D4A240").opacity(0.45), radius: 4)

                if circle.groupStreakDaysSafe > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "D4A240"))
                        Text("\(circle.groupStreakDaysSafe)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "8FAF94"))
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
                .foregroundStyle(Color(hex: "D4A240").opacity(0.65))

            VStack(spacing: 8) {
                Text("Your Circles")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "F0EAD6"))
                Text("Create or join a circle to begin your journey.")
                    .font(.appSubheadline)
                    .foregroundStyle(Color(hex: "8FAF94"))
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
                    .background(Color(hex: "D4A240"), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onJoinCircle) {
                    Text("Join with Code")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "D4A240"))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .overlay(Capsule().stroke(Color(hex: "D4A240"), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
