import SwiftUI
import Supabase

struct CircleDetailView: View {
    let circle: Circle

    @State private var feedViewModel = FeedViewModel()
    @State private var members: [CircleMember] = []
    @State private var memberProfiles: [UUID: Profile] = [:]
    @State private var checkedInCount = 0
    @State private var isLoadingMembers = true
    @State private var showMembersSheet = false
    @State private var windowSecondsRemaining: Int = 0
    @State private var windowTimer: Timer?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showPreview = false

    @Environment(AuthManager.self) private var auth

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
            AppBackground()

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
                            HStack { Spacer(); ProgressView().tint(Color.accent); Spacer() }
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
                    await feedViewModel.refresh(circleIds: [circle.id], currentUserId: userId, singleCircleId: circle.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: inviteURL) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .task {
            guard let userId = auth.session?.user.id else { return }
            await NotificationService.shared.refreshPermissionStatus()
            async let membersFetch = CircleService.shared.fetchMembers(circleId: circle.id)
            members = (try? await membersFetch) ?? []
            checkedInCount = 0
            isLoadingMembers = false
            // Load profiles for avatar display
            let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: members.map { $0.userId })) ?? []
            memberProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            startWindowTimer()
            await feedViewModel.loadInitial(circleIds: [circle.id], currentUserId: userId, singleCircleId: circle.id)
        }
        .onDisappear { windowTimer?.invalidate() }
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
                        DailyMomentService.shared.markPostedToday()
                        await feedViewModel.refresh(circleIds: [circle.id], currentUserId: userId, singleCircleId: circle.id)
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

    // MARK: - Members Strip (D-16)

    private var membersStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(members.count) Members")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button { showMembersSheet = true } label: {
                    Text("See All")
                        .font(.appCaption)
                        .foregroundStyle(Color.accent)
                }
                .sheet(isPresented: $showMembersSheet) {
                    MembersListView(
                        members: members,
                        currentUserId: auth.session?.user.id,
                        senderId: auth.session?.user.id,
                        circleId: circle.id
                    )
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(members) { member in
                        MemberAvatarChip(
                            member: member,
                            avatarUrl: memberProfiles[member.userId]?.avatarUrl,
                            displayName: memberProfiles[member.userId]?.preferredName ?? ""
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Moment Banner (D-17)

    private var momentBanner: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
            Text("POST YOUR MOMENT")
                .font(.appCaptionMedium)
                .foregroundStyle(.white)
            Spacer()
            Text(countdownText)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.accent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { showCamera = true }
        .accessibilityLabel("Post your Moment, \(countdownText). Tap to open camera.")
    }

    // MARK: - Notifications Denied Note

    private var notificationsDeniedNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash.fill")
                .font(.appCaption)
                .foregroundStyle(Color.accent.opacity(0.8))
            Text("Notifications off — turn on in Settings to get Moment alerts")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
    /// Populated by CircleDetailView after fetching profiles
    var avatarUrl: String? = nil
    var displayName: String = ""

    var body: some View {
        VStack(spacing: 4) {
            AvatarView(avatarUrl: avatarUrl, name: displayName.isEmpty ? member.userId.uuidString : displayName, size: 44)
                .shadow(color: .black.opacity(0.06), radius: 3)

            if member.role == "admin" {
                Text("Amir")
                    .font(Font.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.accent)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.darkBackground : Color.lightBackground)
                .ignoresSafeArea()
            List(members) { member in
                HStack {
                    Text(member.userId.uuidString.prefix(8))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if member.role == "admin" {
                        Text("Admin")
                            .font(.appCaption)
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if member.userId != currentUserId {
                        HStack(spacing: 6) {
                            Button {
                                Task { await sendNudge(to: member.userId, type: "moment", circleId: circleId) }
                            } label: {
                                Text("Moment")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.accent.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Button {
                                Task { await sendNudge(to: member.userId, type: "habit", circleId: circleId) }
                            } label: {
                                Text("Habit")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.accent.opacity(0.15))
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
