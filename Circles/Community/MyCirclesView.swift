import SwiftUI

// MARK: - MyCirclesView

struct MyCirclesView: View {
    let circles: [Circle]
    let cardDataMap: [UUID: CircleCardData]
    let pinnedCircleIDs: Set<UUID>
    let sendingNudgeCircleIDs: Set<UUID>
    let onNudge: (UUID) -> Void

    @State private var centeredId: UUID?
    @State private var selectedCircle: Circle?

    private var activeGradientColors: [Color] {
        if let id = centeredId,
           let circle = circles.first(where: { $0.id == id }) {
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
            .animation(.easeInOut(duration: 0.35), value: centeredId)

            GeometryReader { proxy in
                let deckWidth = min(max(proxy.size.width * 0.76, 286), 338)
                let horizontalInset = max(18, (proxy.size.width - deckWidth) / 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(circles) { circle in
                            CircleDeckCard(
                                circle: circle,
                                data: cardDataMap[circle.id],
                                isFeatured: centeredId == circle.id,
                                isPinned: pinnedCircleIDs.contains(circle.id),
                                isSendingEncouragement: sendingNudgeCircleIDs.contains(circle.id),
                                onOpen: { selectedCircle = circle },
                                onEncourage: { onNudge(circle.id) }
                            )
                            .frame(width: deckWidth)
                            .frame(maxHeight: .infinity)
                            .id(circle.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $centeredId)
                .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
                .sensoryFeedback(.impact(weight: .medium), trigger: centeredId)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if centeredId == nil {
                centeredId = circles.first?.id
            }
        }
        .onChange(of: circles.map(\.id)) { _, ids in
            if centeredId == nil || !ids.contains(centeredId ?? UUID()) {
                centeredId = ids.first
            }
        }
        .navigationDestination(item: $selectedCircle) { circle in
            CircleDetailView(circle: circle)
        }
    }
}

// MARK: - Deck Card

private struct CircleDeckCard: View {
    let circle: Circle
    let data: CircleCardData?
    let isFeatured: Bool
    let isPinned: Bool
    let isSendingEncouragement: Bool
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

            Group {
                if let data {
                    if isFeatured {
                        FeaturedCircleCardContent(
                            circle: circle,
                            data: data,
                            accentColor: accentColor,
                            isPinned: isPinned,
                            isSendingEncouragement: isSendingEncouragement,
                            onOpen: onOpen,
                            onEncourage: onEncourage
                        )
                    } else {
                        CompactCircleCardContent(
                            circle: circle,
                            data: data,
                            accentColor: accentColor,
                            isPinned: isPinned
                        )
                    }
                } else {
                    CircleCardSkeleton(isFeatured: isFeatured)
                }
            }
            .padding(isFeatured ? 22 : 18)

            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.msGold.opacity(isFeatured ? 0.28 : 0.16),
                            Color.white.opacity(0.08),
                            accentColor.opacity(isFeatured ? 0.18 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFeatured ? 1.2 : 1
                )
        }
        .frame(maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: accentColor.opacity(isFeatured ? 0.26 : 0.14), radius: isFeatured ? 22 : 12, x: 0, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture(perform: onOpen)
        .scrollTransition { content, phase in
            content
                .opacity(1.0 - abs(phase.value) * 0.28)
                .scaleEffect(1.0 - abs(phase.value) * 0.08)
                .blur(radius: abs(phase.value) * 3)
                .offset(x: phase.value * -16)
        }
    }
}

// MARK: - Featured Card

private struct FeaturedCircleCardContent: View {
    let circle: Circle
    let data: CircleCardData
    let accentColor: Color
    let isPinned: Bool
    let isSendingEncouragement: Bool
    let onOpen: () -> Void
    let onEncourage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader

            HStack(alignment: .bottom, spacing: 14) {
                StoryHeroPanel(data: data, accentColor: accentColor)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(data.supportingMembers.prefix(3)), id: \.id) { member in
                        CompactMemberChip(member: member)
                    }

                    if data.supportingMembers.count > 3 {
                        Text("+\(data.supportingMembers.count - 3) more")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.msTextMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: 92)
            }
            .frame(height: 220)

            VStack(alignment: .leading, spacing: 6) {
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
                    EncourageActionChip(
                        title: data.encourageTitle,
                        isSending: isSendingEncouragement,
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
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    PulseDotView(color: data.pulseDotColor)
                    Text(data.statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.msTextMuted)
                        .textCase(.uppercase)
                }

                HStack(spacing: 8) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.msGold)
                    }

                    Text(circle.name)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            MomentumBadge(text: data.momentumLabel, accentColor: accentColor)
        }
    }
}

// MARK: - Compact Card

private struct CompactCircleCardContent: View {
    let circle: Circle
    let data: CircleCardData
    let accentColor: Color
    let isPinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.msGold)
                        }

                        Text(circle.name)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .lineLimit(1)
                    }

                    Text(data.compactLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.msTextMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                CompactStreakChip(text: data.momentumLabel)
            }

            if let imageURL = data.heroImageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                HStack(spacing: 12) {
                    if let hero = data.primaryHero {
                        AvatarView(
                            avatarUrl: hero.avatarUrl,
                            name: hero.displayName,
                            size: 62
                        )
                        .overlay(
                            SwiftUI.Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(data.primaryHero?.displayName ?? "Your circle")
                            .font(.system(size: 19, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .lineLimit(2)

                        Text(data.activeSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            }

            HStack(spacing: 8) {
                OverlapFaceStack(members: Array(data.members.prefix(3)))
                Text(data.activeSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.msTextMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Shared Card Parts

private struct StoryHeroPanel: View {
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

                    Text(data.primaryHero?.displayName ?? data.circle.name)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .lineLimit(2)

                    Text(data.heroCaption ?? data.activeSummary)
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
        .frame(height: 220)
    }
}

private struct OverlapFaceStack: View {
    let members: [CircleCardMember]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(members.prefix(3)), id: \.id) { member in
                AvatarView(
                    avatarUrl: member.avatarUrl,
                    name: member.displayName,
                    size: 28
                )
                .overlay(
                    SwiftUI.Circle()
                        .stroke(Color.msBackground, lineWidth: 1.5)
                )
            }
        }
    }
}

private struct CompactMemberChip: View {
    let member: CircleCardMember

    var body: some View {
        HStack(spacing: 8) {
            AvatarView(
                avatarUrl: member.avatarUrl,
                name: member.displayName,
                size: 34
            )
            .overlay(
                SwiftUI.Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )

            Text(member.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.msTextMuted)
                .lineLimit(1)
        }
    }
}

private struct CompactStreakChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.msTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

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

private struct EncourageActionChip: View {
    let title: String
    let isSending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(hex: "1A2E1E"))
                } else {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(isSending ? "Sending..." : title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color(hex: "1A2E1E"))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.msGold, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isSending)
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

private struct CircleCardSkeleton: View {
    let isFeatured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: isFeatured ? 172 : 132, height: isFeatured ? 30 : 24)
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 90, height: 32)
            }

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.12))
                .frame(maxWidth: .infinity)
                .frame(height: isFeatured ? 220 : 164)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.12))
                .frame(width: isFeatured ? 220 : 180, height: isFeatured ? 24 : 18)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.10))
                .frame(width: isFeatured ? 190 : 150, height: 14)

            Spacer(minLength: 0)
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Edit Layout

struct EditCirclesLayoutView: View {
    @Bindable var viewModel: CirclesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.pinnedCircles.isEmpty {
                    Section {
                        ForEach(viewModel.pinnedCircles) { circle in
                            EditableCircleRow(
                                circle: circle,
                                isPinned: true,
                                onTogglePin: { viewModel.togglePinned(circleId: circle.id) }
                            )
                        }
                        .onMove { viewModel.movePinnedCircles(from: $0, to: $1) }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pinned Circles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.msTextMuted)
                            Text("Pinned circles stay first in the deck.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.msTextMuted.opacity(0.55))
                        }
                        .textCase(nil)
                    }
                }

                Section {
                    ForEach(viewModel.unpinnedCircles) { circle in
                        EditableCircleRow(
                            circle: circle,
                            isPinned: false,
                            onTogglePin: { viewModel.togglePinned(circleId: circle.id) }
                        )
                    }
                    .onMove { viewModel.moveUnpinnedCircles(from: $0, to: $1) }
                } header: {
                    Text("Other Circles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.msTextMuted)
                        .textCase(nil)
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.msBackgroundDeep)
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Circles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
            }
        }
    }
}

private struct EditableCircleRow: View {
    let circle: Circle
    let isPinned: Bool
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isPinned ? Color.msGold : Color.msTextMuted)
                .frame(width: 22)
                .onTapGesture(perform: onTogglePin)

            VStack(alignment: .leading, spacing: 4) {
                Text(circle.name)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                Text(circle.groupStreakDaysSafe == 0 ? "New circle" : "\(circle.groupStreakDaysSafe) day streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.msTextMuted)
            }

            Spacer(minLength: 0)

            Button(action: onTogglePin) {
                Text(isPinned ? "Unpin" : "Pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPinned ? Color.msTextMuted : Color.msGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
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
