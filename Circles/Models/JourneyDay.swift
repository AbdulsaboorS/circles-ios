import Foundation

/// A single canonical archive day in Journey.
/// `dayKey` is the stored UTC bucket used by both niyyahs and deduplicated moments.
struct JourneyDay: Identifiable, Sendable {
    let dayKey: String
    let displayDateUTC: Date
    let niyyah: MomentNiyyah?
    let moment: CircleMoment?

    var id: String { dayKey }
    var hasNiyyah: Bool { niyyah != nil }
    var hasPostedMoment: Bool { moment != nil }
}
