import Foundation
import Observation

@Observable
@MainActor
final class JourneyViewModel {
    private struct CachedRestoreState {
        let restoredNiyyahs: Bool
        let restoredMonth: Bool

        var restoredAnyData: Bool { restoredNiyyahs || restoredMonth }
    }

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

    var detailDays: [JourneyDay] {
        days.filter { $0.hasNiyyah || $0.hasPostedMoment }
    }

    func loadInitial() async {
        guard !hasLoadedInitialData else {
            await refreshArchiveSummaryIfPossible()
            await loadDisplayedMonth()
            return
        }

        isLoadingInitial = true
        errorMessage = nil
        let restoreState = restoreInitialCache()

        if restoreState.restoredAnyData {
            hasLoadedInitialData = true
            rebuildDays()
            isLoadingInitial = false
        }

        do {
            try await refreshArchiveSummary()
            JourneyCache.saveNiyyahs(niyyahsByDay, userId: userId)
            hasLoadedInitialData = true
            rebuildDays()

            if restoreState.restoredMonth {
                await reloadMonth(currentMonthAnchor, showsError: false)
            } else {
                try await ensureMonthLoaded(
                    currentMonthAnchor,
                    showsLoadingState: !restoreState.restoredAnyData
                )
            }
            rebuildDays()

            Task { await prefetchAdjacentMonths(around: currentMonthAnchor) }
        } catch {
            rebuildDays()
            if !restoreState.restoredAnyData {
                errorMessage = "Could not load Journey right now."
            }
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
        let restoredFromDisk = restoreMonthFromDiskIfNeeded(currentMonthAnchor)
        rebuildDays()
        do {
            if restoredFromDisk {
                await reloadMonth(currentMonthAnchor, showsError: false)
            } else {
                let monthKey = JourneyDateSupport.monthKey(for: currentMonthAnchor)
                let alreadyLoaded = momentCacheByMonth[monthKey] != nil
                try await ensureMonthLoaded(
                    currentMonthAnchor,
                    showsLoadingState: !alreadyLoaded
                )
            }
            rebuildDays()
            Task { await prefetchAdjacentMonths(around: currentMonthAnchor) }
        } catch {
            errorMessage = "Could not load this month."
        }
    }

    func refreshOnAppear() async {
        guard hasLoadedInitialData else { return }

        await refreshArchiveSummaryIfPossible()
        rebuildDays()

        guard isViewingCurrentMonth else { return }
        await reloadMonth(currentMonthAnchor)
    }

    func handleMomentPostRefresh(_ event: MomentPostRefreshEvent) async {
        guard hasLoadedInitialData, event.userId == userId else { return }

        let todayMonth = JourneyDateSupport.monthAnchor(for: Date())
        invalidateMonth(todayMonth)
        await refreshArchiveSummaryIfPossible()
        rebuildDays()

        guard JourneyDateSupport.monthKey(for: currentMonthAnchor) == JourneyDateSupport.monthKey(for: todayMonth) else {
            return
        }

        await reloadMonth(currentMonthAnchor)
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
        JourneyCache.saveNiyyahs(niyyahsByDay, userId: userId)
    }

    private var isViewingCurrentMonth: Bool {
        JourneyDateSupport.monthKey(for: currentMonthAnchor) == JourneyDateSupport.monthKey(for: Date())
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
        if restoreMonthFromDiskIfNeeded(monthAnchor) { return }

        try await fetchMonthFromNetwork(monthAnchor, showsLoadingState: showsLoadingState)
    }

    private func fetchMonthFromNetwork(_ monthAnchor: Date, showsLoadingState: Bool) async throws {
        let monthKey = JourneyDateSupport.monthKey(for: monthAnchor)
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
        let deduplicated = deduplicateMomentsByDay(moments)
        momentCacheByMonth[monthKey] = deduplicated
        JourneyCache.saveMoments(deduplicated, monthKey: monthKey, userId: userId)
    }

    private func deduplicateMomentsByDay(_ moments: [CircleMoment]) -> [String: CircleMoment] {
        var result: [String: CircleMoment] = [:]
        for moment in moments {
            let dayKey = moment.momentDate
            if let existing = result[dayKey] {
                if moment.postedAt > existing.postedAt {
                    result[dayKey] = moment
                }
            } else {
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

    private func invalidateMonth(_ monthAnchor: Date) {
        let monthKey = JourneyDateSupport.monthKey(for: monthAnchor)
        momentCacheByMonth.removeValue(forKey: monthKey)
    }

    private func reloadMonth(_ monthAnchor: Date, showsError: Bool = true) async {
        invalidateMonth(monthAnchor)
        if showsError {
            errorMessage = nil
        }

        do {
            try await fetchMonthFromNetwork(monthAnchor, showsLoadingState: false)
            rebuildDays()
        } catch {
            if showsError {
                errorMessage = "Could not refresh Journey right now."
            }
        }
    }

    private func restoreInitialCache() -> CachedRestoreState {
        let restoredNiyyahs = restoreNiyyahsFromDiskIfNeeded()
        let restoredMonth = restoreMonthFromDiskIfNeeded(currentMonthAnchor)
        if restoredNiyyahs || restoredMonth {
            let monthKey = JourneyDateSupport.monthKey(for: currentMonthAnchor)
            let hasCachedMoments = !(momentCacheByMonth[monthKey] ?? [:]).isEmpty
            hasAnyEntries = !niyyahsByDay.isEmpty || hasCachedMoments
        }
        return CachedRestoreState(
            restoredNiyyahs: restoredNiyyahs,
            restoredMonth: restoredMonth
        )
    }

    private func restoreNiyyahsFromDiskIfNeeded() -> Bool {
        guard niyyahsByDay.isEmpty,
              let cachedNiyyahs = JourneyCache.loadNiyyahs(userId: userId) else {
            return false
        }
        niyyahsByDay = cachedNiyyahs
        return true
    }

    private func restoreMonthFromDiskIfNeeded(_ monthAnchor: Date) -> Bool {
        let monthKey = JourneyDateSupport.monthKey(for: monthAnchor)
        guard momentCacheByMonth[monthKey] == nil,
              let cachedMoments = JourneyCache.loadMoments(monthKey: monthKey, userId: userId) else {
            return false
        }
        momentCacheByMonth[monthKey] = cachedMoments
        return true
    }
}
