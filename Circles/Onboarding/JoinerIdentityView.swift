import SwiftUI
import UIKit

private extension Color {
    static let msBackground = Color(hex: "1A2E1E")
    static let msCardShared = Color(hex: "243828")
    static let msGold = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted = Color(hex: "8FAF94")
    static let msBorder = Color(hex: "D4A240").opacity(0.18)
}

struct JoinerIdentityView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    @State private var searchText = ""
    @State private var pushRequested = false
    @State private var pushDenied = false

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

                    Text("Anchor your prayer times.")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your city helps us sync your prayer window.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)

                if !pushRequested {
                    Button {
                        pushRequested = true
                        Task {
                            let granted = await NotificationService.shared.requestPermission()
                            if !granted {
                                pushDenied = true
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Color.msBackground)
                            Text("Enable the Adhan for your circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.msBackground)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.msGold, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                } else if pushDenied {
                    VStack(spacing: 8) {
                        Text("Without the Adhan notification, your Circle Moment window won't alert you. Enable anytime in Settings.")
                            .font(.system(size: 13))
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

                StepIndicator(current: 5, total: 7)
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
