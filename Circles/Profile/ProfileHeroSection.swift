import SwiftUI

struct ProfileHeroSection: View {
    let viewModel: ProfileViewModel
    let displayName: String
    let memberSince: String
    let heroHeight: CGFloat

    var body: some View {
        let avatarUrl = viewModel.avatarUrl

        ZStack(alignment: .bottom) {
            // Full-height profile image treatment with no blur so the uploaded photo reads clearly.
            ProfileHeroImageView(avatarUrl: avatarUrl)
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()

            // Bottom gradient — fades photo into the page background
            LinearGradient(
                colors: [.clear, Color.clear, Color.msBackground.opacity(0.72), Color.msBackground],
                startPoint: .init(x: 0.5, y: 0.2),
                endPoint: .bottom
            )
            .frame(height: heroHeight)

            // Name + member since overlaid at bottom-left
            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.appTitle)
                    .foregroundStyle(Color.msTextPrimary)

                if !memberSince.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.msGold)
                        Text(memberSince)
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileHeroImageView: View {
    let avatarUrl: String?

    var body: some View {
        if let urlString = avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    loadedImage(image)
                default:
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    @ViewBuilder
    private func loadedImage(_ image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
    }

    private var placeholderCover: some View {
        ZStack {
            Color.msCardShared
            VStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.msTextMuted.opacity(0.4))
                Text("Add a profile photo in Settings")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted.opacity(0.6))
            }
        }
    }
}
