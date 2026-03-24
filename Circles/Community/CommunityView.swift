import SwiftUI

struct CommunityView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(hex: "E8834B").opacity(0.7))

                    VStack(spacing: 8) {
                        Text("Your Circles")
                            .font(.system(.title2, design: .serif, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Create or join a circle to get started")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

#Preview {
    CommunityView()
}
