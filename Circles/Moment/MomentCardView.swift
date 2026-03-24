import SwiftUI

struct MomentCardView: View {
    let moment: CircleMoment?       // nil for own-unposted state
    let isOwnPost: Bool             // true if moment.userId == currentUser
    let hasPostedToday: Bool        // true if current user has posted in this circle today
    let onTapLocked: () -> Void     // opens camera
    let memberName: String          // display name

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            cardImage
            memberLabel
        }
    }

    // MARK: - Card Image

    @ViewBuilder
    private var cardImage: some View {
        if let moment = moment, isOwnPost {
            // Own posted card — always unlocked
            unlockedCard(moment: moment)
        } else if let moment = moment, hasPostedToday {
            // Peer unlocked card
            unlockedCard(moment: moment)
        } else if let moment = moment {
            // Peer locked card
            lockedCard(moment: moment)
        } else if isOwnPost {
            // Own unposted placeholder
            ownUnpostedCard
        }
    }

    // MARK: - Unlocked Card

    private func unlockedCard(moment: CircleMoment) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: moment.photoUrl)) { phase in
                switch phase {
                case .empty:
                    Color(hex: "1A1D35")
                        .overlay(ProgressView().tint(.white))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color(hex: "1A1D35")
                        .overlay(
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.white.opacity(0.3))
                        )
                @unknown default:
                    Color(hex: "1A1D35")
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // On-time star badge
            if moment.isOnTime {
                ZStack {
                    SwiftUI.Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "E8834B"))
                }
                .padding(6)
            }
        }
    }

    // MARK: - Locked Card

    private func lockedCard(moment: CircleMoment) -> some View {
        ZStack {
            AsyncImage(url: URL(string: moment.photoUrl)) { phase in
                switch phase {
                case .empty:
                    Color(hex: "1A1D35")
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 20)
                case .failure:
                    Color(hex: "1A1D35")
                @unknown default:
                    Color(hex: "1A1D35")
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Scrim + lock overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))

            VStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                Text("Post to unlock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .onTapGesture { onTapLocked() }
        .accessibilityLabel("\(memberName)'s Moment \u{2014} locked. Tap to post your Moment first.")
    }

    // MARK: - Own Unposted Card

    private var ownUnpostedCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1D35"), Color(hex: "0D1021")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                Text("Post to unlock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .onTapGesture { onTapLocked() }
        .accessibilityLabel("Your Moment \u{2014} tap to post.")
    }

    // MARK: - Member Label

    @ViewBuilder
    private var memberLabel: some View {
        if isOwnPost && moment == nil {
            Text("You \u{2014} tap to post")
                .font(.caption)
                .foregroundStyle(Color(hex: "E8834B"))
                .lineLimit(1)
        } else {
            Text(memberName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}
