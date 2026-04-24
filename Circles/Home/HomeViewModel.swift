import Foundation
import Observation
import SwiftUI
import Supabase

@Observable
@MainActor
final class HomeViewModel {
    var habits: [Habit] = []
    var todayLogs: [HabitLog] = []
    var streak: Streak? = nil
    var computedStreak: Int = 0
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var circlePresence: [MemberPresence] = []

    private let todayString: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()

    // MARK: - MemberPresence

    struct MemberPresence: Identifiable, Sendable {
        let id: UUID
        let circleId: UUID
        let name: String
        let initials: String
        let avatarColor: Color
        let checkedInToday: Bool
    }

    // MARK: - Derived state

    func isCompleted(habitId: UUID) -> Bool {
        todayLogs.first { $0.habitId == habitId }?.completed ?? false
    }

    var circleCheckedInCount: Int { circlePresence.filter(\.checkedInToday).count }

    /// True only when every active habit has been completed today.
    var allHabitsCompleted: Bool {
        !habits.isEmpty && habits.allSatisfy { isCompleted(habitId: $0.id) }
    }

    // MARK: - Load

    func loadAll(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        // Presence loads concurrently (non-throwing, silently fails)
        Task { circlePresence = await fetchCirclePresence(userId: userId) }
        do {
            async let habitsFetch = HabitService.shared.fetchActiveHabits(userId: userId)
            async let logsFetch   = HabitService.shared.fetchTodayLogs(userId: userId, date: todayString)
            async let streakFetch = HabitService.shared.fetchStreak(userId: userId)
            habits    = try await habitsFetch
            todayLogs = try await logsFetch
            streak    = try await streakFetch
            computedStreak = await HabitToggleService.shared.computeAccountableStreak(userId: userId, habits: habits)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Circle Presence

    private func fetchCirclePresence(userId: UUID) async -> [MemberPresence] {
        do {
            let circles = try await CircleService.shared.fetchMyCircles(userId: userId)
            guard let circle = circles.first else { return [] }

            let members = try await CircleService.shared.fetchMembers(circleId: circle.id)
            let others  = members.filter { $0.userId != userId }
            guard !others.isEmpty else { return [] }

            let memberIdStrings = others.map { $0.userId.uuidString }

            // Batch fetch preferred names
            struct ProfileRow: Decodable {
                let id: UUID
                let preferred_name: String?
            }
            let profiles: [ProfileRow] = (try? await SupabaseService.shared.client
                .from("profiles")
                .select("id,preferred_name")
                .in("id", values: memberIdStrings)
                .execute()
                .value) ?? []
            let nameMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.preferred_name) })

            // Today's activity_feed entries for these members
            let todayISO = todayString + "T00:00:00"
            struct FeedRow: Decodable {
                let userId: UUID
                enum CodingKeys: String, CodingKey { case userId = "user_id" }
            }
            let feedRows: [FeedRow] = (try? await SupabaseService.shared.client
                .from("activity_feed")
                .select("user_id")
                .in("user_id", values: memberIdStrings)
                .gte("created_at", value: todayISO)
                .execute()
                .value) ?? []
            let checkedInIds = Set(feedRows.map { $0.userId })

            let palette: [Color] = [
                Color(hex: "4A7C59"), Color(hex: "5E9E72"),
                Color(hex: "3D6B4F"), Color(hex: "6B8F71"), Color(hex: "2D5A3D")
            ]
            return others.enumerated().map { idx, member in
                let name = nameMap[member.userId] ?? nil
                return MemberPresence(
                    id: member.userId,
                    circleId: circle.id,
                    name: name ?? "Member",
                    initials: makeInitials(from: name),
                    avatarColor: palette[idx % palette.count],
                    checkedInToday: checkedInIds.contains(member.userId)
                )
            }
        } catch {
            return []
        }
    }

    private func makeInitials(from name: String?) -> String {
        guard let name, !name.isEmpty else { return "M" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Toast (shown by HomeView)

    var toastMessage: String? = nil

    // Tracks check-in count per habit this session (resets on app kill — intentional)
    private var checkInCount: [UUID: Int] = [:]

    // MARK: - Delete (archive)

    func deleteHabit(_ habit: Habit) async {
        habits.removeAll { $0.id == habit.id }
        do {
            try await HabitService.shared.archiveHabit(habitId: habit.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Optimistic toggle

    func toggleHabit(_ habit: Habit, userId: UUID) async {
        let alreadyCompleted = isCompleted(habitId: habit.id)

        if alreadyCompleted {
            // Undo path — blocked once check-in count reaches 3
            let count = checkInCount[habit.id] ?? 1
            guard count < 3 else { return }

            // Optimistic undo
            if let idx = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
                todayLogs[idx].completed = false
            }

            do {
                let result = try await HabitToggleService.shared.toggleToday(
                    habit: habit,
                    userId: userId,
                    date: todayString,
                    alreadyCompleted: true
                )
                streak = result.streak
                computedStreak = result.computedStreak
            } catch {
                if let idx = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
                    todayLogs[idx].completed = true
                }
                errorMessage = error.localizedDescription
            }

        } else {
            // Check-in path
            let count = (checkInCount[habit.id] ?? 0) + 1
            checkInCount[habit.id] = count

            // Optimistic check-in
            if let idx = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
                todayLogs[idx].completed = true
            } else {
                todayLogs.append(HabitLog(
                    id: UUID(), habitId: habit.id, userId: userId,
                    date: todayString, completed: true, notes: nil, createdAt: Date()
                ))
            }

            // Progressive warnings
            if count == 2 {
                toastMessage = "pls stop doing and undoing. did u actually do it or not?? 😭"
            } else if count >= 3 {
                toastMessage = "Locked in. No more undos — we trust you this time. 🤝"
            }

            do {
                let result = try await HabitToggleService.shared.toggleToday(
                    habit: habit,
                    userId: userId,
                    date: todayString,
                    alreadyCompleted: false
                )
                streak = result.streak
                computedStreak = result.computedStreak
            } catch {
                if let idx = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
                    todayLogs[idx].completed = false
                }
                checkInCount[habit.id] = count - 1
                errorMessage = error.localizedDescription
            }
        }
    }
}
