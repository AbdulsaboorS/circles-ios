import SwiftUI

struct OwnMomentFullView: View {
    let item: MomentFeedItem
    let profile: Profile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "111A13").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Identity header
                    FeedIdentityHeader(
                        avatarUrl: profile?.avatarUrl,
                        displayName: displayName,
                        circleName: nil,
                        timestamp: timestampLabel
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 52)  // leave room for close button

                    // Gold "Shared with X circles" pill
                    Text("Shared with \(item.circleIds.count) Circle\(item.circleIds.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A2E1E"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "D4A240"), in: Capsule())
                        .padding(.horizontal, 16)

                    // Photo (3:4 ratio)
                    CachedAsyncImage(url: item.photoUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: "243828").overlay(ProgressView().tint(Color(hex: "D4A240")))
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3.0 / 4.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 12)

                    // On-time badge
                    HStack {
                        Text(item.isOnTime ? "On Time" : "Late")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(item.isOnTime ? Color(hex: "1A2E1E") : Color(hex: "F0EAD6"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                item.isOnTime ? Color(hex: "D4A240") : Color(hex: "8FAF94").opacity(0.22),
                                in: Capsule()
                            )
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Caption
                    if let caption = item.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.appSubheadline)
                            .foregroundStyle(Color(hex: "F0EAD6"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 32)
                }
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "F0EAD6"))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: SwiftUI.Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var displayName: String {
        let preferred = profile?.preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return preferred.isEmpty ? item.userName : preferred
    }

    private var timestampLabel: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: item.postedAt) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: item.postedAt)
        }() else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(max(1, Int(diff / 60)))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
