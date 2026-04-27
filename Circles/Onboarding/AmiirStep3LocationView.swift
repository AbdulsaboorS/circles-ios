import SwiftUI

struct AmiirStep3LocationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

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

                    Text("Your Location")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("We use your city to calculate accurate prayer times — so your circle and habits stay anchored to your day.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)

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

                StepIndicator(current: 9, total: 10)
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
