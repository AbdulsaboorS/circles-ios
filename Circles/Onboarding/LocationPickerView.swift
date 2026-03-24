import SwiftUI
import Supabase

struct LocationPickerView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(AuthManager.self) private var auth
    @State private var searchText = ""

    // Bundled city list: (name, country, timezone, lat, lng)
    // Top cities by Muslim population — diaspora-focused, no API needed
    static let cities: [(name: String, country: String, tz: String, lat: Double, lng: Double)] = [
        ("New York", "US", "America/New_York", 40.7128, -74.0060),
        ("Los Angeles", "US", "America/Los_Angeles", 34.0522, -118.2437),
        ("Chicago", "US", "America/Chicago", 41.8781, -87.6298),
        ("Houston", "US", "America/Chicago", 29.7604, -95.3698),
        ("Toronto", "CA", "America/Toronto", 43.6532, -79.3832),
        ("London", "GB", "Europe/London", 51.5074, -0.1278),
        ("Birmingham", "GB", "Europe/London", 52.4862, -1.8904),
        ("Paris", "FR", "Europe/Paris", 48.8566, 2.3522),
        ("Berlin", "DE", "Europe/Berlin", 52.5200, 13.4050),
        ("Istanbul", "TR", "Europe/Istanbul", 41.0082, 28.9784),
        ("Dubai", "AE", "Asia/Dubai", 25.2048, 55.2708),
        ("Riyadh", "SA", "Asia/Riyadh", 24.7136, 46.6753),
        ("Mecca", "SA", "Asia/Riyadh", 21.3891, 39.8579),
        ("Medina", "SA", "Asia/Riyadh", 24.5247, 39.5692),
        ("Cairo", "EG", "Africa/Cairo", 30.0444, 31.2357),
        ("Karachi", "PK", "Asia/Karachi", 24.8607, 67.0011),
        ("Lahore", "PK", "Asia/Karachi", 31.5204, 74.3587),
        ("Islamabad", "PK", "Asia/Karachi", 33.7294, 73.0931),
        ("Dhaka", "BD", "Asia/Dhaka", 23.8103, 90.4125),
        ("Mumbai", "IN", "Asia/Kolkata", 19.0760, 72.8777),
        ("Delhi", "IN", "Asia/Kolkata", 28.6139, 77.2090),
        ("Hyderabad", "IN", "Asia/Kolkata", 17.3850, 78.4867),
        ("Jakarta", "ID", "Asia/Jakarta", -6.2088, 106.8456),
        ("Kuala Lumpur", "MY", "Asia/Kuala_Lumpur", 3.1390, 101.6869),
        ("Singapore", "SG", "Asia/Singapore", 1.3521, 103.8198),
        ("Lagos", "NG", "Africa/Lagos", 6.5244, 3.3792),
        ("Nairobi", "KE", "Africa/Nairobi", -1.2921, 36.8219),
        ("Casablanca", "MA", "Africa/Casablanca", 33.5731, -7.5898),
        ("Amman", "JO", "Asia/Amman", 31.9454, 35.9284),
        ("Baghdad", "IQ", "Asia/Baghdad", 33.3152, 44.3661),
        ("Tehran", "IR", "Asia/Tehran", 35.6892, 51.3890),
        ("Kabul", "AF", "Asia/Kabul", 34.5553, 69.2075),
        ("Sydney", "AU", "Australia/Sydney", -33.8688, 151.2093),
        ("Melbourne", "AU", "Australia/Melbourne", -37.8136, 144.9631),
        ("Amsterdam", "NL", "Europe/Amsterdam", 52.3676, 4.9041),
        ("Brussels", "BE", "Europe/Brussels", 50.8503, 4.3517),
        ("Stockholm", "SE", "Europe/Stockholm", 59.3293, 18.0686),
        ("Oslo", "NO", "Europe/Oslo", 59.9139, 10.7522),
        ("Copenhagen", "DK", "Europe/Copenhagen", 55.6761, 12.5683),
        ("Ottawa", "CA", "America/Toronto", 45.4215, -75.6972),
        ("Montreal", "CA", "America/Toronto", 45.5017, -73.5673),
        ("Vancouver", "CA", "America/Vancouver", 49.2827, -123.1207),
        ("Dallas", "US", "America/Chicago", 32.7767, -96.7970),
        ("Atlanta", "US", "America/New_York", 33.7490, -84.3880),
        ("Washington DC", "US", "America/New_York", 38.9072, -77.0369),
        ("Boston", "US", "America/New_York", 42.3601, -71.0589),
        ("Minneapolis", "US", "America/Chicago", 44.9778, -93.2650),
        ("Detroit", "US", "America/Detroit", 42.3314, -83.0458),
        ("Phoenix", "US", "America/Phoenix", 33.4484, -112.0740),
        ("Seattle", "US", "America/Los_Angeles", 47.6062, -122.3321)
    ]

    var filteredCities: [(name: String, country: String, tz: String, lat: Double, lng: Double)] {
        if searchText.isEmpty { return Self.cities }
        return Self.cities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Where are you based?")
                .font(.title.bold())
                .padding(.top, 32)
                .padding(.bottom, 8)
            Text("Used to calculate your prayer times")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            List(filteredCities, id: \.name) { city in
                Button {
                    coordinator.cityName = city.name
                    coordinator.cityTimezone = city.tz
                    coordinator.cityLatitude = city.lat
                    coordinator.cityLongitude = city.lng
                    guard let userId = auth.session?.user.id else { return }
                    Task { await coordinator.saveLocationAndMarkComplete(userId: userId) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name).font(.body)
                            Text(city.country).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if coordinator.cityName == city.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color(hex: "E8834B"))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search city...")
        }
        .navigationTitle("Your Location")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("OK") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }
}
