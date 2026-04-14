import SwiftUI
import Supabase

struct JourneyView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                IslamicGeometricPattern(opacity: 0.016, tileSize: 52)

                if let userId = auth.session?.user.id {
                    JourneyContentView(userId: userId)
                } else {
                    ProgressView()
                        .tint(Color.msGold)
                }
            }
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct JourneyContentView: View {
    let userId: UUID

    @State private var viewModel: JourneyViewModel
    @State private var selectedDay: JourneyDay? = nil

    init(userId: UUID) {
        self.userId = userId
        _viewModel = State(initialValue: JourneyViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                MonthHeader(
                    title: viewModel.monthTitle,
                    isLoading: viewModel.isLoadingMonth,
                    onPrevious: { Task { await viewModel.showPreviousMonth() } },
                    onNext: { Task { await viewModel.showNextMonth() } }
                )

                Text("A private archive of the days you showed up.")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.msCardDeep.opacity(0.94))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.msBorder, lineWidth: 1)
                        }

                    JourneyCalendarGrid(
                        monthAnchor: viewModel.currentMonthAnchor,
                        weekdaySymbols: viewModel.weekdaySymbols,
                        leadingEmptyCellCount: viewModel.leadingEmptyCellCount,
                        days: viewModel.days,
                        onSelectDay: { selectedDay = $0 }
                    )
                    .padding(18)

                    if viewModel.hasAnyEntries == false && viewModel.isLoadingInitial == false {
                        JourneyEmptyOverlay()
                    }

                    if viewModel.isLoadingInitial && viewModel.days.isEmpty {
                        ProgressView()
                            .tint(Color.msGold)
                    }
                }
                .gesture(monthSwipeGesture)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(
                        message: errorMessage,
                        onRetry: { Task { await viewModel.loadDisplayedMonth() } }
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .task {
            await viewModel.loadInitial()
        }
        .sheet(item: $selectedDay) { day in
            JourneyDayDetailView(day: day)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width <= -50 {
                    Task { await viewModel.showNextMonth() }
                } else if value.translation.width >= 50 {
                    Task { await viewModel.showPreviousMonth() }
                }
            }
    }
}

private struct MonthHeader: View {
    let title: String
    let isLoading: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            monthButton(systemName: "chevron.left", action: onPrevious)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)

                if isLoading {
                    Text("Loading month...")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
            }
            .frame(maxWidth: .infinity)

            monthButton(systemName: "chevron.right", action: onNext)
        }
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.msGold)
                .frame(width: 36, height: 36)
                .background(Color.msCardShared, in: SwiftUI.Circle())
                .overlay {
                    SwiftUI.Circle()
                        .stroke(Color.msBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct JourneyEmptyOverlay: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.msGold.opacity(0.78))

            Text("Your journey begins with your first intention")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextPrimary.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.msGold)

            Text(message)
                .font(.appCaptionMedium)
                .foregroundStyle(Color.msTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Retry", action: onRetry)
                .font(.appCaptionMedium)
                .foregroundStyle(Color.msGold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.msBorder, lineWidth: 1)
        }
    }
}

#Preview {
    JourneyView()
        .environment(AuthManager())
}
