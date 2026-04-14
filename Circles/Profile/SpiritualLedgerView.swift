import SwiftUI
import Supabase

/// Private journal archive of past Niyyahs — only the owner can see this.
/// Each entry is a full page with the Niyyah text as hero and a small photo thumbnail.
struct SpiritualLedgerView: View {
    let userId: UUID
    @State private var entries: [LedgerEntry] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private struct LedgerEntry: Identifiable {
        let id: UUID
        let niyyahText: String
        let photoDate: String
        let photoUrl: String?
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()
            IslamicGeometricPattern(opacity: 0.025)

            if isLoading {
                ProgressView()
                    .tint(Color.msGold)
            } else if entries.isEmpty {
                emptyState
            } else {
                ledgerPages
            }

            // Close button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.msTextPrimary)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: SwiftUI.Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 12)
                    Spacer()
                }
                Spacer()
            }
        }
        .task { await loadEntries() }
    }

    // MARK: - Ledger Pages

    private var ledgerPages: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    ledgerPage(entry: entry)
                        .containerRelativeFrame(.vertical)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
    }

    private func ledgerPage(entry: LedgerEntry) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Date
            Text(formattedDate(entry.photoDate))
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
                .padding(.bottom, 24)

            // Niyyah text — the hero
            Text("\"\(entry.niyyahText)\"")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            // Photo thumbnail
            if let photoUrl = entry.photoUrl {
                CachedAsyncImage(url: photoUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.msCardShared
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(Color.msTextMuted.opacity(0.3))
                        )
                }
                .frame(width: 80, height: 107)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.msGold.opacity(0.3), lineWidth: 1)
                )
                .overlay {
                    NoorAuraOverlay(cornerRadius: 12)
                }
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 40))
                .foregroundStyle(Color.msGold.opacity(0.5))
            Text("Your spiritual journey begins\nwith your first Niyyah")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Data Loading

    private func loadEntries() async {
        isLoading = true
        do {
            let niyyahs = try await NiyyahService.shared.fetchMyNiyyahs(userId: userId)
            var loaded: [LedgerEntry] = []
            for niyyah in niyyahs {
                var photoUrl: String?
                if let moment = try? await MomentService.shared.fetchMomentForDate(
                    userId: userId, date: niyyah.photoDate
                ) {
                    photoUrl = moment.photoUrl
                }
                loaded.append(LedgerEntry(
                    id: niyyah.id,
                    niyyahText: niyyah.niyyahText,
                    photoDate: niyyah.photoDate,
                    photoUrl: photoUrl
                ))
            }
            entries = loaded
        } catch {
            print("[SpiritualLedgerView] load failed: \(error)")
        }
        isLoading = false
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
