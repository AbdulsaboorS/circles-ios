import SwiftUI

struct CommonIntentionsSection: View {
    let topHabits: [TopHabit]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("COMMON INTENTIONS")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color.msTextMuted)

            Text("What your heart returns to most")
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.msTextPrimary.opacity(0.6))
                .padding(.top, 3)

            if topHabits.isEmpty {
                emptyState
                    .padding(.top, 16)
            } else {
                pillsRow
                    .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pillsRow: some View {
        // Wrap pills using a flow-style layout
        FlowLayout(spacing: 8) {
            ForEach(topHabits, id: \.name) { habit in
                intentionPill(habit)
            }
        }
    }

    private func intentionPill(_ habit: TopHabit) -> some View {
        Text(habit.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.msGold)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.msGold.opacity(0.12)))
            .overlay(Capsule().stroke(Color.msGold.opacity(0.35), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.msGold.opacity(0.5))
            Text("Your intentions will appear as you build your practice")
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Flow Layout

/// Simple wrapping horizontal layout for pills.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > containerWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: containerWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
