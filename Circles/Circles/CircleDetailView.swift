import SwiftUI
import Supabase

struct CircleDetailView: View {
    let circle: Circle

    // Feed state
    @State private var feedViewModel = FeedViewModel()

    // Members state
    @State private var members: [CircleMember] = []
    @State private var checkedInCount = 0
    @State private var isLoadingMembers = true
    @State private var showMembersSheet = false

    // Moment window state
    @State private var windowSecondsRemaining: Int = 0
    @State private var windowTimer: Timer?

    // Camera / post state
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showPreview = false

    @Environment(AuthManager.self) private var auth

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

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0D1021").ignoresSafeArea()

            VStack(spacing: 0) {
                // Active window banner
                if isWindowActive {
                    momentBanner
                }

                ScrollView {

                    LazyVStack(spacing: 0) {
                        // Circle info header
                        if let desc = circle.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }

                        // Invite section
                        VStack(alignment: .leading, spacing: 0) {
                            if let code = circle.inviteCode {
                                HStack {
                                    Text("Code:")
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text(code)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }

                            ShareLink(item: inviteURL) {
                                Label("Invite Friends", systemImage: "square.and.arrow.up")
                                    .foregroundStyle(Color(hex: "E8834B"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.06))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Notifications-off inline note (shown when permission is denied)
                        if NotificationService.shared.permissionStatus == .denied {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.slash.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "E8834B").opacity(0.8))
                                Text("Notifications off — turn on in Settings to get Moment alerts")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.04))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Members summary row
                        Button {
                            showMembersSheet = true
                        } label: {
                            HStack {
                                Text("\(members.count) members · \(checkedInCount) checked in today")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .sheet(isPresented: $showMembersSheet) {
                            MembersListView(
                                members: members,
                                currentUserId: auth.session?.user.id,
                                senderId: auth.session?.user.id,
                                circleId: circle.id
                            )
                        }

                        // Activity section label
                        Text("Activity")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // Initial load indicator
                        if feedViewModel.isLoadingInitial {
                            HStack {
                                Spacer()
                                ProgressView().tint(Color(hex: "E8834B"))
                                Spacer()
                            }
                            .padding(.vertical, 24)
                        }

                        // Feed
                        if let userId = auth.session?.user.id {
                            FeedView(
                                circleId: circle.id,
                                currentUserId: userId,
                                viewModel: feedViewModel
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    guard let userId = auth.session?.user.id else { return }
                    await feedViewModel.refresh(circleId: circle.id, currentUserId: userId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            guard let userId = auth.session?.user.id else { return }

            // Refresh notification permission status for inline note
            await NotificationService.shared.refreshPermissionStatus()

            // Load members and feed in parallel
            async let membersFetch = CircleService.shared.fetchMembers(circleId: circle.id)
            members = (try? await membersFetch) ?? []
            checkedInCount = 0  // Phase 5: no per-member check-in status yet; wired in future phase
            isLoadingMembers = false

            // Start window countdown timer if window is active
            startWindowTimer()

            // Load feed
            await feedViewModel.loadInitial(circleId: circle.id, currentUserId: userId)
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
                        guard let userId = auth.session?.user.id else { return }
                        let _ = try await MomentService.shared.postMoment(
                            image: image,
                            circleId: circle.id,
                            userId: userId,
                            caption: caption,
                            windowStart: circle.momentWindowStart
                        )
                        // Refresh feed to update reciprocity gate and show new Moment
                        await feedViewModel.refresh(circleId: circle.id, currentUserId: userId)
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

    // MARK: - Nudge

    private func sendNudge(to targetUserId: UUID, nudgeType: String) async {
        guard let senderId = auth.session?.user.id else { return }
        do {
            try await SupabaseService.shared.client.functions
                .invoke(
                    "send-peer-nudge",
                    options: .init(body: [
                        "senderId": senderId.uuidString,
                        "targetUserId": targetUserId.uuidString,
                        "circleId": circle.id.uuidString,
                        "nudgeType": nudgeType
                    ])
                )
        } catch {
            // Rate-limited (429) or network error — fail silently; no UX disruption
            print("[CircleDetailView] Nudge failed: \(error)")
        }
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

// MARK: - Members List Sheet

private struct MembersListView: View {
    let members: [CircleMember]
    let currentUserId: UUID?
    let senderId: UUID?
    let circleId: UUID

    var body: some View {
        ZStack {
            Color(hex: "0D1021").ignoresSafeArea()
            List(members) { member in
                HStack {
                    Text(member.userId.uuidString.prefix(8))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    if member.role == "admin" {
                        Text("Admin")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "E8834B"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "E8834B").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    // Nudge buttons — only for other members, not self
                    if member.userId != currentUserId {
                        HStack(spacing: 6) {
                            Button {
                                Task {
                                    await sendNudge(to: member.userId, type: "moment", circleId: circleId)
                                }
                            } label: {
                                Text("Moment")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color(hex: "E8834B"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "E8834B").opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task {
                                    await sendNudge(to: member.userId, type: "habit", circleId: circleId)
                                }
                            } label: {
                                Text("Habit")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color(hex: "E8834B"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "E8834B").opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Members")
        .presentationDetents([.medium, .large])
    }

    private func sendNudge(to targetUserId: UUID, type nudgeType: String, circleId: UUID) async {
        guard let senderId else { return }
        do {
            try await SupabaseService.shared.client.functions
                .invoke(
                    "send-peer-nudge",
                    options: .init(body: [
                        "senderId": senderId.uuidString,
                        "targetUserId": targetUserId.uuidString,
                        "circleId": circleId.uuidString,
                        "nudgeType": nudgeType
                    ])
                )
        } catch {
            print("[MembersListView] Nudge failed: \(error)")
        }
    }
}
