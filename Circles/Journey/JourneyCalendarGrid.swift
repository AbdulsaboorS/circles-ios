import SwiftUI

struct JourneyCalendarGrid: View {
    let monthAnchor: Date
    let weekdaySymbols: [String]
    let leadingEmptyCellCount: Int
    let days: [JourneyDay]
    let onSelectDay: (JourneyDay) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<leadingEmptyCellCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                ForEach(days) { day in
                    JourneyDayCell(day: day) {
                        onSelectDay(day)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: JourneyDateSupport.monthKey(for: monthAnchor))
    }

    private var weekdayHeader: some View {
        HStack(spacing: 10) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(Color.msTextMuted.opacity(0.8))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct JourneyDayCell: View {
    let day: JourneyDay
    let onTap: () -> Void

    private var isToday: Bool {
        JourneyDateSupport.isToday(day.displayDateUTC)
    }

    private var isInteractive: Bool {
        day.hasNiyyah || day.hasPostedMoment
    }

    private var dayNumber: Int {
        JourneyDateSupport.calendar.component(.day, from: day.displayDateUTC)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(backgroundFill)

                if day.hasNiyyah {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .blur(radius: 10)
                        .offset(x: -16, y: -16)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 17, weight: day.hasNiyyah ? .semibold : .medium, design: .serif))
                    .foregroundStyle(numberColor)

                if day.hasNiyyah || day.hasPostedMoment {
                    VStack {
                        HStack {
                            Spacer()
                            SwiftUI.Circle()
                                .fill(day.hasNiyyah ? Color.msGold : Color.msTextMuted.opacity(0.75))
                                .frame(width: 6, height: 6)
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(borderColor, lineWidth: day.hasNiyyah ? 1.2 : 1)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.msTextMuted.opacity(0.55), lineWidth: 1)
                        .padding(-3)
                }
            }
            .shadow(color: day.hasNiyyah ? Color.msGold.opacity(0.12) : .clear, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isInteractive ? [.isButton] : [])
    }

    private var backgroundFill: some ShapeStyle {
        if day.hasNiyyah {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.msGold.opacity(0.20), Color.msCardWarm.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if day.hasPostedMoment {
            return AnyShapeStyle(Color.msCardShared.opacity(0.9))
        }

        return AnyShapeStyle(Color.msBackgroundDeep.opacity(0.72))
    }

    private var borderColor: Color {
        if day.hasNiyyah { return Color.msGold.opacity(0.35) }
        if day.hasPostedMoment { return Color.msBorder }
        return Color.white.opacity(0.05)
    }

    private var numberColor: Color {
        if day.hasNiyyah { return Color.msTextPrimary }
        if day.hasPostedMoment { return Color.msTextPrimary.opacity(0.92) }
        return Color.msTextMuted.opacity(0.85)
    }

    private var accessibilityLabel: String {
        let date = JourneyDateSupport.formattedDate(for: day.displayDateUTC)
        if day.hasNiyyah { return "\(date), has niyyah and moment detail" }
        if day.hasPostedMoment { return "\(date), has moment detail" }
        return date
    }
}
