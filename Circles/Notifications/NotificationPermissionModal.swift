import SwiftUI

struct NotificationPermissionModal: View {
    @Binding var isPresented: Bool
    var prayerTimeName: String = "prayer time"

    var body: some View {
        ZStack {
            Color(hex: "0D1021").ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(hex: "E8834B"))

                VStack(spacing: 12) {
                    Text("Never Miss Your Moment")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Your circle posts their Moment at \(prayerTimeName.capitalized). Turn on notifications to never miss the 30-minute window.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        isPresented = false
                        Task {
                            await NotificationService.shared.requestPermission()
                        }
                    } label: {
                        Text("Enable Notifications")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "E8834B"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)

                    Button("Not now") {
                        isPresented = false
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.subheadline)
                }

                Spacer()
            }
        }
    }
}
