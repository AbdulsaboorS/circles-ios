import Foundation
import SwiftUI

/// Enriched data bundle for a single circle card in the Stage carousel.
struct CircleCardData: Identifiable, Sendable {
    let id: UUID  // == circle.id
    let circle: Circle
    let members: [CircleCardMember]
    let latestActivity: LatestActivityInfo?
    let latestMoment: LatestMomentInfo?
    let activeUserIdsToday: Set<UUID>
    var nudgeSentCountToday: Int

    private var memberWord: String {
        switch circle.genderSettingSafe {
        case "brothers": return "brother"
        case "sisters": return "sister"
        default: return "member"
        }
    }

    private var memberWordPlural: String {
        switch circle.genderSettingSafe {
        case "brothers": return "brothers"
        case "sisters": return "sisters"
        default: return "members"
        }
    }

    var totalMemberCount: Int { members.count }

    var quietMembers: [CircleCardMember] {
        members.filter { !activeUserIdsToday.contains($0.id) }
    }

    var encouragementTargets: [CircleCardMember] {
        quietMembers.filter { !$0.isCurrentUser }
    }

    var activeCountToday: Int { activeUserIdsToday.count }

    var primaryHero: CircleCardMember? {
        if let latestMoment,
           let member = members.first(where: { $0.id == latestMoment.userId }) {
            return member
        }
        if let latestActivity,
           let member = members.first(where: { $0.id == latestActivity.userId }) {
            return member
        }
        return quietMembers.first ?? members.first
    }

    var supportingMembers: [CircleCardMember] {
        let heroId = primaryHero?.id
        return members.filter { $0.id != heroId }
    }

    var pulseDotColor: Color {
        guard let timestamp = latestSignalTimestamp,
              let date = Self.date(from: timestamp)
        else { return .gray }

        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 7200 { return .green }
        if elapsed < 86400 { return Color.msGold }
        return .gray
    }

    var momentumLabel: String {
        let streak = circle.groupStreakDaysSafe
        switch streak {
        case 0: return "New circle"
        case 1: return "1 day streak"
        default: return "\(streak) day streak"
        }
    }

    var headline: String {
        if let latestMoment {
            return "\(latestMoment.userName) posted a Moment"
        }
        if let latestActivity {
            switch latestActivity.eventType {
            case "streak_milestone":
                if let days = latestActivity.streakDays {
                    return "\(latestActivity.userName) hit \(days) days"
                }
            case "habit_checkin":
                if let habitName = latestActivity.habitName, !habitName.isEmpty {
                    return "\(latestActivity.userName) checked in to \(habitName)"
                }
                return "\(latestActivity.userName) checked in"
            default:
                break
            }
        }
        let quietCount = quietMembers.count
        if quietCount <= 1 {
            return "Your circle is waiting on each other"
        }
        return "\(quietCount) \(memberWordPlural) are still quiet today"
    }

    var supportingLine: String {
        if let latestMoment {
            return "\(Self.relativeTimestamp(latestMoment.postedAt)) • \(activeSummary)"
        }
        if let latestActivity {
            return "\(Self.relativeTimestamp(latestActivity.timestamp)) • \(activeSummary)"
        }
        if let firstQuiet = quietMembers.first {
            let name = firstQuiet.shortName
            if quietMembers.count == 1 {
                return "\(name) could use encouragement."
            }
            return "\(name) + \(quietMembers.count - 1) more could use encouragement."
        }
        return "Open the circle and get the momentum going."
    }

    var compactLine: String {
        if let latestMoment {
            return "\(latestMoment.userName) posted • \(Self.relativeTimestamp(latestMoment.postedAt))"
        }
        if let latestActivity {
            switch latestActivity.eventType {
            case "streak_milestone":
                if let days = latestActivity.streakDays {
                    return "\(latestActivity.userName) hit \(days) days"
                }
            case "habit_checkin":
                return "\(latestActivity.userName) checked in"
            default:
                break
            }
        }
        return activeSummary
    }

    var activeSummary: String {
        switch activeCountToday {
        case 0:
            return "Quiet today"
        case 1:
            return "1 of \(max(1, totalMemberCount)) \(memberWord) active"
        default:
            return "\(activeCountToday) of \(max(1, totalMemberCount)) \(memberWordPlural) active"
        }
    }

    var heroImageURL: String? {
        latestMoment?.photoUrl
    }

    var heroCaption: String? {
        latestMoment?.caption
    }

    var statusLabel: String {
        guard let timestamp = latestSignalTimestamp,
              let date = Self.date(from: timestamp)
        else { return "Quiet today" }

        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 7200 { return "Live now" }
        if elapsed < 86400 { return "Active today" }
        return "Quieting down"
    }

    var showEncourageCTA: Bool {
        !encouragementTargets.isEmpty && nudgeSentCountToday < 2
    }

    var encourageTitle: String {
        let count = min(encouragementTargets.count, 2)
        return count > 1 ? "Encourage \(count)" : "Send Nudge"
    }

    var nudgeTargetIds: [UUID] {
        Array(encouragementTargets.prefix(2).map(\.id))
    }

    var latestSignalTimestamp: String? {
        switch (latestMoment?.postedAt, latestActivity?.timestamp) {
        case let (moment?, activity?):
            return moment >= activity ? moment : activity
        case let (moment?, nil):
            return moment
        case let (nil, activity?):
            return activity
        case (nil, nil):
            return nil
        }
    }

    private static func date(from iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)
    }

    static func relativeTimestamp(_ iso: String) -> String {
        guard let date = date(from: iso) else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(max(1, Int(diff / 60)))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}

struct CircleCardMember: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let avatarUrl: String?
    let isCurrentUser: Bool

    var shortName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Someone" }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).first ?? trimmed
    }
}

/// Lightweight info about the most recent activity in a circle.
struct LatestActivityInfo: Sendable {
    let userName: String
    let userId: UUID
    let eventType: String    // "habit_checkin" | "streak_milestone"
    let habitName: String?
    let streakDays: Int?
    let timestamp: String    // ISO8601
}

/// Lightweight info about the most recent Moment in a circle.
struct LatestMomentInfo: Sendable {
    let id: UUID
    let userId: UUID
    let userName: String
    let photoUrl: String
    let caption: String?
    let postedAt: String
}
