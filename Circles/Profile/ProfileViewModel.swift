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

struct ProfileEditDraft: Equatable, Sendable {
    var preferredName: String
    var gender: String?
    var avatarUrl: String?
    var cityName: String
    var timezone: String?
    var latitude: Double?
    var longitude: Double?

    var isValid: Bool {
        !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
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
    var nudgesSent: Int = 0
    var topHabits: [TopHabit] = []
    var isCircleFounder: Bool = false
    var avatarUrl: String? = nil
    var isLoadingStats: Bool = true
    var isUploadingAvatar: Bool = false
    var avatarUploadError: String? = nil
    var saveError: String? = nil

    var milestones: [Milestone] {
        [
            Milestone(id: "first_light",     title: "First Light",      subtitle: "7 days",        icon: "sunrise.fill",    isUnlocked: totalDays >= 7),
            Milestone(id: "forty_days",      title: "40 Days",          subtitle: "40 days",       icon: "moon.stars.fill", isUnlocked: totalDays >= 40),
            Milestone(id: "circle_founder",  title: "Circle Founder",   subtitle: "Led a circle",  icon: "person.3.fill",   isUnlocked: isCircleFounder),
            Milestone(id: "hundred_days",    title: "100 Days",         subtitle: "100 days",      icon: "star.fill",       isUnlocked: totalDays >= 100),
            Milestone(id: "laylatul_qadr",   title: "Laylatul Qadr",    subtitle: "27-day streak", icon: "sparkles",        isUnlocked: bestStreak >= 27),
        ]
    }

    func loadAll(userId: UUID) async {
        isLoadingStats = true
        async let profileFetch   = AvatarService.shared.fetchProfile(userId: userId)
        async let daysFetch      = AvatarService.shared.fetchTotalCompletedDays(userId: userId)
        async let streakFetch    = HabitService.shared.fetchStreak(userId: userId)
        async let circlesFetch   = AvatarService.shared.fetchCircleCount(userId: userId)
        async let nudgesFetch    = NudgeService.shared.fetchLifetimeSentCount(userId: userId)
        async let topHabitsFetch = HabitService.shared.fetchTopHabits(userId: userId)
        async let founderFetch   = AvatarService.shared.fetchIsCircleFounder(userId: userId)

        profile = try? await profileFetch
        avatarUrl = profile?.avatarUrl
        totalDays = (try? await daysFetch) ?? 0
        let streak = try? await streakFetch
        bestStreak = streak?.longestStreak ?? 0
        currentStreak = streak?.currentStreak ?? 0
        circleCount = (try? await circlesFetch) ?? 0
        nudgesSent = (try? await nudgesFetch) ?? 0
        topHabits = (try? await topHabitsFetch) ?? []
        isCircleFounder = (try? await founderFetch) ?? false
        isLoadingStats = false
    }

    func applyNudgeSentIncrement(_ sentCount: Int) {
        guard sentCount > 0 else { return }
        nudgesSent += sentCount
    }

    func makeEditDraft(fallbackName: String) -> ProfileEditDraft {
        ProfileEditDraft(
            preferredName: profile?.preferredName ?? fallbackName,
            gender: profile?.gender,
            avatarUrl: avatarUrl,
            cityName: profile?.cityName ?? "",
            timezone: profile?.timezone,
            latitude: profile?.latitude,
            longitude: profile?.longitude
        )
    }

    func handleAvatarPick(_ item: PhotosPickerItem, userId: UUID) async -> String? {
        isUploadingAvatar = true
        avatarUploadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AvatarError.imageConversionFailed
            }
            guard let image = UIImage(data: data) else {
                throw AvatarError.imageConversionFailed
            }
            let updatedAvatarUrl = try await AvatarService.shared.uploadAvatar(userId: userId, image: image)
            avatarUrl = updatedAvatarUrl
            profile?.avatarUrl = updatedAvatarUrl
            isUploadingAvatar = false
            return updatedAvatarUrl
        } catch {
            print("[ProfileViewModel] Avatar upload failed: \(error)")
            avatarUploadError = error.localizedDescription
            isUploadingAvatar = false
            return nil
        }
    }

    func saveProfile(_ draft: ProfileEditDraft, userId: UUID) async -> Bool {
        let trimmedName = draft.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        saveError = nil

        do {
            let updates: [String: AnyJSON] = [
                "preferred_name": .string(trimmedName),
                "gender": draft.gender.map(AnyJSON.string) ?? .null,
                "city_name": draft.cityName.isEmpty ? .null : .string(draft.cityName),
                "timezone": draft.timezone.map(AnyJSON.string) ?? .null,
                "latitude": draft.latitude.map(AnyJSON.double) ?? .null,
                "longitude": draft.longitude.map(AnyJSON.double) ?? .null
            ]

            try await SupabaseService.shared.client
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()

            if profile == nil {
                profile = Profile(
                    id: userId,
                    preferredName: trimmedName,
                    gender: draft.gender,
                    avatarUrl: draft.avatarUrl,
                    cityName: draft.cityName.isEmpty ? nil : draft.cityName,
                    timezone: draft.timezone,
                    latitude: draft.latitude,
                    longitude: draft.longitude
                )
            } else {
                profile?.preferredName = trimmedName
                profile?.gender = draft.gender
                profile?.avatarUrl = draft.avatarUrl
                profile?.cityName = draft.cityName.isEmpty ? nil : draft.cityName
                profile?.timezone = draft.timezone
                profile?.latitude = draft.latitude
                profile?.longitude = draft.longitude
            }

            avatarUrl = draft.avatarUrl
            return true
        } catch {
            print("[ProfileViewModel] Save profile failed: \(error)")
            saveError = error.localizedDescription
            return false
        }
    }
}
