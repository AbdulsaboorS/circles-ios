import SwiftUI
import Supabase

struct CircleDetailView: View {
    @State private var circle: Circle

    @State private var feedViewModel = FeedViewModel()
    @State private var members: [CircleMember] = []
    @State private var memberProfiles: [UUID: Profile] = [:]
    @State private var checkedInCount = 0
    @State private var isLoadingMembers = true
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
    }

    private var isAmir: Bool {
        guard let uid = auth.session?.user.id else { return false }
        return members.contains { $0.userId == uid && $0.role == "admin" }
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

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {

                        membersStrip
                            .padding(.top, 12)

                        if isWindowActive {
                            momentBanner
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        if NotificationService.shared.permissionStatus == .denied {
                            notificationsDeniedNote
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        SectionHeader(title: "Activity")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        if feedViewModel.isLoadingInitial {
                            HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
                                .padding(.vertical, 24)
                        }

                        if let userId = auth.session?.user.id {
                            ZStack {
                                FeedView(
                                    circleIds: [circle.id],
                                    currentUserId: userId,
                                    viewModel: feedViewModel
                                )
                                if DailyMomentService.shared.isGateActive {
                                    ReciprocityGateView(
                                        prayerName: DailyMomentService.shared.prayerDisplayName
                                    ) {
                                        draftMoment = nil
                                        showCamera = true
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    guard let userId = auth.session?.user.id else { return }
                    await reloadCircleFromServer()
                    await feedViewModel.refresh(circleIds: [circle.id], currentUserId: userId, singleCircleId: circle.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(circle.name)
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
            AmirCircleSettingsView(
                circle: $circle,
                members: $members,
                memberProfiles: $memberProfiles
            )
        }
        .task {
            guard let userId = auth.session?.user.id else { return }
            await NotificationService.shared.refreshPermissionStatus()
            await DailyMomentService.shared.load(userId: userId)
            async let membersFetch = CircleService.shared.fetchMembers(circleId: circle.id)
            members = (try? await membersFetch) ?? []
            checkedInCount = 0
            isLoadingMembers = false
            let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: members.map { $0.userId })) ?? []
            memberProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            let allCircles = try? await CircleService.shared.fetchMyCircles(userId: userId)
            allUserCircleIds = (allCircles ?? [circle]).map { $0.id }
            startWindowTimer()
            await feedViewModel.loadInitial(circleIds: [circle.id], currentUserId: userId, singleCircleId: circle.id)
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
                    await feedViewModel.refresh(circleIds: [circle.id], currentUserId: userId, singleCircleId: circle.id)
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

    // MARK: - Members Strip

    private var membersStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(members.count) Members")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.msTextMuted)
                Spacer()
                Button { showMembersSheet = true } label: {
                    Text("See All")
                        .font(.appCaption)
                        .foregroundStyle(Color.msGold)
                }
                .sheet(isPresented: $showMembersSheet) {
                    MembersListView(
                        members: members,
                        memberProfiles: memberProfiles,
                        currentUserId: auth.session?.user.id,
                        senderId: auth.session?.user.id,
                        circleId: circle.id
                    )
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let maxStrip = 14
                    let stripMembers = Array(members.prefix(maxStrip))
                    ForEach(stripMembers) { member in
                        MemberAvatarChip(
                            member: member,
                            avatarUrl: memberProfiles[member.userId]?.avatarUrl,
                            displayName: memberProfiles[member.userId]?.preferredName ?? ""
                        )
                    }
                    if members.count > maxStrip {
                        Text("+\(members.count - maxStrip)")
                            .font(.appCaptionMedium)
                            .foregroundStyle(Color.msTextMuted)
                            .frame(width: 44, height: 44)
                            .background(Color.msGold.opacity(0.12), in: SwiftUI.Circle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Moment Banner

    private var momentBanner: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.msBackground)
            Text("POST YOUR MOMENT")
                .font(.appCaptionMedium)
                .foregroundStyle(Color.msBackground)
            Spacer()
            Text(countdownText)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.msBackground)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.msGold)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
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

// MARK: - MemberAvatarChip

private struct MemberAvatarChip: View {
    let member: CircleMember
    var avatarUrl: String? = nil
    var displayName: String = ""

    var body: some View {
        VStack(spacing: 4) {
            AvatarView(avatarUrl: avatarUrl, name: displayName.isEmpty ? member.userId.uuidString : displayName, size: 44)
                .shadow(color: .black.opacity(0.06), radius: 3)

            if member.role == "admin" {
                Text("Amir")
                    .font(Font.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.msGold)
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
                                        Task { await sendNudge(to: member.userId, type: "moment", circleId: circleId) }
                                    } label: {
                                        Text("Moment")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.msGold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.msGold.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        Task { await sendNudge(to: member.userId, type: "habit", circleId: circleId) }
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
