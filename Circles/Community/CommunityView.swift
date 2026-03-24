import SwiftUI
import Supabase

struct CommunityView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.pendingInviteCode) var pendingInviteCode
    @State private var viewModel = CirclesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color(hex: "E8834B"))
                    } else if viewModel.circles.isEmpty {
                        emptyState
                    } else {
                        circlesList
                    }
                }
            }
            .navigationTitle("My Circles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
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
                            .foregroundStyle(Color(hex: "E8834B"))
                    }
                }
            }
            .task {
                if let userId = auth.session?.user.id {
                    await viewModel.loadCircles(userId: userId)
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

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "E8834B").opacity(0.7))
            VStack(spacing: 8) {
                Text("Your Circles")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Create or join a circle to get started")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Text("Create a Circle")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "E8834B"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    viewModel.showJoinSheet = true
                } label: {
                    Text("Join with Code")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "E8834B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E8834B"), lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var circlesList: some View {
        List(viewModel.circles) { circle in
            NavigationLink(destination: CircleDetailView(circle: circle)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(circle.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let desc = circle.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color(hex: "0D1021"))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            if let userId = auth.session?.user.id {
                await viewModel.loadCircles(userId: userId)
            }
        }
    }
}

#Preview {
    CommunityView()
        .environment(AuthManager())
}
