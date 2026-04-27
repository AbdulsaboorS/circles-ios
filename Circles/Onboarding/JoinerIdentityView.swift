import SwiftUI

struct JoinerIdentityView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

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
                VStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.msGold)
                        .padding(.top, 24)

                    Text("Your Location")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("We use your city to calculate accurate prayer times — so your habits stay anchored to your day.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.msTextMuted)

                    TextField("Search cities...", text: $searchText)
                        .font(.system(size: 15, weight: .medium))
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
                        coordinator.proceedToAuthGate()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.msTextPrimary)

                                Text(city.country)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.msTextMuted)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
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

                StepIndicator(current: 5, total: 6)
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
