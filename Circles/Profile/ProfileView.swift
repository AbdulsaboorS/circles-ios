import SwiftUI
import Supabase

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    Circle()
                        .fill(Color(hex: "E8834B").opacity(0.2))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color(hex: "E8834B"))
                        )

                    VStack(spacing: 6) {
                        Text(auth.session?.user.email ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        Task { await auth.signOut() }
                    } label: {
                        Text("Sign Out")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}
