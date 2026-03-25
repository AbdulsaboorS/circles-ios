import SwiftUI
import Supabase

struct CommunityView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.pendingInviteCode) var pendingInviteCode
    @State private var viewModel = CirclesViewModel()
    @State private var selectedTab = 0
    @State private var publicCircles: [Circle] = []
    @State private var isLoadingPublicCircles = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        Text("My Circles").tag(0)
                        Text("Explore").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if selectedTab == 0 {
                        myCirclesContent
                    } else {
                        exploreContent
                    }
                }
            }
            .navigationTitle("Community")
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
                if let userId = auth.session?.user.id {
                    await viewModel.loadCircles(userId: userId)
                }
                await loadPublicCircles()
            }
            .onChange(of: selectedTab) { _, tab in
                if tab == 1 && publicCircles.isEmpty {
                    Task { await loadPublicCircles() }
                }
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

    // MARK: - My Circles (D-11)

    private var myCirclesContent: some View {
        Group {
            if viewModel.isLoading {
                Spacer()
                ProgressView().tint(Color.accent)
                Spacer()
            } else if viewModel.circles.isEmpty {
                myCirclesEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.circles) { circle in
                            NavigationLink(destination: CircleDetailView(circle: circle)) {
                                AppCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(circle.name)
                                                .font(.appSubheadline)
                                                .foregroundStyle(Color.textPrimary)
                                            if let desc = circle.description, !desc.isEmpty {
                                                Text(desc)
                                                    .font(.appCaption)
                                                    .foregroundStyle(Color.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.appCaption)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    .padding(14)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    if let userId = auth.session?.user.id {
                        await viewModel.loadCircles(userId: userId)
                    }
                }
            }
        }
    }

    private var myCirclesEmptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accent.opacity(0.7))
            VStack(spacing: 8) {
                Text("Your Circles")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)
                Text("Create or join a circle to get started")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                PrimaryButton(title: "Create a Circle") {
                    viewModel.showCreateSheet = true
                }
                Button {
                    viewModel.showJoinSheet = true
                } label: {
                    Text("Join with Code")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.accent, lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Public Explore (D-12)

    private var exploreContent: some View {
        Group {
            if isLoadingPublicCircles {
                Spacer()
                ProgressView().tint(Color.accent)
                Spacer()
            } else if publicCircles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No public circles yet")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.textSecondary)
                    Text("Create a circle and make it public to appear here.")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(Array(publicCircles.enumerated()), id: \.element.id) { index, circle in
                            NavigationLink(destination: CircleDetailView(circle: circle)) {
                                BubbleCircleCard(circle: circle, isOffset: index % 2 == 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Data

    private func loadPublicCircles() async {
        isLoadingPublicCircles = true
        publicCircles = (try? await CircleService.shared.fetchPublicCircles()) ?? []
        isLoadingPublicCircles = false
    }
}

// MARK: - BubbleCircleCard (D-12)

private struct BubbleCircleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let circle: Circle
    let isOffset: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if colorScheme == .dark {
                    SwiftUI.Circle()
                        .fill(.ultraThinMaterial)
                } else {
                    SwiftUI.Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                Text(String(circle.name.prefix(2)).uppercased())
                    .font(.appHeadline)
                    .foregroundStyle(Color.accent)
            }
            .frame(width: 80, height: 80)

            Text(circle.name)
                .font(.appCaptionMedium)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("Public")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .padding(.top, isOffset ? 24 : 0)
    }
}

#Preview {
    CommunityView()
        .environment(AuthManager())
}
