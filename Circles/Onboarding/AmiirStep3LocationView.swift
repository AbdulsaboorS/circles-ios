import SwiftUI
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

struct AmiirStep3LocationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @Environment(AuthManager.self) private var auth

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
                .padding(.bottom, 16)

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

                if coordinator.isLoading {
                    Spacer()
                    ProgressView().tint(Color.msGold)
                    Spacer()
                } else {
                    List(filteredCities, id: \.name) { city in
                        Button {
                            coordinator.cityName = city.name
                            coordinator.cityTimezone = city.tz
                            coordinator.cityLatitude = city.lat
                            coordinator.cityLongitude = city.lng
                            if let userId = auth.session?.user.id {
                                Task { await coordinator.createCircleAndProceed(userId: userId) }
                            }
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
                }

                if let error = coordinator.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .padding()
                }

                StepIndicator(current: 3, total: 5)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarBackButtonHidden()
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
    }
}
