import SwiftUI
import Supabase

struct CircleDetailView: View {
    @State private var circle: Circle
    @State private var detailVM: CircleDetailViewModel
    @State private var feedViewModel = FeedViewModel()

    @State private var showMembersSheet = false
    @State private var windowSecondsRemaining: Int = 0
    @State private var windowTimer: Timer?
    @State private var showCamera = false
    @State private var draftMoment: MomentDraft?
    @State private var showAmirSettings = false
    @State private var allUserCircleIds: [UUID] = []

    @Environment(AuthManager.self) private var auth

    init(circle: Circle) {
        _circle = State(initialValue: circle)
        _detailVM = State(initialValue: CircleDetailViewModel(circleId: circle.id))
    }

    private var isAmir: Bool {
        guard let uid = auth.session?.user.id else { return false }
        return detailVM.members.contains { $0.userId == uid && $0.role == "admin" }
    }

    private var inviteURL: URL {
        URL(string: "https://joinlegacy.app/join/\(circle.inviteCode ?? "")")!
    }

    private var isWindowActive: Bool { windowSecondsRemaining > 0 }

    private var countdownText: String {
        let mins = windowSecondsRemaining / 60
        let secs = windowSecondsRemaining % 60
        return String(format: "%02d:%02d remaining", mins, secs)
    }

    private var accentColor: Color {
        CircleColorDeriver.accent(for: circle.name)
    }

    var body: some View {
        ZStack {
            BreathingGradientBackground(circleName: circle.name)

            ScrollView {
                LazyVStack(spacing: 0) {

                    // Circle name — serif display title
                    Text(circle.name)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                        .accessibilityAddTraits(.isHeader)

                    // Celestial Noor Orb
                    CelestialNoorView(
                        intensity: detailVM.noorIntensity,
                        accentColor: accentColor
                    )
                    .padding(.top, 4)

                    // Moment banner (window open)
                    if isWindowActive {
                        momentBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    // Notifications denied note
                    if NotificationService.shared.permissionStatus == .denied {
                        notificationsDeniedNote
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    // Members section header + Pulse Bar
                    if !detailVM.members.isEmpty {
                        HStack {
                            Text("\(detailVM.members.count) Members")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.msTextMuted)
                            Spacer()
                            Button {
                                showMembersSheet = true
                            } label: {
                                Text("See All")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.msGold)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                        PulseBarView(
                            members: detailVM.members,
                            viewModel: detailVM,
                            currentUserId: auth.session?.user.id ?? UUID(),
                            circleId: circle.id,
                            onNudge: { targetId, nudgeType, message in
                                guard let senderId = auth.session?.user.id else { return }
                                Task {
                                    try? await NudgeService.shared.sendDirectNudge(
                                        circleId: circle.id,
                                        senderId: senderId,
                                        targetUserId: targetId,
                                        nudgeType: nudgeType,
                                        message: message
                                    )
                                }
                            }
                        )
                    }

                    // Daily Status Shelf
                    if let stats = detailVM.completionStats, !stats.habits.isEmpty {
                        DailyStatusShelfView(
                            stats: stats,
                            memberCount: detailVM.members.count
                        )
                        .padding(.top, 16)
                    }

                    // Tab Switcher
                    tabSwitcher
                        .padding(.top, 20)

                    Divider()
                        .background(Color.msBorder)
                        .padding(.top, 4)

                    // Tab Content
                    Group {
                        switch detailVM.activeTab {
                        case .huddle:
                            if let userId = auth.session?.user.id {
                                HuddleTimelineView(
                                    feedViewModel: feedViewModel,
                                    circleId: circle.id,
                                    currentUserId: userId
                                )
                                .padding(.top, 4)
                            }
                        case .gallery:
                            if let userId = auth.session?.user.id {
                                ZStack(alignment: .top) {
                                    MomentGalleryView(
                                        feedViewModel: feedViewModel,
                                        currentUserId: userId,
                                        hasPostedToday: DailyMomentService.shared.hasPostedToday
                                    )
                                    .padding(.top, 12)

                                    if DailyMomentService.shared.isGateActive {
                                        ReciprocityGateView(
                                            prayerName: DailyMomentService.shared.prayerDisplayName
                                        ) {
                                            draftMoment = nil
                                            showCamera = true
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .refreshable {
                guard let userId = auth.session?.user.id else { return }
                async let statsRefresh: () = detailVM.refreshStats()
                async let feedRefresh: () = feedViewModel.refresh(
                    circleIds: [circle.id],
                    currentUserId: userId,
                    singleCircleId: circle.id
                )
                _ = await (statsRefresh, feedRefresh)
                await reloadCircleFromServer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if isAmir {
                        Button {
                            showAmirSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(Color.msGold)
                        }
                    }
                    ShareLink(item: inviteURL) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.msGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showAmirSettings) {
            let bindableVM = Bindable(detailVM)
            AmirCircleSettingsView(
                circle: $circle,
                members: bindableVM.members,
                memberProfiles: bindableVM.memberProfiles
            )
        }
        .sheet(isPresented: $showMembersSheet) {
            MembersListView(
                members: detailVM.members,
                memberProfiles: detailVM.memberProfiles,
                currentUserId: auth.session?.user.id,
                senderId: auth.session?.user.id,
                circleId: circle.id
            )
        }
        .task {
            guard let userId = auth.session?.user.id else { return }
            await NotificationService.shared.refreshPermissionStatus()
            await DailyMomentService.shared.load(userId: userId)
            await detailVM.load(userId: userId)
            let allCircles = try? await CircleService.shared.fetchMyCircles(userId: userId)
            allUserCircleIds = (allCircles ?? [circle]).map { $0.id }
            startWindowTimer()
            await feedViewModel.loadInitial(
                circleIds: [circle.id],
                currentUserId: userId,
                singleCircleId: circle.id
            )
        }
        .onDisappear { windowTimer?.invalidate() }
        .fullScreenCover(isPresented: $showCamera) {
            MomentCameraView(circleId: circle.id) { _, primary, secondary in
                showCamera = false
                Task { @MainActor in
                    await Task.yield()
                    draftMoment = MomentDraft(primaryImage: primary, secondaryImage: secondary)
                }
            }
        }
        .sheet(item: $draftMoment) { draft in
            MomentPreviewView(
                primaryImage: draft.primaryImage,
                secondaryImage: draft.secondaryImage,
                onPost: { caption, swapped in
                    guard let userId = auth.session?.user.id else { return }
                    let postCircleIds = allUserCircleIds.isEmpty ? [circle.id] : allUserCircleIds
                    let windowStartStr: String? = DailyMomentService.shared.windowStart.map {
                        ISO8601DateFormatter().string(from: $0)
                    }
                    let result = try await MomentService.shared.postMomentToAllCircles(
                        primaryImage: swapped ? (draft.secondaryImage ?? draft.primaryImage) : draft.primaryImage,
                        secondaryImage: swapped ? draft.primaryImage : draft.secondaryImage,
                        circleIds: postCircleIds,
                        userId: userId,
                        caption: caption,
                        windowStart: windowStartStr
                    )
                    DailyMomentService.shared.markPostedToday()
                    await reloadCircleFromServer()
                    await feedViewModel.refresh(
                        circleIds: [circle.id],
                        currentUserId: userId,
                        singleCircleId: circle.id
                    )
                    if result.isPartialSuccess {
                        let failCount = result.failedCircleIds.count
                        let total = result.totalCount
                        throw NSError(domain: "MomentPost", code: 0, userInfo: [
                            NSLocalizedDescriptionKey: "Posted to \(result.succeeded.count) of \(total) circles. \(failCount) failed — tap Post again to retry."
                        ])
                    }
                },
                onRetake: {
                    draftMoment = nil
                    Task { @MainActor in
                        await Task.yield()
                        showCamera = true
                    }
                },
                circleCount: max(1, allUserCircleIds.count)
            )
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(CircleDetailViewModel.DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        detailVM.activeTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(
                                detailVM.activeTab == tab
                                    ? Color.msTextPrimary
                                    : Color.msTextMuted
                            )
                            .padding(.top, 4)

                        Rectangle()
                            .fill(detailVM.activeTab == tab ? Color.msGold : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(detailVM.activeTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Moment Banner

    private var momentBanner: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.msGold)
            Text("POST YOUR MOMENT")
                .font(.appCaptionMedium)
                .foregroundStyle(Color.msTextPrimary)
            Spacer()
            Text(countdownText)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.msTextMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.msGold.opacity(0.4), lineWidth: 1)
        )
        .onTapGesture { showCamera = true }
        .accessibilityLabel("Post your Moment, \(countdownText). Tap to open camera.")
    }

    // MARK: - Notifications Denied Note

    private var notificationsDeniedNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash.fill")
                .font(.appCaption)
                .foregroundStyle(Color.msGold.opacity(0.8))
            Text("Notifications off — turn on in Settings to get Moment alerts")
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
    }

    // MARK: - Helpers

    private func reloadCircleFromServer() async {
        do {
            circle = try await CircleService.shared.fetchCircle(id: circle.id)
        } catch {
            print("[CircleDetailView] reloadCircle failed: \(error)")
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
        guard let startDate else { return }
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
    let memberProfiles: [UUID: Profile]
    let currentUserId: UUID?
    let senderId: UUID?
    let circleId: UUID

    private func rowTitle(_ member: CircleMember) -> String {
        if let n = memberProfiles[member.userId]?.preferredName, !n.isEmpty { return n }
        return String(member.userId.uuidString.prefix(8)) + "…"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                List {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            AvatarView(
                                avatarUrl: memberProfiles[member.userId]?.avatarUrl,
                                name: rowTitle(member),
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rowTitle(member))
                                    .font(.appSubheadline)
                                    .foregroundStyle(Color.msTextPrimary)
                                if member.role == "admin" {
                                    Text("Amir")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.msGold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.msGold.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer(minLength: 8)
                            if member.userId != currentUserId {
                                HStack(spacing: 6) {
                                    Button {
                                        Task { await sendNudge(to: member.userId, nudgeType: "habit_reminder") }
                                    } label: {
                                        Text("Habit")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.msGold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.msGold.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowBackground(Color.msCardShared)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }

    private func sendNudge(to targetUserId: UUID, nudgeType: String) async {
        guard let senderId else { return }
        try? await NudgeService.shared.sendDirectNudge(
            circleId: circleId,
            senderId: senderId,
            targetUserId: targetUserId,
            nudgeType: nudgeType
        )
    }
}
