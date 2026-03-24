import SwiftUI
import Supabase

struct HomeView: View {
    @Environment(AuthManager.self) private var auth

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6:   return "Peaceful Night"
        case 6..<12:  return "Good Morning"
        case 12..<15: return "Peaceful Afternoon"
        case 15..<18: return "Blessed Asr"
        case 18..<21: return "Blessed Evening"
        default:      return "Peaceful Night"
        }
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6:   return "🌙"
        case 6..<12:  return "☀️"
        case 12..<15: return "🕌"
        case 15..<18: return "🤲"
        case 18..<21: return "🌅"
        default:      return "🌙"
        }
    }

    private var firstName: String {
        let fullName = auth.session?.user.userMetadata["full_name"]?.stringValue
                    ?? auth.session?.user.email?.components(separatedBy: "@").first
                    ?? "Friend"
        return fullName.components(separatedBy: " ").first ?? fullName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("\(greeting), \(firstName) \(greetingEmoji)")
                            .font(.system(.title, design: .serif, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Your habits await")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 32)

                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color(hex: "E8834B").opacity(0.8))

                        Text("Habits coming in Phase 2")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
