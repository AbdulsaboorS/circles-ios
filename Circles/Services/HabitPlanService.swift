import Foundation
import Observation
import Supabase

enum HabitPlanServiceError: LocalizedError {
    case refinementLimitReached
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .refinementLimitReached:
            return "Sorry, no more for now. AI tokens cost a lot! InshAllah try again next time."
        case .notAuthenticated:
            return "You need to be signed in."
        }
    }
}

@Observable
@MainActor
final class HabitPlanService {
    static let shared = HabitPlanService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Short alert copy for plan save / AI failures (Supabase schema, timeouts, etc.).
    static func userFacingMessage(from error: Error) -> String {
        if let urlErr = error as? URLError, urlErr.code == .timedOut {
            return "The AI request timed out. Check your connection and try again."
        }
        let localized = error.localizedDescription
        let blob = (localized + " " + String(describing: error)).lowercased()
        if blob.contains("milestones"), blob.contains("schema") || blob.contains("could not find") {
            return "Database setup: habit_plans is missing milestones or the API cache is stale. In Supabase SQL Editor, run habit_plans_align_app.sql (it notifies PostgREST to refresh). Wait a few seconds and try again — there is no “reload schema” button in Settings."
        }
        return localized
    }

    // MARK: - Read

    func fetchPlan(habitId: UUID, userId: UUID) async throws -> HabitPlan? {
        let rows: [HabitPlan] = try await client
            .from("habit_plans")
            .select()
            .eq("habit_id", value: habitId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Create / replace (initial generation — not counted as refinement)

    /// Inserts or replaces the plan row. Does not increment refinement_count (first-time roadmap).
    func upsertInitialPlan(habitId: UUID, userId: UUID, milestones: [HabitMilestone]) async throws -> HabitPlan {
        let row = HabitPlanUpsert(
            habit_id: habitId,
            user_id: userId,
            milestones: milestones,
            week_number: 1,
            refinement_count: 0,
            refinement_week: 0,
            refinement_cycle: ""
        )
        return try await client
            .from("habit_plans")
            .upsert(row, onConflict: "habit_id,user_id")
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Refine (server-enforced weekly cap)

    func applyRefinement(habitId: UUID, milestones: [HabitMilestone]) async throws -> HabitPlan {
        let params: [String: AnyJSON] = [
            "p_habit_id": .string(habitId.uuidString),
            "p_milestones": Self.milestonesAsAnyJSON(milestones)
        ]
        do {
            return try await client
                .rpc("apply_habit_plan_refinement", params: params)
                .execute()
                .value
        } catch {
            let msg = String(describing: error).lowercased()
            if msg.contains("refinement limit") || msg.contains("p0001") {
                throw HabitPlanServiceError.refinementLimitReached
            }
            throw error
        }
    }

    // MARK: - Onboarding / background

    /// Generate via Gemini and save initial plan; no-op if a plan already exists.
    func ensureAIRoadmapForOnboarding(habit: Habit, userId: UUID) async {
        do {
            if try await fetchPlan(habitId: habit.id, userId: userId) != nil { return }
            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: habit.planNotes,
                userRefinementRequest: nil
            )
            _ = try await upsertInitialPlan(habitId: habit.id, userId: userId, milestones: milestones)
        } catch {
            print("[HabitPlanService] ensureAIRoadmapForOnboarding failed: \(error)")
        }
    }

    private static func milestonesAsAnyJSON(_ milestones: [HabitMilestone]) -> AnyJSON {
        .array(
            milestones.map { m in
                .object([
                    "day": .double(Double(m.day)),
                    "title": .string(m.title),
                    "description": .string(m.description)
                ])
            }
        )
    }
}

// MARK: - Encodable row

private struct HabitPlanUpsert: Encodable, Sendable {
    let habit_id: UUID
    let user_id: UUID
    let milestones: [HabitMilestone]
    let week_number: Int
    let refinement_count: Int
    let refinement_week: Int
    let refinement_cycle: String
}
