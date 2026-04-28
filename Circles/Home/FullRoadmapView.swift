import SwiftUI

/// Full 28-day roadmap, pushed as a `NavigationLink` destination from
/// `HabitDetailView`'s Today's Focus card. Was previously a `.sheet`-hosted
/// view inside `HabitDetailView`; promoted to a standalone push target so the
/// back-button returns to habit detail instead of dismissing a modal.
struct FullRoadmapView: View {
    let habit: Habit
    @State var plan: HabitPlan?
    /// Called when the user applies a refinement so the caller can refresh its
    /// own cached `plan`. Receives the new plan (or nil if unchanged).
    var onPlanChanged: ((HabitPlan) -> Void)? = nil

    @Environment(AuthManager.self) private var auth

    @State private var expandedWeeks: Set<Int> = [1, 2, 3, 4]
    @State private var editingMilestone: HabitMilestone?
    @State private var showRefineSheet = false
    @State private var isRefining = false
    @State private var isSavingMilestone = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let plan {
                        ForEach(1...4, id: \.self) { week in
                            let days = plan.milestones.filter {
                                plan.displayWeek(forMilestoneDay: $0.day) == week
                            }
                            if !days.isEmpty {
                                weekSection(week: week, days: days, plan: plan)
                            }
                        }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView().tint(Color.msGold)
                            Spacer()
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(16)
            }

            if isRefining {
                Color.black.opacity(0.28).ignoresSafeArea()
                ProgressView("Updating roadmap…")
                    .tint(Color.msGold)
                    .padding(24)
                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.msBorder, lineWidth: 1))
            }

            if isSavingMilestone {
                Color.black.opacity(0.18).ignoresSafeArea()
                ProgressView("Saving edit…")
                    .tint(Color.msGold)
                    .padding(24)
                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.msBorder, lineWidth: 1))
            }
        }
        .navigationTitle("28-Day Roadmap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if plan != nil {
                    Button("Refine") {
                        if plan?.isRefinementLimitReached == true {
                            errorMessage = HabitPlanServiceError.refinementLimitReached.errorDescription
                        } else {
                            showRefineSheet = true
                        }
                    }
                    .foregroundStyle(plan?.isRefinementLimitReached == true ? Color.msTextMuted : Color.msGold)
                    .disabled(isRefining || isSavingMilestone)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showRefineSheet) {
            RefinePlanSheet(
                isRefining: $isRefining,
                onRefine: { note in await refineWithAI(userNote: note) }
            )
        }
        .sheet(item: $editingMilestone) { milestone in
            EditMilestoneSheet(milestone: milestone) { updated in applyMilestoneEdit(updated) }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func weekSection(week: Int, days: [HabitMilestone], plan: HabitPlan) -> some View {
        let isExpanded = expandedWeeks.contains(week)
        let hasToday = days.contains { plan.isMilestoneToday(day: $0.day) }

        VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded { expandedWeeks.remove(week) } else { expandedWeeks.insert(week) }
            } label: {
                HStack {
                    Text("Week \(week)")
                        .font(.appCaptionMedium)
                        .foregroundStyle(hasToday ? Color.msGold : Color.msTextMuted)
                    if hasToday {
                        Text("Current")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.msBackground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.msGold, in: Capsule())
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.msTextMuted)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasToday ? Color.msGold.opacity(0.4) : Color.msBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(days) { m in milestoneRow(plan: plan, milestone: m) }
                }
                .padding(.top, 8)
            }
        }
    }

    private func milestoneRow(plan: HabitPlan, milestone: HabitMilestone) -> some View {
        let today = plan.isMilestoneToday(day: milestone.day)
        let dateLabel: String = {
            guard let s = plan.calendarDateString(forMilestoneDay: milestone.day) else { return "" }
            let parts = s.split(separator: "-")
            guard parts.count == 3 else { return s }
            return "\(parts[1])/\(parts[2])"
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Day \(milestone.day)")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.msTextMuted)
                Text(dateLabel)
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted.opacity(0.7))
                if today {
                    Text("Today")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.msBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.msGold, in: Capsule())
                }
                Spacer()
                Button {
                    editingMilestone = milestone
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.msTextMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(isSavingMilestone)
            }
            Text(milestone.title)
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextPrimary)
            Text(milestone.description)
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(today ? Color.msGold.opacity(0.10) : Color.msCardDeep)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(today ? Color.msGold.opacity(0.35) : Color.msBorder, lineWidth: 1)
        )
    }

    // MARK: - Mutations

    private func applyMilestoneEdit(_ updated: HabitMilestone) {
        guard let previousPlan = plan,
              let idx = previousPlan.milestones.firstIndex(where: { $0.day == updated.day }) else { return }
        var updatedPlan = previousPlan
        updatedPlan.milestones[idx] = updated
        plan = updatedPlan
        onPlanChanged?(updatedPlan)
        Task {
            isSavingMilestone = true
            defer { isSavingMilestone = false }
            do {
                try await HabitPlanService.shared.updateMilestones(
                    planId: updatedPlan.id,
                    milestones: updatedPlan.milestones
                )
            } catch {
                plan = previousPlan
                onPlanChanged?(previousPlan)
                errorMessage = "Couldn't save your roadmap edit. Try again."
            }
        }
    }

    private func refineWithAI(userNote: String?) async {
        guard plan != nil else { return }
        isRefining = true
        errorMessage = nil
        defer { isRefining = false }
        do {
            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: habit.planNotes,
                userRefinementRequest: userNote
            )
            let refreshed = try await HabitPlanService.shared.applyRefinement(
                habitId: habit.id,
                milestones: milestones
            )
            plan = refreshed
            onPlanChanged?(refreshed)
            showRefineSheet = false
        } catch let e as HabitPlanServiceError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = HabitPlanService.userFacingMessage(from: error)
        }
    }
}

// MARK: - Refine sheet (moved from HabitDetailView)

struct RefinePlanSheet: View {
    @Binding var isRefining: Bool
    var onRefine: (String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tell the coach what to change (optional). We'll regenerate all 28 days.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                    TextField("e.g. I can only practice on weekdays…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundStyle(Color.msTextPrimary)
                        .padding(12)
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                        .tint(Color.msGold)
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Refine plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                        .disabled(isRefining)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refine with AI") {
                        Task {
                            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                            dismiss()
                            await onRefine(trimmed.isEmpty ? nil : trimmed)
                        }
                    }
                    .foregroundStyle(Color.msGold)
                    .disabled(isRefining)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit milestone sheet (moved from HabitDetailView)

struct EditMilestoneSheet: View {
    let milestone: HabitMilestone
    var onSave: (HabitMilestone) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var desc: String

    init(milestone: HabitMilestone, onSave: @escaping (HabitMilestone) -> Void) {
        self.milestone = milestone
        self.onSave = onSave
        _title = State(initialValue: milestone.title)
        _desc = State(initialValue: milestone.description)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Day \(milestone.day)")
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.msGold)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                        TextField("Title", text: $title)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(12)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                            .tint(Color.msGold)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                        TextField("Description", text: $desc, axis: .vertical)
                            .lineLimit(3...8)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(12)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                            .tint(Color.msGold)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Day \(milestone.day)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = milestone
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.description = desc.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                        dismiss()
                    }
                    .foregroundStyle(Color.msGold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
