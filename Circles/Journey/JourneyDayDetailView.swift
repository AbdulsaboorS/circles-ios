import SwiftUI

struct JourneyDayDetailView: View {
    private let days: [JourneyDay]
    @State private var selectedDayKey: String

    init(days: [JourneyDay], selectedDayKey: String) {
        let detailDays = days.filter { $0.hasNiyyah || $0.hasPostedMoment }
        self.days = detailDays
        let initialDayKey = detailDays.contains(where: { $0.dayKey == selectedDayKey })
            ? selectedDayKey
            : (detailDays.first?.dayKey ?? selectedDayKey)
        _selectedDayKey = State(initialValue: initialDayKey)
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()
            IslamicGeometricPattern(opacity: 0.02, tileSize: 44)

            if days.isEmpty {
                JourneyDetailUnavailableView()
            } else {
                TabView(selection: $selectedDayKey) {
                    ForEach(days) { day in
                        JourneyDayDetailPage(day: day)
                            .tag(day.dayKey)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .task(id: selectedDayKey) {
            await prefetchCurrentWindow()
        }
    }

    private func prefetchCurrentWindow() async {
        guard let selectedIndex = days.firstIndex(where: { $0.dayKey == selectedDayKey }) else { return }

        let nearbyDays = [selectedIndex - 1, selectedIndex, selectedIndex + 1]
            .filter { days.indices.contains($0) }
            .map { days[$0] }

        for day in nearbyDays {
            guard let moment = day.moment else { continue }
            await MomentService.shared.prefetchMomentMedia(
                primaryStoredValue: moment.photoUrl,
                secondaryStoredValue: moment.secondaryPhotoUrl
            )
        }
    }
}

private struct JourneyDayDetailPage: View {
    let day: JourneyDay

    @State private var resolvedMedia: ResolvedMomentMedia? = nil
    @State private var isLoadingMedia = false
    @State private var mediaLoadFailed = false
    @State private var swapped = false

    private var mainPhotoURL: String? {
        guard let resolvedMedia else { return nil }
        return swapped ? (resolvedMedia.secondaryURL ?? resolvedMedia.primaryURL) : resolvedMedia.primaryURL
    }

    private var mainCacheKey: String? {
        guard let resolvedMedia else { return nil }
        return swapped
            ? (resolvedMedia.secondaryCacheKey ?? resolvedMedia.primaryCacheKey)
            : resolvedMedia.primaryCacheKey
    }

    private var pipPhotoURL: String? {
        guard let resolvedMedia, resolvedMedia.secondaryURL != nil else { return nil }
        return swapped ? resolvedMedia.primaryURL : resolvedMedia.secondaryURL
    }

    private var pipCacheKey: String? {
        guard let resolvedMedia, resolvedMedia.secondaryCacheKey != nil else { return nil }
        return swapped ? resolvedMedia.primaryCacheKey : resolvedMedia.secondaryCacheKey
    }

    var body: some View {
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
        .task(id: day.id) {
            await loadMediaIfNeeded()
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
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.msCardShared)

            if let mainPhotoURL, let mainCacheKey {
                CachedAsyncImage(url: mainPhotoURL, cacheKey: mainCacheKey) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    loadingPhotoPlaceholder
                }
            } else {
                loadingPhotoPlaceholder
            }

            if let pipPhotoURL, let pipCacheKey {
                CachedAsyncImage(url: pipPhotoURL, cacheKey: pipCacheKey) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.msCardShared
                }
                .frame(width: 118, height: 157)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.msGold, lineWidth: 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        swapped.toggle()
                    }
                }
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
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

            if isLoadingMedia {
                ProgressView()
                    .tint(Color.msGold)
            } else if mediaLoadFailed {
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

    private func loadMediaIfNeeded() async {
        guard let moment = day.moment else { return }

        isLoadingMedia = true
        mediaLoadFailed = false
        swapped = false
        defer { isLoadingMedia = false }

        do {
            resolvedMedia = try await MomentService.shared.resolveMomentMedia(
                primaryStoredValue: moment.photoUrl,
                secondaryStoredValue: moment.secondaryPhotoUrl
            )
        } catch {
            resolvedMedia = nil
            mediaLoadFailed = true
        }
    }
}

private struct JourneyDetailUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 24))
                .foregroundStyle(Color.msGold.opacity(0.8))

            Text("This day is no longer available.")
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextMuted)
        }
    }
}
