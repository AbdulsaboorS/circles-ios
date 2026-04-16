import SwiftUI
import PhotosUI
import Supabase

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth

    @State private var viewModel = ProfileViewModel()
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showSettingsSheet = false
    @State private var isEditingName = false
    @State private var editNameDraft: String = ""
    @State private var isSavingName = false
    @State private var heroIsVisible = true

    private var displayName: String {
        if let name = viewModel.profile?.preferredName, !name.isEmpty { return name }
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
                    VStack(spacing: 0) {
                        // Hero — scroll offset tracker pinned here
                        ProfileHeroSection(
                            viewModel: viewModel,
                            displayName: displayName,
                            memberSince: memberSince,
                            selectedPhoto: $selectedPhoto,
                            isEditingName: $isEditingName,
                            editNameDraft: $editNameDraft,
                            onSaveName: {
                                guard let userId = auth.session?.user.id else { return }
                                isSavingName = true
                                await viewModel.saveProfileName(editNameDraft, userId: userId)
                                isSavingName = false
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onChange(of: geo.frame(in: .named("profileScroll")).minY) { _, minY in
                                        // Hero considered visible until bottom of hero scrolls past nav bar area
                                        heroIsVisible = minY > -240
                                    }
                            }
                        )

                        VStack(spacing: 28) {
                            SpiritualPulseCard(
                                totalDays: viewModel.totalDays,
                                bestStreak: viewModel.bestStreak,
                                circleCount: viewModel.circleCount,
                                ameensGiven: viewModel.ameensGiven,
                                isLoading: viewModel.isLoadingStats
                            )

                            CommonIntentionsSection(topHabits: viewModel.topHabits)

                            SacredMilestonesSection(milestones: viewModel.milestones)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
                .coordinateSpace(name: "profileScroll")
                .ignoresSafeArea(.container, edges: .top)
            }
            .navigationTitle(heroIsVisible ? "" : displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                heroIsVisible ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial),
                for: .navigationBar
            )
            .toolbarBackground(heroIsVisible ? .hidden : .visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        ZStack {
                            SwiftUI.Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 34, height: 34)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.msGold)
                        }
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                settingsSheetContent
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item, let userId = auth.session?.user.id else { return }
                Task { await viewModel.handleAvatarPick(item, userId: userId) }
            }
            .alert("Upload Failed", isPresented: .constant(viewModel.avatarUploadError != nil)) {
                Button("OK") { viewModel.avatarUploadError = nil }
            } message: {
                Text(viewModel.avatarUploadError ?? "")
            }
        }
    }

    // MARK: - Settings Sheet Content

    private var settingsSheetContent: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                ScrollView {
                    settingsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $isEditingName) {
                editProfileSheet
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.msCardShared)
                VStack(spacing: 0) {
                    settingsRow(icon: "person.fill", label: "Edit Profile") {
                        editNameDraft = viewModel.profile?.preferredName ?? displayName
                        isEditingName = true
                    }

                    Divider().foregroundStyle(Color.msBorder).padding(.leading, 48)

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

    // MARK: - Edit Profile Sheet

    private var editProfileSheet: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Display Name")
                                .font(.appCaption)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(Color.msTextMuted)
                            TextField("Your name", text: $editNameDraft)
                                .textInputAutocapitalization(.words)
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(14)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                                .tint(Color.msGold)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.appCaption)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(Color.msTextMuted)
                            Text(auth.session?.user.email ?? "—")
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextMuted)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.msCardShared.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    Button {
                        Task {
                            guard let userId = auth.session?.user.id else { return }
                            isSavingName = true
                            await viewModel.saveProfileName(editNameDraft, userId: userId)
                            isSavingName = false
                            isEditingName = false
                        }
                    } label: {
                        Group {
                            if isSavingName {
                                ProgressView().tint(Color.msBackground)
                            } else {
                                Text("Save Changes")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(Color.msBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(editNameDraft.trimmingCharacters(in: .whitespaces).isEmpty || isSavingName)
                    .opacity(editNameDraft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isEditingName = false }
                        .foregroundStyle(Color.msGold)
                }
            }
        }
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

            Button {
                Task {
                    guard let userId = auth.session?.user.id else { return }
                    await DailyMomentService.shared.forceOpenWindow(userId: userId)
                }
            } label: {
                Text("Force Open Moment Window")
                    .font(.appCaption)
                    .foregroundStyle(Color.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}
