import SwiftUI
import Supabase

struct CommunityView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.pendingInviteCode) var pendingInviteCode
    @State private var viewModel = CirclesViewModel()
    @State private var feedViewModel = FeedViewModel()
    @State private var selectedPage = 0
    @State private var showGlobalCamera = false
    @State private var draftMoment: MomentDraft?
    @State private var pendingFeedRefresh = false  // set true by onPost, consumed by onDismiss
    private var momentService = DailyMomentService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    pageSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    TabView(selection: $selectedPage) {
                        globalFeedPage.tag(0)
                        circlesPage.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: selectedPage)
                }
            }
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
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
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadCircles(userId: userId)
                await loadGlobalFeed()
                await DailyMomentService.shared.load(userId: userId)
            }
            .onAppear {
                Task {
                    guard let userId = auth.session?.user.id else { return }
                    await viewModel.loadCircles(userId: userId)
                    await loadGlobalFeed()
                }
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
            .onChange(of: viewModel.circles) { _, _ in
                Task { await loadGlobalFeed() }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateCircleView(viewModel: viewModel).environment(auth)
            }
            .sheet(isPresented: $viewModel.showJoinSheet) {
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

    // MARK: - Page Selector

    private var pageSelector: some View {
        HStack(spacing: 0) {
            pageTab(title: "Feed", index: 0)
            pageTab(title: "Circles", index: 1)
        }
        .background(Color.msCardShared, in: Capsule())
        .overlay(Capsule().stroke(Color.msBorder, lineWidth: 1))
    }

    private func pageTab(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { selectedPage = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selectedPage == index ? .semibold : .regular))
                .foregroundStyle(selectedPage == index ? Color.msBackground : Color.msTextMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    selectedPage == index ? Color.msGold : Color.clear,
                    in: Capsule()
                )
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
                            FeedView(
                                circleIds: viewModel.circles.map { $0.id },
                                currentUserId: userId,
                                viewModel: feedViewModel,
                                showFilterTabs: true
                            )
                            .padding(.top, 8)
                            .padding(.bottom, 24)
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

    // MARK: - Helpers

    private func loadGlobalFeed() async {
        guard let userId = auth.session?.user.id, !viewModel.circles.isEmpty else { return }
        await feedViewModel.loadInitial(circleIds: viewModel.circles.map { $0.id }, currentUserId: userId)
    }
}

#Preview {
    CommunityView().environment(AuthManager())
}
