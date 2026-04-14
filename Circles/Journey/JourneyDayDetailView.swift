import SwiftUI

struct JourneyDayDetailView: View {
    let day: JourneyDay

    @State private var signedPhotoURL: String? = nil
    @State private var isLoadingPhoto = false
    @State private var photoLoadFailed = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()
            IslamicGeometricPattern(opacity: 0.02, tileSize: 44)

            ScrollView {
                VStack(spacing: 26) {
                    Capsule()
                        .fill(Color.msTextMuted.opacity(0.25))
                        .frame(width: 44, height: 5)
                        .padding(.top, 10)

                    Text(JourneyDateSupport.formattedDate(for: day.displayDateUTC))
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)

                    if let niyyah = day.niyyah {
                        Text("\"\(niyyah.niyyahText)\"")
                            .font(.system(size: 30, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    mediaSection
                        .padding(.top, day.niyyah == nil ? 12 : 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .task(id: day.id) {
            await loadPhotoIfNeeded()
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        if day.hasPostedMoment {
            momentPhotoCard
        } else {
            niyyahOnlyPlaceholder
        }
    }

    private var momentPhotoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.msCardShared)

            if let signedPhotoURL {
                CachedAsyncImage(url: signedPhotoURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    loadingPhotoPlaceholder
                }
            } else {
                loadingPhotoPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(day.hasNiyyah ? Color.msGold.opacity(0.28) : Color.msBorder, lineWidth: 1)
        }
        .overlay {
            if day.hasNiyyah {
                NoorAuraOverlay(cornerRadius: 28)
            }
        }
    }

    private var loadingPhotoPlaceholder: some View {
        ZStack {
            Color.msCardShared

            if isLoadingPhoto {
                ProgressView()
                    .tint(Color.msGold)
            } else if photoLoadFailed {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.msTextMuted.opacity(0.7))
                    Text("Photo unavailable")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.msTextMuted.opacity(0.5))
            }
        }
    }

    private var niyyahOnlyPlaceholder: some View {
        VStack(spacing: 14) {
            ZStack {
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(0.12))
                    .frame(width: 84, height: 84)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.msGold.opacity(0.85))
            }

            Text("No photo was preserved for this day.")
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.msCardDeep.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.msBorder, lineWidth: 1)
        }
    }

    private func loadPhotoIfNeeded() async {
        guard let storedPhotoPath = day.moment?.photoUrl else { return }

        isLoadingPhoto = true
        photoLoadFailed = false
        defer { isLoadingPhoto = false }

        do {
            signedPhotoURL = try await MomentService.shared.resolveMomentPhotoURL(from: storedPhotoPath)
        } catch {
            photoLoadFailed = true
        }
    }
}
