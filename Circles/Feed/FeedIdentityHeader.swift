import SwiftUI

struct FeedIdentityHeader: View {
    let avatarUrl: String?
    let displayName: String
    let circleName: String?
    let timestamp: String
    var isOnTime: Bool? = nil
    var avatarSize: CGFloat = 42
    var onMenuTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarView(avatarUrl: avatarUrl, name: displayName, size: avatarSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "F0EAD6"))
                    .lineLimit(1)

                subtitleLine
            }

            Spacer(minLength: 0)

            if let onMenuTap {
                Button(action: onMenuTap) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "8FAF94"))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var subtitleLine: some View {
        if let circleName, !circleName.isEmpty {
            HStack(spacing: 4) {
                Text(circleName)
                    .font(.appCaption)
                    .foregroundStyle(Color(hex: "8FAF94"))
                    .lineLimit(1)

                if let isOnTime {
                    Text("•")
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "8FAF94"))

                    if isOnTime {
                        Text("On Time")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "1A2E1E"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: "D4A240"), in: Capsule())
                    } else {
                        Text(timestamp)
                            .font(.appCaption)
                            .foregroundStyle(Color(hex: "8FAF94"))
                    }
                } else {
                    Text("•")
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "8FAF94"))
                    Text(timestamp)
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "8FAF94"))
                }
            }
        } else {
            Text(timestamp)
                .font(.appCaption)
                .foregroundStyle(Color(hex: "8FAF94"))
        }
    }
}
