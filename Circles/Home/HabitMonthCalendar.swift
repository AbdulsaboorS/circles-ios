import SwiftUI

/// Monthly calendar heatmap for a single habit's check-ins. View-only — no
/// tap-to-log. Gold fill = completed day; gold ring = today (not done);
/// solid gold = today (done); outside-month days dimmed.
struct HabitMonthCalendar: View {
    /// Year-month currently rendered. Bound so the parent can page months.
    @Binding var displayedMonth: Date
    /// Full history of logs for this habit (not just the 28-day window).
    let logs: [HabitLog]
    /// "yyyy-MM-dd" for today, injected so the grid follows the same clock
    /// everyone else in the view uses.
    let todayString: String

    private var calendar: Calendar { Calendar.current }
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    /// Weekday symbols rotated to match `calendar.firstWeekday`.
    private var weekdaySymbols: [String] {
        let raw = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1   // Calendar is 1-indexed
        return Array(raw[first...] + raw[..<first])
    }

    /// Every cell the grid needs: 6 weeks × 7 days = 42 cells, anchored on the
    /// first-of-month and padded with prev/next month dates.
    private var gridDates: [Date] {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let firstWeekdayIndex = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -firstWeekdayIndex, to: firstOfMonth)
        else { return [] }
        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    private var completedDates: Set<String> {
        Set(logs.filter(\.completed).map(\.date))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.msTextMuted.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(gridDates, id: \.self) { date in
                    dayCell(for: date)
                }
            }
        }
        .padding(16)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.msBorder, lineWidth: 1))
    }

    private var header: some View {
        HStack {
            Button {
                guard let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
                displayedMonth = prev
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.msGold)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            Spacer()

            Button {
                guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
                displayedMonth = next
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.msGold)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dateStr = dateFormatter.string(from: date)
        let inDisplayedMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isFuture = dateStr > todayString
        let isToday = dateStr == todayString
        let isCompleted = completedDates.contains(dateStr)
        let dayNum = calendar.component(.day, from: date)

        ZStack {
            if isCompleted {
                SwiftUI.Circle()
                    .fill(Color.msGold)
                    .shadow(color: Color.msGold.opacity(0.4), radius: 4)
                Text("\(dayNum)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msBackground)
            } else if isToday {
                SwiftUI.Circle()
                    .stroke(Color.msGold, lineWidth: 1.5)
                Text("\(dayNum)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msGold)
            } else {
                Text("\(dayNum)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(inDisplayedMonth
                                     ? Color.msTextPrimary.opacity(isFuture ? 0.35 : 0.75)
                                     : Color.msTextMuted.opacity(0.25))
            }
        }
        .frame(height: 32)
        .opacity(inDisplayedMonth ? 1.0 : 0.35)
    }
}
