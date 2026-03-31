import SwiftUI
import PhotosUI
import Supabase

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
    static let msBorder      = Color(hex: "D4A240").opacity(0.18)
}

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth

    @State private var profile: Profile? = nil
    @State private var totalDays: Int = 0
    @State private var bestStreak: Int = 0
    @State private var circleCount: Int = 0
    @State private var isLoadingStats = true

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isUploadingAvatar = false
    @State private var avatarUrl: String? = nil

    private var displayName: String {
        if let name = profile?.preferredName, !name.isEmpty { return name }
        return auth.session?.user.email?.components(separatedBy: "@").first ?? "Member"
    }

    private var memberSince: String {
        guard let date = auth.session?.user.createdAt else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return "Member since \(f.string(from: date))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        avatarSection
                        statsCard
                        settingsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await loadAll()
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await handleAvatarPick(item) }
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    AvatarView(avatarUrl: avatarUrl, name: displayName, size: 96)
                        .overlay(
                            SwiftUI.Circle()
                                .stroke(Color.msGold.opacity(0.35), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold)
                            .frame(width: 28, height: 28)
                        if isUploadingAvatar {
                            ProgressView().tint(Color.msBackground).scaleEffect(0.6)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.msBackground)
                        }
                    }
                    .offset(x: 2, y: 2)
                }
            }

            Text(displayName)
                .font(.appTitle)
                .foregroundStyle(Color.msTextPrimary)

            if !memberSince.isEmpty {
                Text(memberSince)
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.msCardShared)
            HStack(spacing: 0) {
                statItem(value: "\(totalDays)", label: "Total Days", icon: "flame.fill")
                Divider().frame(height: 40).foregroundStyle(Color.msBorder)
                statItem(value: "\(bestStreak)", label: "Best Streak", icon: "bolt.fill")
                Divider().frame(height: 40).foregroundStyle(Color.msBorder)
                statItem(value: "\(circleCount)", label: "Circles", icon: "person.2.fill")
            }
            .padding(.vertical, 16)
        }
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))
        .overlay(
            isLoadingStats
                ? AnyView(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.msBackground.opacity(0.6))
                        .overlay(ProgressView().tint(Color.msGold))
                )
                : AnyView(EmptyView())
        )
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.msGold)
            Text(value)
                .font(.appHeadline)
                .foregroundStyle(Color.msTextPrimary)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.msCardShared)
                VStack(spacing: 0) {
                    settingsRow(icon: "bell.fill", label: "Notifications") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                    Divider().foregroundStyle(Color.msBorder).padding(.leading, 48)

                    settingsRow(icon: "location.fill", label: "Location & Prayer Times") {}
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))

            Button {
                Task { await auth.signOut() }
            } label: {
                HStack {
                    Image(systemName: "arrow.right.square")
                    Text("Sign Out")
                }
                .font(.appSubheadline)
                .foregroundStyle(Color.msGold)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.msGold, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            #if DEBUG
            debugTools
            #endif
        }
    }

    private func settingsRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.msGold.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.msGold)
                }
                Text(label)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debug Tools

    @ViewBuilder
    private var debugTools: some View {
        VStack(spacing: 8) {
            Text("DEV TOOLS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.msTextMuted.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if let userId = auth.session?.user.id {
                    UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(userId.uuidString)")
                }
                Task { await auth.signOut() }
            } label: {
                Text("Reset Account")
                    .font(.appCaption)
                    .foregroundStyle(Color.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                NotificationService.shared.incrementUnread()
            } label: {
                Text("Test Badge +1")
                    .font(.appCaption)
                    .foregroundStyle(Color.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data Loading

    private func loadAll() async {
        guard let userId = auth.session?.user.id else { return }
        isLoadingStats = true
        async let profileFetch = AvatarService.shared.fetchProfile(userId: userId)
        async let daysFetch = AvatarService.shared.fetchTotalCompletedDays(userId: userId)
        async let streakFetch = HabitService.shared.fetchStreak(userId: userId)
        async let circlesFetch = AvatarService.shared.fetchCircleCount(userId: userId)

        profile = try? await profileFetch
        avatarUrl = profile?.avatarUrl
        totalDays = (try? await daysFetch) ?? 0
        bestStreak = (try? await streakFetch)?.longestStreak ?? 0
        circleCount = (try? await circlesFetch) ?? 0
        isLoadingStats = false
    }

    private func handleAvatarPick(_ item: PhotosPickerItem) async {
        guard let userId = auth.session?.user.id else { return }
        isUploadingAvatar = true
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                avatarUrl = try await AvatarService.shared.uploadAvatar(userId: userId, image: image)
            }
        } catch {
            print("[ProfileView] Avatar upload failed: \(error)")
        }
        isUploadingAvatar = false
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}
