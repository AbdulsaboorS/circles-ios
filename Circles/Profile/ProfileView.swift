import SwiftUI
import PhotosUI
import Supabase

@MainActor
struct ProfileView: View {
    @Environment(AuthManager.self) private var auth

    @State private var viewModel = ProfileViewModel()
    @State private var showSettingsSheet = false
    @State private var heroIsVisible = true

    private var displayName: String {
        if let name = viewModel.profile?.preferredName, !name.isEmpty {
            return name
        }
        return auth.session?.user.email?.components(separatedBy: "@").first ?? "Member"
    }

    private var memberSince: String {
        guard let date = auth.session?.user.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Member since \(formatter.string(from: date))"
    }

    private var joinedDateFooter: String {
        guard let date = auth.session?.user.createdAt else { return "You joined Circles recently" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "You joined Circles in \(formatter.string(from: date))"
    }

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.52, 420), 560)
            let collapseThreshold = heroHeight - 80

            NavigationStack {
                ZStack {
                    Color.msBackground.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                            ProfileHeroSection(
                                viewModel: viewModel,
                                displayName: displayName,
                                memberSince: memberSince,
                                heroHeight: heroHeight
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onChange(of: geo.frame(in: .named("profileScroll")).minY) { _, minY in
                                            heroIsVisible = minY > -collapseThreshold
                                        }
                                }
                            )

                            VStack(spacing: 28) {
                                SpiritualPulseCard(
                                    totalDays: viewModel.totalDays,
                                    bestStreak: viewModel.bestStreak,
                                    circleCount: viewModel.circleCount,
                                    nudgesSent: viewModel.nudgesSent,
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
                    if let userId = auth.session?.user.id {
                        ProfileSettingsSheet(
                            viewModel: viewModel,
                            userId: userId,
                            fallbackDisplayName: displayName,
                            email: auth.session?.user.email ?? "—",
                            joinedDateFooter: joinedDateFooter
                        )
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                }
                .task {
                    guard let userId = auth.session?.user.id else { return }
                    await viewModel.loadAll(userId: userId)
                }
                .alert("Upload Failed", isPresented: .constant(viewModel.avatarUploadError != nil)) {
                    Button("OK") { viewModel.avatarUploadError = nil }
                } message: {
                    Text(viewModel.avatarUploadError ?? "")
                }
            }
        }
    }
}

@MainActor
private struct ProfileSettingsSheet: View {
    @Environment(AuthManager.self) private var auth

    let viewModel: ProfileViewModel
    let userId: UUID
    let fallbackDisplayName: String
    let email: String
    let joinedDateFooter: String

    @State private var draft: ProfileEditDraft

    init(
        viewModel: ProfileViewModel,
        userId: UUID,
        fallbackDisplayName: String,
        email: String,
        joinedDateFooter: String
    ) {
        self.viewModel = viewModel
        self.userId = userId
        self.fallbackDisplayName = fallbackDisplayName
        self.email = email
        self.joinedDateFooter = joinedDateFooter
        _draft = State(initialValue: viewModel.makeEditDraft(fallbackName: fallbackDisplayName))
    }

    private enum Route: Hashable {
        case editProfile
        case location
    }

    private var identitySummary: String {
        let genderText = genderLabel(for: draft.gender) ?? "Gender not set"
        let cityText = draft.cityName.isEmpty ? "Prayer city not set" : draft.cityName
        return "\(genderText) • \(cityText)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        NavigationLink(value: Route.editProfile) {
                            ProfileAccountCard(
                                name: draft.preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackDisplayName : draft.preferredName,
                                email: email,
                                summary: identitySummary,
                                avatarUrl: draft.avatarUrl,
                                isUploadingAvatar: viewModel.isUploadingAvatar
                            )
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 0) {
                            settingsRow(icon: "bell.fill", label: "Notifications") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }

                            Divider()
                                .foregroundStyle(Color.msBorder)
                                .padding(.leading, 52)

                            NavigationLink(value: Route.location) {
                                SettingsRowLabel(
                                    icon: "location.fill",
                                    label: "Location & Prayer Times",
                                    detail: draft.cityName.isEmpty ? "Choose your prayer city" : draft.cityName
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.msBorder, lineWidth: 1)
                        )

                        VStack(spacing: 12) {
                            Button {
                                Task { await auth.signOut() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.right.square")
                                    Text("Log Out")
                                }
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msGold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.msGold, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(joinedDateFooter)
                                .font(.appCaption)
                                .foregroundStyle(Color.msTextMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        #if DEBUG
                        debugTools
                        #endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .editProfile:
                    EditProfileView(
                        viewModel: viewModel,
                        userId: userId,
                        email: email,
                        draft: $draft,
                        fallbackDisplayName: fallbackDisplayName
                    )
                case .location:
                    ProfileLocationPickerView(draft: $draft)
                }
            }
            .alert("Profile Save Failed", isPresented: .constant(viewModel.saveError != nil)) {
                Button("OK") { viewModel.saveError = nil }
            } message: {
                Text(viewModel.saveError ?? "")
            }
        }
    }

    private func settingsRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRowLabel(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var debugTools: some View {
        VStack(spacing: 8) {
            Text("DEV TOOLS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.msTextMuted.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(userId.uuidString)")
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

@MainActor
private struct ProfileAccountCard: View {
    let name: String
    let email: String
    let summary: String
    let avatarUrl: String?
    let isUploadingAvatar: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.msCardShared, Color.msBackgroundDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            IslamicGeometricPattern(opacity: 0.03, tileSize: 42, color: Color.msGold)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(avatarUrl: avatarUrl, name: name, size: 64)
                        .overlay(
                            SwiftUI.Circle()
                                .stroke(Color.msGold.opacity(0.3), lineWidth: 1)
                        )

                    if isUploadingAvatar {
                        ZStack {
                            SwiftUI.Circle()
                                .fill(Color.msBackground)
                                .frame(width: 22, height: 22)
                            ProgressView()
                                .scaleEffect(0.55)
                                .tint(Color.msGold)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)

                    Text(email)
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)

                    Text(summary)
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.msGold.opacity(0.95))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }
            .padding(18)

            Text("Profile")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.msBackground)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.msGold, in: Capsule())
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 138)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.msBorder, lineWidth: 1)
        )
    }
}

@MainActor
private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: ProfileViewModel
    let userId: UUID
    let email: String
    @Binding var draft: ProfileEditDraft
    let fallbackDisplayName: String

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        let photoCardAvatarUrl = draft.avatarUrl
        let photoCardDisplayName = displayName
        let photoCardUploading = viewModel.isUploadingAvatar

        ZStack {
            Color.msBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        EditProfilePhotoCard(
                            avatarUrl: photoCardAvatarUrl,
                            displayName: photoCardDisplayName,
                            isUploadingAvatar: photoCardUploading
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 18) {
                        fieldTitle("Name")
                        TextField("Your name", text: $draft.preferredName)
                            .textInputAutocapitalization(.words)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.msBorder, lineWidth: 1)
                            )
                            .tint(Color.msGold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.msBackgroundDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.msBorder, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        fieldTitle("Gender")
                        GenderSelector(selection: $draft.gender)

                        fieldTitle("Prayer Location")
                        NavigationLink {
                            ProfileLocationPickerView(draft: $draft)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.cityName.isEmpty ? "Choose your city" : draft.cityName)
                                        .font(.appSubheadline)
                                        .foregroundStyle(Color.msTextPrimary)
                                    Text(draft.timezone ?? "Prayer times follow this city")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.msTextMuted)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.msTextMuted)
                            }
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.msBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        fieldTitle("Account")
                        Text(email)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.msCardShared.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.msBorder, lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.msBackgroundDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.msBorder, lineWidth: 1)
                    )

                    Button {
                        Task {
                            isSaving = true
                            let didSave = await viewModel.saveProfile(draft, userId: userId)
                            isSaving = false
                            if didSave {
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if isSaving {
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
                    .disabled(!draft.isValid || isSaving)
                    .opacity((!draft.isValid || isSaving) ? 0.5 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let updatedAvatarUrl = await viewModel.handleAvatarPick(item, userId: userId) {
                    draft.avatarUrl = updatedAvatarUrl
                }
            }
        }
    }

    private var displayName: String {
        let trimmed = draft.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackDisplayName : trimmed
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.appCaption)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color.msTextMuted)
    }
}

@MainActor
private struct EditProfilePhotoCard: View {
    let avatarUrl: String?
    let displayName: String
    let isUploadingAvatar: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    avatarUrl: avatarUrl,
                    name: displayName,
                    size: 92
                )
                .overlay(
                    SwiftUI.Circle()
                        .stroke(Color.msGold.opacity(0.3), lineWidth: 1)
                )

                ZStack {
                    SwiftUI.Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 30, height: 30)
                    if isUploadingAvatar {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color.msGold)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.msGold)
                    }
                }
            }

            Text("Change photo")
                .font(.appCaptionMedium)
                .foregroundStyle(Color.msGold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.msBorder, lineWidth: 1)
        )
    }
}

@MainActor
private struct GenderSelector: View {
    @Binding var selection: String?

    var body: some View {
        HStack(spacing: 8) {
            genderButton(title: "Unset", value: nil)
            genderButton(title: "Brother", value: "brother")
            genderButton(title: "Sister", value: "sister")
        }
    }

    private func genderButton(title: String, value: String?) -> some View {
        let isSelected = selection == value
        return Button {
            selection = value
        } label: {
            Text(title)
                .font(.appCaptionMedium)
                .foregroundStyle(isSelected ? Color.msBackground : Color.msGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? Color.msGold : Color.msCardShared,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.msBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private struct ProfileLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var draft: ProfileEditDraft
    @State private var searchText = ""

    private var filteredCities: [(name: String, country: String, tz: String, lat: Double, lng: Double)] {
        if searchText.isEmpty { return LocationPickerView.cities }
        return LocationPickerView.cities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.msTextMuted)

                    TextField("Search cities...", text: $searchText)
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)
                        .tint(Color.msGold)
                }
                .padding(12)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.msBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                List(filteredCities, id: \.name) { city in
                    Button {
                        draft.cityName = city.name
                        draft.timezone = city.tz
                        draft.latitude = city.lat
                        draft.longitude = city.lng
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city.name)
                                    .font(.appSubheadline)
                                    .foregroundStyle(Color.msTextPrimary)
                                Text(city.country)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.msTextMuted)
                            }

                            Spacer()

                            if city.name == draft.cityName {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.msGold)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.msTextMuted)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.msCardShared)
                    .listRowSeparatorTint(Color.msBorder)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Prayer Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

@MainActor
private struct SettingsRowLabel: View {
    let icon: String
    let label: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.msGold.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.msGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextPrimary)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private func genderLabel(for value: String?) -> String? {
    switch value {
    case "brother":
        return "Brother"
    case "sister":
        return "Sister"
    default:
        return nil
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}
