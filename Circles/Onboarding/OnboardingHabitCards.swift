import SwiftUI

/// Single full-width row used by both the Amir shared-habits screen and the
/// quiz personal-habits screen. Tap the body to toggle selection. If
/// `onRemove` is provided, a trailing X removes the row from the parent's
/// list (used for custom-typed habits).
struct OnboardingHabitRow: View {
    let name: String
    let icon: String
    let rationale: String
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(isSelected ? Color.msBackground.opacity(0.6) : Color.clear)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.msBackground.opacity(0.15) : Color.msGold.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msGold)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)

                if !rationale.isEmpty {
                    Text(rationale)
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundStyle(isSelected
                                         ? Color.msBackground.opacity(0.78)
                                         : Color.msTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.msBackground)
            }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected
                                         ? Color.msBackground.opacity(0.55)
                                         : Color.msTextMuted.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.msGold : Color.msCardShared)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.msBorder, lineWidth: 1)
                )
        )
        .opacity(isDisabled ? 0.4 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if !isDisabled { onTap() }
        }
    }
}

/// Card-shaped slot that swaps between an "+ Add your own" prompt and an
/// inline editor. Card geometry mirrors `OnboardingHabitRow` so the slot
/// reads as another row in the list. On commit, calls `onCommit(text)` and
/// resets back to collapsed. Parent decides whether the new entry is added
/// selected or unselected.
struct OnboardingCustomHabitSlot: View {
    /// Predicate provided by parent — returns false if the trimmed text is
    /// empty or duplicates an existing entry. Used to gate the Add button.
    let canCommit: (String) -> Bool
    let onCommit: (String) -> Void
    var placeholder: String = "e.g. Tahajjud, Journaling…"

    @State private var isEditing: Bool = false
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCommittable: Bool {
        !trimmed.isEmpty && canCommit(trimmed)
    }

    var body: some View {
        Group {
            if isEditing {
                editingState
            } else {
                collapsedState
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.msCardShared.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: isEditing ? [] : [4, 4])
                        )
                        .foregroundStyle(Color.msGold.opacity(isEditing ? 0.5 : 0.35))
                )
        )
    }

    private var collapsedState: some View {
        Button {
            isEditing = true
            isFocused = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.msGold)
                Text("Add your own")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.msTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var editingState: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.msGold)
                .frame(width: 32, height: 32)
                .background(Color.msGold.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .foregroundStyle(Color.msTextPrimary)
                .tint(Color.msGold)
                .submitLabel(.done)
                .onSubmit { commitIfPossible() }

            Button {
                cancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.msTextMuted.opacity(0.7))
            }
            .buttonStyle(.plain)

            Button {
                commitIfPossible()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isCommittable ? Color.msGold : Color.msGold.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!isCommittable)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func commitIfPossible() {
        guard isCommittable else { return }
        onCommit(trimmed)
        text = ""
        isEditing = false
        isFocused = false
    }

    private func cancel() {
        text = ""
        isEditing = false
        isFocused = false
    }
}
