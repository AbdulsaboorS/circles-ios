import SwiftUI
import Supabase

struct HabitDetailView: View {
    let habit: Habit

    @State private var logs: [HabitLog] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // Last 28 calendar days including today
    private var last28Days: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        return (0..<28).reversed().map { daysAgo -> String in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return formatter.string(from: date)
        }
    }

    private var twentyEightDaysAgoString: String {
        last28Days.first ?? ""
    }

    private func isCompleted(dateString: String) -> Bool {
        logs.first { $0.date == dateString }?.completed ?? false
    }

    private var totalCompletions: Int {
        logs.filter { $0.completed }.count
    }

    // Grid of 7 columns, 4 rows = 28 cells
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero card
                VStack(spacing: 8) {
                    Text(habit.icon)
                        .font(.system(size: 56))
                    Text(habit.name)
                        .font(.title.bold())
                    if let goal = habit.acceptedAmount, !goal.isEmpty {
                        Label(goal, systemImage: "target")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 16) {
                        StatBadge(label: "Completions", value: "\(totalCompletions)")
                        StatBadge(label: "Last 28 days", value: "\(totalCompletions)/28")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // 28-day calendar
                VStack(alignment: .leading, spacing: 12) {
                    Text("28-Day History")
                        .font(.headline)
                        .padding(.horizontal)

                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(last28Days, id: \.self) { dateStr in
                                VStack(spacing: 2) {
                                    SwiftUI.Circle()
                                        .fill(isCompleted(dateString: dateStr) ? Color.green : Color(.systemGray5))
                                        .frame(width: 32, height: 32)
                                    Text(dayNumber(from: dateStr))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchLogs()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func fetchLogs() async {
        isLoading = true
        errorMessage = nil
        do {
            // Intentional direct Supabase call — HabitService has no date-range-by-habitId method.
            // See plan 02-03 task 2 rationale for why this exception is acceptable here.
            let fetched: [HabitLog] = try await SupabaseService.shared.client
                .from("habit_logs")
                .select()
                .eq("habit_id", value: habit.id.uuidString)
                .gte("date", value: twentyEightDaysAgoString)
                .execute()
                .value
            logs = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func dayNumber(from dateString: String) -> String {
        // Extract day number from "yyyy-MM-dd" → "23", stripping leading zero
        let day = String(dateString.suffix(2))
        return day.hasPrefix("0") ? String(day.dropFirst()) : day
    }
}

private struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
