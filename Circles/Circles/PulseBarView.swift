import SwiftUI

struct PulseBarView: View {
    let members: [CircleMember]
    let viewModel: CircleDetailViewModel
    let currentUserId: UUID
    let circleId: UUID
    let onNudge: (UUID, String, String?) -> Void

    @State private var nudgeTargetId: UUID?
    @State private var showCustomMessage = false
    @State private var customMessageText = ""
    @State private var nudgeSentTrigger = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(members) { member in
                    memberAvatar(member)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func memberAvatar(_ member: CircleMember) -> some View {
        let name = viewModel.displayName(for: member)
        let firstName = name.components(separatedBy: .whitespaces).first ?? name
        let ringStatus = viewModel.noorRingStatus(for: member.userId)
        let isCurrentUser = member.userId == currentUserId

        VStack(spacing: 6) {
            ZStack {
                NoorRing(status: ringStatus, size: 62)

                AvatarView(
                    avatarUrl: viewModel.avatarUrl(for: member),
                    name: name.isEmpty ? member.userId.uuidString : name,
                    size: 56
                )
            }
            .opacity(ringStatus == .dimmed ? 0.55 : 1.0)
            .onTapGesture {
                guard !isCurrentUser else { return }
                nudgeTargetId = member.userId
            }

            Text(isCurrentUser ? "You" : (firstName.isEmpty ? "..." : firstName))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ringStatus == .dimmed ? Color.msTextMuted.opacity(0.6) : Color.msTextMuted)
                .lineLimit(1)

            if member.role == "admin" {
                Text("Amir")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.msGold)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: nudgeTargetId)
        .sensoryFeedback(.success, trigger: nudgeSentTrigger)
        .confirmationDialog(
            "Send encouragement",
            isPresented: Binding(
                get: { nudgeTargetId == member.userId },
                set: { if !$0 { nudgeTargetId = nil } }
            ),
            titleVisibility: .hidden
        ) {
            Button("Do your habits!") {
                onNudge(member.userId, "habit_reminder", nil)
                nudgeSentTrigger += 1
                nudgeTargetId = nil
            }
            Button("Send a message...") {
                customMessageText = ""
                showCustomMessage = true
            }
            Button("Cancel", role: .cancel) {
                nudgeTargetId = nil
            }
        }
        .alert("Send a message", isPresented: $showCustomMessage) {
            TextField("Type something kind...", text: $customMessageText)
            Button("Send") {
                let text = customMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, let target = nudgeTargetId else { return }
                onNudge(target, "custom", text)
                nudgeSentTrigger += 1
                nudgeTargetId = nil
            }
            Button("Cancel", role: .cancel) {
                nudgeTargetId = nil
            }
        }
    }
}

// MARK: - Noor Ring

private struct NoorRing: View {
    let status: CircleDetailViewModel.NoorRingStatus
    let size: CGFloat

    @State private var pulsing = false

    var body: some View {
        SwiftUI.Circle()
            .stroke(ringColor, lineWidth: 3)
            .frame(width: size, height: size)
            .scaleEffect(status == .pulsingGreen && pulsing ? 1.08 : 1.0)
            .opacity(status == .pulsingGreen && pulsing ? 0.7 : 1.0)
            .animation(
                status == .pulsingGreen
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear {
                if status == .pulsingGreen { pulsing = true }
            }
    }

    private var ringColor: Color {
        switch status {
        case .gold: Color.msGold
        case .pulsingGreen: Color.green
        case .dimmed: Color.msTextMuted.opacity(0.3)
        }
    }
}
