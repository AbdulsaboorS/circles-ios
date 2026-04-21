import SwiftUI

/// A full-width row with a gold left-border highlight when selected,
/// matching the style of familiarity rows in `AddPrivateIntentionSheet`.
struct QuizChoiceRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(isSelected ? Color.msGold : Color.clear)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Text(label)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.msBackground)
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.msGold : Color.msCardShared)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : Color.msBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
