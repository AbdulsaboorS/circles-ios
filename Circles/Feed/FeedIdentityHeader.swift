import SwiftUI

struct FeedIdentityHeader: View {
    let avatarUrl: String?
    let displayName: String
    let circleName: String?
    let timestamp: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarView(avatarUrl: avatarUrl, name: displayName, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "F0EAD6"))
                        .lineLimit(1)

                    if let circleName, !circleName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(circleName)
                                .font(.appCaption)
                                .foregroundStyle(Color(hex: "8FAF94"))
                                .lineLimit(1)
                        }
                    }
                }

                Text(timestamp)
                    .font(.appCaption)
                    .foregroundStyle(Color(hex: "8FAF94"))
            }

            Spacer(minLength: 0)
        }
    }
}
