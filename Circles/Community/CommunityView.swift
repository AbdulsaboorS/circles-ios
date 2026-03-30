import SwiftUI
import Supabase

struct CommunityView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.pendingInviteCode) var pendingInviteCode
    @State private var viewModel = CirclesViewModel()
    @State private var feedViewModel = FeedViewModel()
    @State private var selectedPage = 0
    @State private var showGlobalCamera = false
    @State private var globalCapturedImage: UIImage? = nil
    @State private var showGlobalPreview = false
    private var momentService = DailyMomentService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    // Feed | Circles segmented control
                    pageSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Swipeable pages
                    TabView(selection: $selectedPage) {
                        globalFeedPage
                            .tag(0)
                        circlesPage
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: selectedPage)
                }
            }
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.inline)
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
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadCircles(userId: userId)
                await loadGlobalFeed()
                await DailyMomentService.shared.load(userId: userId)
            }
            .fullScreenCover(isPresented: $showGlobalCamera) {
                if let circleId = viewModel.circles.first?.id {
                    MomentCameraView(circleId: circleId) { image in
                        globalCapturedImage = image
                        showGlobalCamera = false
                        showGlobalPreview = true
                    }
                }
            }
            .sheet(isPresented: $showGlobalPreview) {
                if let image = globalCapturedImage,
                   let circleId = viewModel.circles.first?.id {
                    MomentPreviewView(
                        image: image,
                        onPost: { caption in
                            guard let userId = auth.session?.user.id else { return }
                            _ = try await MomentService.shared.postMoment(
                                image: image,
                                circleId: circleId,
                                userId: userId,
                                caption: caption,
                                windowStart: viewModel.circles.first?.momentWindowStart
                            )
                            DailyMomentService.shared.markPostedToday()
                            await loadGlobalFeed()
                            await viewModel.loadCircles(userId: userId)
                        },
                        onRetake: {
                            showGlobalPreview = false
                            globalCapturedImage = nil
                            showGlobalCamera = true
                        }
                    )
                    .environment(auth)
                }
            }
            .onChange(of: viewModel.circles) { _, circles in
                // Reload global feed when circles change (joined/created a new one)
                Task { await loadGlobalFeed() }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateCircleView(viewModel: viewModel)
                    .environment(auth)
            }
            .sheet(isPresented: $viewModel.showJoinSheet) {
                JoinCircleView(viewModel: viewModel)
                    .environment(auth)
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
        .background(Color.accent.opacity(0.08), in: Capsule())
        .padding(3)
        .background(Color.black.opacity(0.04), in: Capsule())
    }

    private func pageTab(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedPage = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selectedPage == index ? .semibold : .regular))
                .foregroundStyle(selectedPage == index ? Color.white : Color(hex: "6B5B45"))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    selectedPage == index
                        ? Color.accent
                        : Color.clear,
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
                    ProgressView().tint(Color.accent)
                    Spacer()
                }
            } else if viewModel.circles.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accent.opacity(0.6))
                    Text("No activity yet")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(hex: "1A1209"))
                    Text("Join or create a circle to see your feed.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color(hex: "6B5B45"))
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
                                viewModel: feedViewModel
                            )
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                    }
                    .refreshable {
                        await loadGlobalFeed()
                    }

                    if momentService.isGateActive {
                        ReciprocityGateView(prayerName: momentService.prayerDisplayName) {
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
                    ProgressView().tint(Color.accent)
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
        guard let userId = auth.session?.user.id,
              !viewModel.circles.isEmpty else { return }
        let ids = viewModel.circles.map { $0.id }
        await feedViewModel.loadInitial(circleIds: ids, currentUserId: userId)
    }
}

#Preview {
    CommunityView()
        .environment(AuthManager())
}
