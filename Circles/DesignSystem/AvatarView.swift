import SwiftUI

/// Reusable circular avatar. Shows the user's photo if available,
/// falls back to amber initials on a warm tinted circle.
struct AvatarView: View {
    let avatarUrl: String?
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(SwiftUI.Circle())
    }

    private var initialsView: some View {
        ZStack {
            SwiftUI.Circle()
                .fill(Color.accent.opacity(0.15))
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: max(10, size * 0.35), weight: .semibold))
                .foregroundStyle(Color.accent)
        }
    }
}
