import SwiftUI
import PhotosUI
import Supabase

// MARK: - Milestone Model

struct Milestone: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let isUnlocked: Bool
}

// MARK: - ProfileViewModel

@Observable
@MainActor
final class ProfileViewModel {

    var profile: Profile?
    var totalDays: Int = 0
    var bestStreak: Int = 0
    var currentStreak: Int = 0
    var circleCount: Int = 0
    var ameensGiven: Int = 0
    var topHabits: [TopHabit] = []
    var isCircleFounder: Bool = false
    var avatarUrl: String? = nil
    var isLoadingStats: Bool = true
    var isUploadingAvatar: Bool = false
    var avatarUploadError: String? = nil

    var milestones: [Milestone] {
        [
            Milestone(id: "first_light",     title: "First Light",      subtitle: "7 days",        icon: "sunrise.fill",   isUnlocked: totalDays >= 7),
            Milestone(id: "forty_days",      title: "40 Days",          subtitle: "40 days",       icon: "moon.stars.fill",isUnlocked: totalDays >= 40),
            Milestone(id: "circle_founder",  title: "Circle Founder",   subtitle: "Led a circle",  icon: "person.3.fill",  isUnlocked: isCircleFounder),
            Milestone(id: "hundred_days",    title: "100 Days",         subtitle: "100 days",      icon: "star.fill",      isUnlocked: totalDays >= 100),
            Milestone(id: "laylatul_qadr",   title: "Laylatul Qadr",    subtitle: "27-day streak", icon: "sparkles",       isUnlocked: bestStreak >= 27),
        ]
    }

    func loadAll(userId: UUID) async {
        isLoadingStats = true
        async let profileFetch   = AvatarService.shared.fetchProfile(userId: userId)
        async let daysFetch      = AvatarService.shared.fetchTotalCompletedDays(userId: userId)
        async let streakFetch    = HabitService.shared.fetchStreak(userId: userId)
        async let circlesFetch   = AvatarService.shared.fetchCircleCount(userId: userId)
        async let ameeensFetch   = AvatarService.shared.fetchReactionsGivenCount(userId: userId)
        async let topHabitsFetch = HabitService.shared.fetchTopHabits(userId: userId)
        async let founderFetch   = AvatarService.shared.fetchIsCircleFounder(userId: userId)

        profile          = try? await profileFetch
        avatarUrl        = profile?.avatarUrl
        totalDays        = (try? await daysFetch) ?? 0
        let streak       = try? await streakFetch
        bestStreak       = streak?.longestStreak ?? 0
        currentStreak    = streak?.currentStreak ?? 0
        circleCount      = (try? await circlesFetch) ?? 0
        ameensGiven      = (try? await ameeensFetch) ?? 0
        topHabits        = (try? await topHabitsFetch) ?? []
        isCircleFounder  = (try? await founderFetch) ?? false
        isLoadingStats   = false
    }

    func handleAvatarPick(_ item: PhotosPickerItem, userId: UUID) async {
        isUploadingAvatar = true
        avatarUploadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AvatarError.imageConversionFailed
            }
            guard let image = UIImage(data: data) else {
                throw AvatarError.imageConversionFailed
            }
            avatarUrl = try await AvatarService.shared.uploadAvatar(userId: userId, image: image)
        } catch {
            print("[ProfileViewModel] Avatar upload failed: \(error)")
            avatarUploadError = error.localizedDescription
        }
        isUploadingAvatar = false
    }

    func saveProfileName(_ name: String, userId: UUID) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let updates: [String: AnyJSON] = ["preferred_name": .string(trimmed)]
            try await SupabaseService.shared.client
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()
            profile?.preferredName = trimmed
        } catch {
            print("[ProfileViewModel] Save name failed: \(error)")
        }
    }
}
