import SwiftUI

/// "Something else…" tile shared by the habit picker and struggle quiz screens.
/// Tapping flips the parent's `showCustomField` state to reveal a textfield.
struct QuizCustomRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(isSelected ? Color.msGold : Color.clear)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msGold)

                Text("Something else…")
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)

                Spacer()
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
