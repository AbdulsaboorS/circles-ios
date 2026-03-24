import SwiftUI
import Supabase

struct CircleDetailView: View {
    let circle: Circle

    // Existing state
    @State private var members: [CircleMember] = []
    @State private var isLoading = true

    // Moment state
    @State private var moments: [CircleMoment] = []
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showPreview = false
    @State private var windowSecondsRemaining: Int = 0
    @State private var windowTimer: Timer?

    // MARK: - Computed Properties

    private var inviteURL: URL {
        URL(string: "https://joinlegacy.app/join/\(circle.inviteCode ?? "")")!
    }

    private var isWindowActive: Bool {
        windowSecondsRemaining > 0
    }

    private var countdownText: String {
        let mins = windowSecondsRemaining / 60
        let secs = windowSecondsRemaining % 60
        return String(format: "%02d:%02d remaining", mins, secs)
    }

    private var currentUserId: UUID? {
        SupabaseService.shared.client.auth.currentSession?.user.id
    }

    private var hasPostedToday: Bool {
        guard let userId = currentUserId else { return false }
        return moments.contains { $0.userId == userId }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0D1021").ignoresSafeArea()

            VStack(spacing: 0) {
                // Active window banner
                if isWindowActive {
                    momentBanner
                }

                List {
                    // Circle info header
                    Section {
                        if let desc = circle.description, !desc.isEmpty {
                            Text(desc)
                                .foregroundStyle(.white.opacity(0.8))
                                .listRowBackground(Color.white.opacity(0.06))
                        }
                    }

                    // Moments section
                    Section("Moments") {
                        momentsContent
                            .animation(.easeOut(duration: 0.4), value: hasPostedToday)
                    }
                    .foregroundStyle(.white.opacity(0.6))

                    // Invite section
                    Section("Invite") {
                        if let code = circle.inviteCode {
                            HStack {
                                Text("Code:")
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(code)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .fontWeight(.semibold)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }

                        ShareLink(item: inviteURL) {
                            Label("Invite Friends", systemImage: "square.and.arrow.up")
                                .foregroundStyle(Color(hex: "E8834B"))
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                    .foregroundStyle(.white.opacity(0.6))

                    // Members section
                    Section("Members (\(members.count))") {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView().tint(Color(hex: "E8834B"))
                                Spacer()
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        } else {
                            ForEach(members) { member in
                                HStack {
                                    Text(String(member.userId.uuidString.prefix(8)))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if member.role == "admin" {
                                        Text("Admin")
                                            .font(.caption)
                                            .foregroundStyle(Color(hex: "E8834B"))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(hex: "E8834B").opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            // Fetch members
            do {
                members = try await CircleService.shared.fetchMembers(circleId: circle.id)
            } catch {
                // Non-critical: show empty members list on error
            }
            isLoading = false

            // Fetch today's moments
            do {
                moments = try await MomentService.shared.fetchTodayMoments(circleId: circle.id)
            } catch {
                // Non-critical: moments section shows empty state
            }

            // Start window countdown timer if window is active
            startWindowTimer()
        }
        .onDisappear {
            windowTimer?.invalidate()
        }
        .fullScreenCover(isPresented: $showCamera) {
            MomentCameraView(circleId: circle.id) { image in
                capturedImage = image
                showCamera = false
                showPreview = true
            }
        }
        .sheet(isPresented: $showPreview) {
            if let image = capturedImage {
                MomentPreviewView(
                    image: image,
                    onPost: { caption in
                        guard let userId = currentUserId else { return }
                        let _ = try await MomentService.shared.postMoment(
                            image: image,
                            circleId: circle.id,
                            userId: userId,
                            caption: caption,
                            windowStart: circle.momentWindowStart
                        )
                        // Reload moments to unlock reciprocity gate
                        moments = try await MomentService.shared.fetchTodayMoments(circleId: circle.id)
                    },
                    onRetake: {
                        showPreview = false
                        capturedImage = nil
                        showCamera = true
                    }
                )
                .interactiveDismissDisabled(true)
            }
        }
    }

    // MARK: - Moment Banner

    private var momentBanner: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
            Text("POST YOUR MOMENT")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(countdownText)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(hex: "E8834B"))
        .onTapGesture {
            showCamera = true
        }
        .accessibilityLabel("Post your Moment, \(countdownText). Tap to open camera.")
    }

    // MARK: - Moments Content

    @ViewBuilder
    private var momentsContent: some View {
        let displayCards = momentCards

        if displayCards.isEmpty {
            // Empty state
            Group {
                if isWindowActive {
                    Text("Be the first to post your Moment.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("No Moments yet. Come back when the window opens.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .listRowBackground(Color.white.opacity(0.06))
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(displayCards, id: \.id) { card in
                    MomentCardView(
                        moment: card.moment,
                        isOwnPost: card.isOwnPost,
                        hasPostedToday: hasPostedToday,
                        onTapLocked: { showCamera = true },
                        memberName: card.memberName
                    )
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.white.opacity(0.06))
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        }
    }

    // MARK: - Moment Card Data

    private struct MomentCardData: Identifiable {
        let id: UUID
        let moment: CircleMoment?
        let isOwnPost: Bool
        let memberName: String
    }

    private var momentCards: [MomentCardData] {
        guard !members.isEmpty else { return [] }

        var cards: [MomentCardData] = []

        for member in members {
            let memberMoment = moments.first { $0.userId == member.userId }
            let isOwn = member.userId == currentUserId
            let name = isOwn ? "You" : String(member.userId.uuidString.prefix(8))

            if isOwn {
                // Always show own slot (unposted or posted)
                cards.append(MomentCardData(
                    id: member.userId,
                    moment: memberMoment,
                    isOwnPost: true,
                    memberName: name
                ))
            } else if let memberMoment = memberMoment {
                // Show peer only if they've posted
                cards.append(MomentCardData(
                    id: member.userId,
                    moment: memberMoment,
                    isOwnPost: false,
                    memberName: name
                ))
            }
            // Skip: peer with no moment posted
        }

        return cards
    }

    // MARK: - Window Timer

    private func startWindowTimer() {
        guard let windowStartStr = circle.momentWindowStart else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var startDate = formatter.date(from: windowStartStr)
        if startDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startDate = formatter.date(from: windowStartStr)
        }
        guard let startDate = startDate else { return }

        let elapsed = Date().timeIntervalSince(startDate)
        let remaining = 1800 - elapsed
        guard remaining > 0 else { return }

        windowSecondsRemaining = Int(remaining)

        windowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                if self.windowSecondsRemaining > 0 {
                    self.windowSecondsRemaining -= 1
                } else {
                    self.windowTimer?.invalidate()
                    self.windowTimer = nil
                }
            }
        }
    }
}
