import SwiftUI
import Supabase

struct AmiirStep3LocationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    private var filteredCities: [(name: String, country: String, tz: String, lat: Double, lng: Double)] {
        if searchText.isEmpty { return LocationPickerView.cities }
        return LocationPickerView.cities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accent.opacity(0.85))
                        .padding(.top, 24)

                    Text("Prayer Synchronization")
                        .font(.appTitle)
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your location helps us anchor your Circle Moment to the right prayer.")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(colors.textSecondary)
                    TextField("Search cities…", text: $searchText)
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textPrimary)
                        .tint(Color.accent)
                }
                .padding(12)
                .background(Color.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                if coordinator.isLoading {
                    Spacer()
                    ProgressView().tint(Color.accent)
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
                                        .foregroundStyle(colors.textPrimary)
                                    Text(city.country)
                                        .font(.appCaption)
                                        .foregroundStyle(colors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.appCaption)
                                    .foregroundStyle(colors.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.accent.opacity(0.1))
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

                StepIndicator(current: 2, total: 4)
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
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }
}
