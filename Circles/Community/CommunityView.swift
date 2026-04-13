import SwiftUI
import Supabase

struct CommunityView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.pendingInviteCode) var pendingInviteCode
    @State private var viewModel = CirclesViewModel()
    @State private var feedViewModel = FeedViewModel()
    @State private var selectedPage = 0
    @State private var activeFilter: FeedFilter = .posts
    @State private var showGlobalCamera = false
    @State private var draftMoment: MomentDraft?
    @State private var pendingFeedRefresh = false
    @State private var expandedOwnMoment: MomentFeedItem? = nil
    @State private var momentStripId = UUID()
    private var momentService = DailyMomentService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    stickyHeader

                    TabView(selection: $selectedPage) {
                        globalFeedPage.tag(0)
                        circlesPage.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: selectedPage)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // Toolbar + removed — create/join now lives in the carousel's Empty Pedestal card
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadCircles(userId: userId)
                // Feed and gate load are independent — run concurrently
                async let feedLoad: Void = loadGlobalFeed()
                async let gateLoad: Void = DailyMomentService.shared.load(userId: userId)
                _ = await (feedLoad, gateLoad)
            }
            .onReceive(NotificationCenter.default.publisher(for: .habitCheckinBroadcast)) { _ in
                Task { await loadGlobalFeed() }
            }
            .fullScreenCover(isPresented: $showGlobalCamera) {
                if let circleId = viewModel.circles.first?.id {
                    MomentCameraView(circleId: circleId) { _, primary, secondary in
                        showGlobalCamera = false
                        Task { @MainActor in
                            await Task.yield()
                            draftMoment = MomentDraft(primaryImage: primary, secondaryImage: secondary)
                        }
                    }
                }
            }
            .fullScreenCover(item: $expandedOwnMoment) { moment in
                MomentFullScreenView(
                    item: moment,
                    currentUserId: auth.session?.user.id ?? UUID(),
                    profile: feedViewModel.authorProfiles[moment.userId],
                    viewModel: feedViewModel,
                    onCaptionSaved: { momentStripId = UUID() }
                )
            }
            .sheet(item: $draftMoment, onDismiss: {
                guard pendingFeedRefresh else { return }
                pendingFeedRefresh = false
                Task {
                    guard let userId = auth.session?.user.id else { return }
                    await feedViewModel.refresh(
                        circleIds: viewModel.circles.map { $0.id },
                        currentUserId: userId
                    )
                }
            }) { draft in
                MomentPreviewView(
                    primaryImage: draft.primaryImage,
                    secondaryImage: draft.secondaryImage,
                    onPost: { caption, swapped in
                        guard let userId = auth.session?.user.id else { return }
                        let circleIds = viewModel.circles.map { $0.id }
                        let result = try await MomentService.shared.postMomentToAllCircles(
                            primaryImage: swapped ? (draft.secondaryImage ?? draft.primaryImage) : draft.primaryImage,
                            secondaryImage: swapped ? draft.primaryImage : draft.secondaryImage,
                            circleIds: circleIds,
                            userId: userId,
                            caption: caption,
                            windowStart: viewModel.circles.first?.momentWindowStart
                        )
                        DailyMomentService.shared.markPostedToday()
                        pendingFeedRefresh = true
                        await viewModel.loadCircles(userId: userId)
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
                            showGlobalCamera = true
                        }
                    },
                    circleCount: viewModel.circles.count
                )
                .environment(auth)
            }
            .sheet(isPresented: $viewModel.showCreateSheet, onDismiss: {
                Task { await loadGlobalFeed() }
            }) {
                CreateCircleView(viewModel: viewModel).environment(auth)
            }
            .sheet(isPresented: $viewModel.showJoinSheet, onDismiss: {
                Task { await loadGlobalFeed() }
            }) {
                JoinCircleView(viewModel: viewModel).environment(auth)
            }
            .onChange(of: pendingInviteCode) { _, code in
                if let code {
                    viewModel.pendingCode = code
                    viewModel.showJoinSheet = true
                }
            }
            .sheet(isPresented: $viewModel.shouldShowPermissionPrompt) {
                NotificationPermissionModal(isPresented: $viewModel.shouldShowPermissionPrompt)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $viewModel.showLayoutEditor) {
                EditCirclesLayoutView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Sticky Double-Tier Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Circles")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Spacer()

                    if selectedPage == 1, !viewModel.circles.isEmpty {
                        Button {
                            viewModel.showLayoutEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.msGold)
                                .frame(width: 34, height: 34)
                                .background(Color.msBackgroundDeep.opacity(0.85), in: SwiftUI.Circle())
                                .overlay(
                                    SwiftUI.Circle()
                                        .stroke(Color.msGold.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button("Create a Circle") { viewModel.showCreateSheet = true }
                            Button("Join with Invite Code") { viewModel.showJoinSheet = true }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "1A2E1E"))
                                .frame(width: 34, height: 34)
                                .background(Color.msGold, in: SwiftUI.Circle())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
            .frame(height: 44)

            // Tier 1: Feed | Circles — full width
            HStack(spacing: 0) {
                tier1Button(title: "Feed", index: 0)
                tier1Button(title: "Circles", index: 1)
            }

            // Tier 2: Posts | Check-ins — centered, compact
            if selectedPage == 0 {
                HStack(spacing: 24) {
                    tier2Button(title: "Posts", filter: .posts)
                    tier2Button(title: "Check-ins", filter: .checkins)
                }
                .frame(height: 32)
            }

            // Bottom divider
            Rectangle()
                .fill(Color.msGold.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    private func tier1Button(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { selectedPage = index }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: selectedPage == index ? .semibold : .regular, design: .serif))
                .foregroundStyle(selectedPage == index ? Color.msTextPrimary : Color.msTextMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
    }

    private func tier2Button(title: String, filter: FeedFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { activeFilter = filter }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: activeFilter == filter ? .semibold : .regular, design: .serif))
                .foregroundStyle(activeFilter == filter ? Color.msTextPrimary : Color.msTextMuted)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Global Feed Page

    private var globalFeedPage: some View {
        Group {
            if feedViewModel.isLoadingInitial && feedViewModel.items.isEmpty {
                // Only show full-screen spinner on the very first load
                VStack {
                    Spacer()
                    ProgressView().tint(Color.msGold)
                    Spacer()
                }
            } else if viewModel.circles.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.msGold.opacity(0.6))
                    Text("No activity yet")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                    Text("Join or create a circle to see your feed.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 32)
            } else {
                ZStack {
                    ScrollView {
                        if let userId = auth.session?.user.id {
                            VStack(spacing: 0) {
                                // Pinned own-moment card (shown only if user posted today)
                                if momentService.hasPostedToday,
                                   let moment = ownMomentItem(for: userId) {
                                    ownMomentStrip(moment)
                                        .id(momentStripId)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 8)
                                        .padding(.bottom, 4)
                                        .contentShape(Rectangle())
                                        .onTapGesture { expandedOwnMoment = moment }
                                }

                                FeedView(
                                    circleIds: viewModel.circles.map { $0.id },
                                    currentUserId: userId,
                                    viewModel: feedViewModel,
                                    activeFilter: $activeFilter,
                                    excludeUserId: userId
                                )
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                    .refreshable { await loadGlobalFeed() }

                    if momentService.isGateActive {
                        ReciprocityGateView(prayerName: momentService.prayerDisplayName) {
                            draftMoment = nil
                            showGlobalCamera = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Circles Page

    private var circlesPage: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView().tint(Color.msGold)
                    Spacer()
                }
            } else if viewModel.circles.isEmpty {
                MyCirclesEmptyView(
                    onCreateCircle: { viewModel.showCreateSheet = true },
                    onJoinCircle:   { viewModel.showJoinSheet = true }
                )
            } else {
                MyCirclesView(
                    circles: viewModel.circles,
                    cardDataMap: viewModel.cardDataMap,
                    pinnedCircleIDs: viewModel.pinnedCircleIDs,
                    sendingNudgeCircleIDs: viewModel.sendingNudgeCircleIDs,
                    onNudge: { circleId in
                        guard let userId = auth.session?.user.id else { return }
                        Task { await viewModel.sendNudge(circleId: circleId, userId: userId) }
                    }
                )
            }
        }
    }

    // MARK: - Pinned Own-Moment Card

    private func ownMomentItem(for userId: UUID) -> MomentFeedItem? {
        for item in feedViewModel.items {
            if case .moment(let m) = item, m.userId == userId { return m }
        }
        return nil
    }

    private func ownMomentStrip(_ moment: MomentFeedItem) -> some View {
        VStack(spacing: 10) {
            // BeReal-style composited preview: main photo with PiP overlay
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: moment.photoUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(hex: "243828")
                        .overlay(ProgressView().tint(Color.msGold))
                }
                .frame(width: 160, height: 213)
                .clipped()

                if let secondaryUrl = moment.secondaryPhotoUrl {
                    CachedAsyncImage(url: secondaryUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: "243828")
                    }
                    .frame(width: 52, height: 69)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.msGold, lineWidth: 1.5)
                    )
                    .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.msGold.opacity(0.4), lineWidth: 1)
            )

            // Caption prompt
            if let caption = moment.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.msTextPrimary)
                    .lineLimit(1)
            } else {
                Text("Add a caption...")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.msTextMuted)
            }

            // Shared pill
            Text("Shared with \(moment.circleIds.count) Circle\(moment.circleIds.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "1A2E1E"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.msGold, in: Capsule())
        }
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func loadGlobalFeed() async {
        guard let userId = auth.session?.user.id, !viewModel.circles.isEmpty else { return }
        await feedViewModel.loadInitial(circleIds: viewModel.circles.map { $0.id }, currentUserId: userId)
    }
}

#Preview {
    CommunityView().environment(AuthManager())
}
