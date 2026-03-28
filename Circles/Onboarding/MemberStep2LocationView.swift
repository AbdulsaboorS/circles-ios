import SwiftUI
import Supabase

struct MemberStep2LocationView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator
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
                VStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accent.opacity(0.85))
                        .padding(.top, 20)

                    Text("Prayer Synchronization")
                        .font(.appTitle)
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your location helps us align your Circle Moment to the right prayer time.")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)

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
                .padding(.bottom, 6)

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
                                Task { await coordinator.joinAndComplete(userId: userId) }
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
                        .padding(.horizontal, 20)
                }

                StepIndicator(current: 1, total: 2)
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
