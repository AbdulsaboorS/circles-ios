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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showCreateSheet = true
                        } label: {
                            Label("Create Circle", systemImage: "plus.circle")
                        }
                        Button {
                            viewModel.showJoinSheet = true
                        } label: {
                            Label("Join Circle", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.msGold)
                    }
                }
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadCircles(userId: userId)
                await loadGlobalFeed()
                await DailyMomentService.shared.load(userId: userId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .habitCheckinBroadcast)) { _ in
                Task { await loadGlobalFeed() }
            }
            .fullScreenCover(isPresented: $showGlobalCamera) {
                if let circleId = viewModel.circles.first?.id {
                    MomentCameraView(circleId: circleId) { image in
                        showGlobalCamera = false
                        Task { @MainActor in
                            await Task.yield()
                            draftMoment = MomentDraft(image: image)
                        }
                    }
                }
            }
            .fullScreenCover(item: $expandedOwnMoment) { moment in
                OwnMomentFullView(item: moment, profile: feedViewModel.authorProfiles[moment.userId])
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
                    image: draft.image,
                    onPost: { caption in
                        guard let userId = auth.session?.user.id else { return }
                        let circleIds = viewModel.circles.map { $0.id }
                        let result = try await MomentService.shared.postMomentToAllCircles(
                            image: draft.image,
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
        }
    }

    // MARK: - Sticky Double-Tier Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // Tier 1: Feed | Circles
            HStack(spacing: 0) {
                tier1Button(title: "Feed", index: 0)
                tier1Button(title: "Circles", index: 1)
            }
            .background(.ultraThinMaterial)

            // Tier 2: Posts | Check-ins (only on Feed tab)
            if selectedPage == 0 {
                HStack(spacing: 0) {
                    tier2Button(title: "Posts", filter: .posts)
                    tier2Button(title: "Check-ins", filter: .checkins)
                }
                .padding(.horizontal, 20)
                .background(.ultraThinMaterial)
            }

            // Bottom divider
            Rectangle()
                .fill(Color.msBorder.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    private func tier1Button(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { selectedPage = index }
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 15, weight: selectedPage == index ? .semibold : .regular))
                    .foregroundStyle(selectedPage == index ? Color.msTextPrimary : Color.msTextMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                Rectangle()
                    .fill(selectedPage == index ? Color.msGold : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func tier2Button(title: String, filter: FeedFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { activeFilter = filter }
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: activeFilter == filter ? .semibold : .regular))
                    .foregroundStyle(activeFilter == filter ? Color.msTextPrimary : Color.msTextMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                Rectangle()
                    .fill(activeFilter == filter ? Color.msGold : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Global Feed Page

    private var globalFeedPage: some View {
        Group {
            if feedViewModel.isLoadingInitial {
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
                                    ownMomentCard(moment)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .padding(.bottom, 4)
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
                    onCreateCircle: { viewModel.showCreateSheet = true },
                    onJoinCircle:   { viewModel.showJoinSheet = true }
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

    private func ownMomentCard(_ moment: MomentFeedItem) -> some View {
        ZStack(alignment: .topTrailing) {
            CachedAsyncImage(url: moment.photoUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(hex: "243828").overlay(ProgressView().tint(Color(hex: "D4A240")))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()

            // Gold "Shared with X Circle(s)" pill
            Text("Shared with \(moment.circleIds.count) Circle\(moment.circleIds.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "1A2E1E"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "D4A240"), in: Capsule())
                .padding(10)
        }
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.msGold, lineWidth: 1.5)
        )
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
