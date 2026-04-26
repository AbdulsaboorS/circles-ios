import SwiftUI
import UserNotifications

struct AmiirStep3LocationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    @State private var searchText = ""
    @State private var pushRequested = false
    @State private var pushDenied = false
    @State private var showPermissionPrompt = false

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

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.msGold)
                        .padding(.top, 24)

                    Text("Prayer Synchronization")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your location helps us anchor your Circle Moment to the right prayer.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)

                // Push notification soft ask
                if !pushRequested {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Color.msGold)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable the Adhan for your circle")
                                    .font(.appCaptionMedium)
                                    .foregroundStyle(Color.msGold)
                                Text("Get notified when your prayer window opens for Circle Moment.")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.msTextMuted)
                            }

                            Spacer()

                            Button {
                                showPermissionPrompt = true
                            } label: {
                                Text("Enable")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.msBackground)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.msGold, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                } else if pushDenied {
                    VStack(spacing: 6) {
                        Text("Without the Adhan notification, your Circle Moment window won't alert you. Enable anytime in Settings.")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)

                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.msTextMuted)
                    TextField("Search cities…", text: $searchText)
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)
                        .tint(Color.msGold)
                }
                .padding(12)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                List(filteredCities, id: \.name) { city in
                    Button {
                        coordinator.cityName = city.name
                        coordinator.cityTimezone = city.tz
                        coordinator.cityLatitude = city.lat
                        coordinator.cityLongitude = city.lng
                        coordinator.proceedToActivation()
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
                            Image(systemName: "chevron.right")
                                .font(.appCaption)
                                .foregroundStyle(Color.msTextMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.msCardShared)
                    .listRowSeparatorTint(Color.msBorder)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                if let error = coordinator.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .padding()
                }

                StepIndicator(current: 7, total: 8)
                    .padding(.bottom, 16)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.navigationPath.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.msGold)
                }
            }
        }
        .sheet(isPresented: $showPermissionPrompt, onDismiss: {
            Task { await syncNotificationState() }
        }) {
            NotificationPermissionModal(
                isPresented: $showPermissionPrompt,
                prayerTimeName: DailyMomentService.shared.prayerDisplayName
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await syncNotificationState()
        }
    }

    private func syncNotificationState() async {
        await NotificationService.shared.refreshPermissionStatus()
        let status = NotificationService.shared.permissionStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            pushRequested = true
            pushDenied = false
        case .denied:
            pushRequested = true
            pushDenied = true
        case .notDetermined:
            pushRequested = false
            pushDenied = false
        @unknown default:
            pushRequested = false
            pushDenied = false
        }
    }
}
