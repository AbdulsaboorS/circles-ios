import Foundation
import Observation

@Observable
@MainActor
final class JourneyViewModel {
    let userId: UUID

    var currentMonthAnchor: Date
    var days: [JourneyDay] = []
    var isLoadingInitial = false
    var isLoadingMonth = false
    var errorMessage: String? = nil
    var hasAnyEntries = false

    private var hasLoadedInitialData = false
    private var niyyahsByDay: [String: MomentNiyyah] = [:]
    private var momentCacheByMonth: [String: [String: CircleMoment]] = [:]
    private var loadingMonthKeys: Set<String> = []

    init(userId: UUID, initialDate: Date = Date()) {
        self.userId = userId
        self.currentMonthAnchor = JourneyDateSupport.monthAnchor(for: initialDate)
    }

    var monthTitle: String {
        JourneyDateSupport.monthTitle(for: currentMonthAnchor)
    }

    var weekdaySymbols: [String] {
        JourneyDateSupport.weekdaySymbols()
    }

    var leadingEmptyCellCount: Int {
        JourneyDateSupport.leadingEmptyCellCount(for: currentMonthAnchor)
    }

    var isCurrentMonthEmpty: Bool {
        !days.contains { $0.hasNiyyah || $0.hasPostedMoment }
    }

    func loadInitial() async {
        guard !hasLoadedInitialData else {
            await refreshArchiveSummaryIfPossible()
            await loadDisplayedMonth()
            return
        }

        isLoadingInitial = true
        errorMessage = nil

        do {
            try await refreshArchiveSummary()
            hasLoadedInitialData = true
            rebuildDays()

            try await ensureMonthLoaded(currentMonthAnchor)
            rebuildDays()

            Task { await prefetchAdjacentMonths(around: currentMonthAnchor) }
        } catch {
            rebuildDays()
            errorMessage = "Could not load Journey right now."
        }

        isLoadingInitial = false
    }

    func showPreviousMonth() async {
        await showMonth(offset: -1)
    }

    func showNextMonth() async {
        await showMonth(offset: 1)
    }

    func loadDisplayedMonth() async {
        guard hasLoadedInitialData else {
            await loadInitial()
            return
        }

        errorMessage = nil
        rebuildDays()
        do {
            try await ensureMonthLoaded(currentMonthAnchor, showsLoadingState: true)
            rebuildDays()
            Task { await prefetchAdjacentMonths(around: currentMonthAnchor) }
        } catch {
            errorMessage = "Could not load this month."
        }
    }

    private func refreshArchiveSummaryIfPossible() async {
        try? await refreshArchiveSummary()
    }

    private func refreshArchiveSummary() async throws {
        async let niyyahsFetch = NiyyahService.shared.fetchMyNiyyahs(userId: userId)
        async let hasMomentsFetch = MomentService.shared.hasAnyMoments(userId: userId)

        let niyyahs = try await niyyahsFetch
        let hasMoments = try await hasMomentsFetch
        niyyahsByDay = Dictionary(uniqueKeysWithValues: niyyahs.map { ($0.photoDate, $0) })
        hasAnyEntries = !niyyahs.isEmpty || hasMoments
    }

    private func showMonth(offset: Int) async {
        guard let shifted = JourneyDateSupport.calendar.date(byAdding: .month, value: offset, to: currentMonthAnchor) else {
            return
        }
        currentMonthAnchor = JourneyDateSupport.monthAnchor(for: shifted)
        await loadDisplayedMonth()
    }

    private func ensureMonthLoaded(_ monthAnchor: Date, showsLoadingState: Bool = false) async throws {
        let monthKey = JourneyDateSupport.monthKey(for: monthAnchor)
        if momentCacheByMonth[monthKey] != nil { return }
        if loadingMonthKeys.contains(monthKey) { return }

        loadingMonthKeys.insert(monthKey)
        if showsLoadingState { isLoadingMonth = true }
        defer {
            loadingMonthKeys.remove(monthKey)
            if showsLoadingState { isLoadingMonth = false }
        }

        let bounds = JourneyDateSupport.monthBounds(for: monthAnchor)
        let moments = try await MomentService.shared.fetchMoments(
            userId: userId,
            from: bounds.start,
            toExclusive: bounds.endExclusive
        )
        momentCacheByMonth[monthKey] = deduplicateMomentsByDay(moments)
    }

    private func deduplicateMomentsByDay(_ moments: [CircleMoment]) -> [String: CircleMoment] {
        var result: [String: CircleMoment] = [:]
        for moment in moments {
            let dayKey = String(moment.postedAt.prefix(10))
            if result[dayKey] == nil {
                result[dayKey] = moment
            }
        }
        return result
    }

    private func rebuildDays() {
        let monthKey = JourneyDateSupport.monthKey(for: currentMonthAnchor)
        let monthMoments = momentCacheByMonth[monthKey] ?? [:]
        let dayCount = JourneyDateSupport.daysInMonth(for: currentMonthAnchor)

        days = (1...dayCount).compactMap { day in
            guard let date = JourneyDateSupport.dayDate(day: day, monthAnchor: currentMonthAnchor) else {
                return nil
            }

            let dayKey = JourneyDateSupport.dayKey(for: date)
            return JourneyDay(
                dayKey: dayKey,
                displayDateUTC: date,
                niyyah: niyyahsByDay[dayKey],
                moment: monthMoments[dayKey]
            )
        }
    }

    private func prefetchAdjacentMonths(around monthAnchor: Date) async {
        guard let previous = JourneyDateSupport.calendar.date(byAdding: .month, value: -1, to: monthAnchor),
              let next = JourneyDateSupport.calendar.date(byAdding: .month, value: 1, to: monthAnchor) else {
            return
        }

        try? await ensureMonthLoaded(previous)
        try? await ensureMonthLoaded(next)
    }
}
