import SwiftUI

/// Amir-only sheet: edit core habits, gender setting, remove members.
struct AmirCircleSettingsView: View {
    @Binding var circle: Circle
    @Binding var members: [CircleMember]
    @Binding var memberProfiles: [UUID: Profile]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedHabits: Set<String> = []
    @State private var genderSetting: String = "mixed"
    @State private var descriptionText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var memberToRemove: CircleMember?

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    private var canSelectMoreHabits: Bool { selectedHabits.count < 3 }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.darkBackground : Color.lightBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.textSecondary)
                            TextField("What is this circle about?", text: $descriptionText, axis: .vertical)
                                .font(.appSubheadline)
                                .foregroundStyle(colors.textPrimary)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(
                                    colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.8),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accent.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Circle setting")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.textSecondary)
                            HStack(spacing: 8) {
                                ForEach([("Mixed", "mixed"), ("Brothers", "brothers"), ("Sisters", "sisters")], id: \.1) { label, value in
                                    Button {
                                        genderSetting = value
                                    } label: {
                                        Text(label)
                                            .font(.appCaptionMedium)
                                            .foregroundStyle(genderSetting == value ? .white : colors.textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                genderSetting == value ? Color.accent : Color.accent.opacity(0.12),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Core habits")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.textSecondary)
                            Text("Choose up to 3 habits your circle tracks together.")
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary.opacity(0.85))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(AmiirOnboardingCoordinator.curatedHabits, id: \.name) { habit in
                                    let isSelected = selectedHabits.contains(habit.name)
                                    let isDisabled = !isSelected && !canSelectMoreHabits
                                    Button {
                                        if isSelected {
                                            selectedHabits.remove(habit.name)
                                        } else if canSelectMoreHabits {
                                            selectedHabits.insert(habit.name)
                                        }
                                    } label: {
                                        SettingsHabitTile(
                                            name: habit.name,
                                            icon: habit.icon,
                                            isSelected: isSelected,
                                            isDisabled: isDisabled
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isDisabled)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Members")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.textSecondary)

                            ForEach(members.filter { $0.role != "admin" }) { member in
                                HStack(spacing: 12) {
                                    AvatarView(
                                        avatarUrl: memberProfiles[member.userId]?.avatarUrl,
                                        name: memberDisplayName(member),
                                        size: 40
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(memberDisplayName(member))
                                            .font(.appSubheadline)
                                            .foregroundStyle(colors.textPrimary)
                                        Text("Member")
                                            .font(.appCaption)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        memberToRemove = member
                                    } label: {
                                        Text("Remove")
                                            .font(.appCaptionMedium)
                                            .foregroundStyle(.red.opacity(0.9))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 8)
                            }

                            if members.allSatisfy({ $0.role == "admin" }) {
                                Text("No other members yet. Share your invite link to grow the circle.")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.appCaption)
                                .foregroundStyle(.red.opacity(0.9))
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Circle settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || selectedHabits.isEmpty)
                }
            }
            .onAppear {
                selectedHabits = Set(circle.coreHabitsSafe)
                genderSetting = circle.genderSettingSafe
                descriptionText = circle.description ?? ""
            }
            .confirmationDialog(
                "Remove this member from the circle?",
                isPresented: Binding(
                    get: { memberToRemove != nil },
                    set: { if !$0 { memberToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let m = memberToRemove {
                        Task { await removeMember(m) }
                    }
                }
                Button("Cancel", role: .cancel) { memberToRemove = nil }
            }
        }
    }

    private func memberDisplayName(_ member: CircleMember) -> String {
        if let n = memberProfiles[member.userId]?.preferredName, !n.isEmpty { return n }
        return String(member.userId.uuidString.prefix(8)) + "…"
    }

    private func save() async {
        guard !selectedHabits.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let habits = Array(selectedHabits).sorted()
        do {
            let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = try await CircleService.shared.updateCircleSettings(
                circleId: circle.id,
                coreHabits: habits,
                genderSetting: genderSetting,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc
            )
            circle = updated
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeMember(_ member: CircleMember) async {
        errorMessage = nil
        defer { memberToRemove = nil }
        do {
            try await CircleService.shared.removeMember(circleId: circle.id, userId: member.userId)
            members.removeAll { $0.id == member.id }
            memberProfiles[member.userId] = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Tile (matches Amiir onboarding styling)

private struct SettingsHabitTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accent : Color.accent.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : Color.accent)
            }
            Text(name)
                .font(.appSubheadline)
                .foregroundStyle(isSelected ? Color.accent : (colorScheme == .dark ? Color.darkTextPrimary : Color.lightTextPrimary))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accent)
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(
            isSelected
                ? Color.accent.opacity(0.1)
                : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.8)),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 1.5)
        )
        .opacity(isDisabled ? 0.45 : 1)
    }
}
