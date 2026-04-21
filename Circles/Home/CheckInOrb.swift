import SwiftUI

/// Hold-to-confirm orb. Pulses while idle; on press, a gold fill rises from
/// the bottom as a 1.2s progress animation runs. Releasing early resets. At
/// full progress a haptic fires and `onComplete` is called exactly once.
///
/// Honours `accessibilityReduceMotion`: idle pulse disables and the fill ramps
/// linearly with no extra easing when the user has reduce-motion enabled.
struct CheckInOrb: View {
    /// Called exactly once when the user holds through the full duration.
    var onComplete: () -> Void

    /// Total hold duration before completion.
    private let requiredDuration: TimeInterval = 1.2
    private let orbSize: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPressing: Bool = false
    @State private var progress: Double = 0           // 0 → 1
    @State private var pulseScale: Double = 1.0
    @State private var didFire: Bool = false
    @State private var progressTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                SwiftUI.Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.msGold.opacity(0.18), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: orbSize
                        )
                    )
                    .frame(width: orbSize * 1.55, height: orbSize * 1.55)

                SwiftUI.Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.msGold.opacity(0.55),
                                Color.msGold.opacity(0.22),
                                Color.msGold.opacity(0.08)
                            ],
                            center: .init(x: 0.35, y: 0.32),
                            startRadius: 10,
                            endRadius: orbSize / 1.6
                        )
                    )
                    .frame(width: orbSize, height: orbSize)
                    .overlay(
                        SwiftUI.Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.msGold.opacity(0.8), Color.msGold.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.msGold.opacity(0.55), radius: 20)

                // Progress overlay — brighter sphere fading in with progress.
                SwiftUI.Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.msGold, Color.msGold.opacity(0.6)],
                            center: .center,
                            startRadius: 8,
                            endRadius: orbSize / 2
                        )
                    )
                    .frame(width: orbSize, height: orbSize)
                    .opacity(progress)
                    .shadow(color: Color.msGold.opacity(0.9 * progress), radius: 30)

                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.msBackground.opacity(0.75 - progress * 0.6))
                    .opacity(isPressing ? 0.0 : 1.0)
            }
            .scaleEffect(isPressing ? 1.04 : pulseScale)
            .animation(.easeOut(duration: 0.18), value: isPressing)
            .contentShape(SwiftUI.Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            startHold()
                        }
                    }
                    .onEnded { _ in
                        endHold()
                    }
            )
            .onAppear { startIdlePulse() }

            Text(isPressing ? "Keep holding…" : "Hold to confirm your check-in.")
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextMuted)
                .animation(.easeInOut(duration: 0.25), value: isPressing)
        }
    }

    // MARK: - Idle pulse

    private func startIdlePulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            pulseScale = 1.04
        }
    }

    // MARK: - Hold lifecycle

    private func startHold() {
        guard !didFire else { return }
        isPressing = true
        progress = 0
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            let start = Date()
            let step: TimeInterval = 1.0 / 60.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(step * 1000)))
                if Task.isCancelled { return }
                let elapsed = Date().timeIntervalSince(start)
                let p = min(1.0, elapsed / requiredDuration)
                progress = p
                if p >= 1.0 {
                    fireComplete()
                    return
                }
            }
        }
    }

    private func endHold() {
        guard !didFire else { return }
        isPressing = false
        progressTask?.cancel()
        progressTask = nil
        withAnimation(.easeOut(duration: 0.25)) {
            progress = 0
        }
    }

    private func fireComplete() {
        guard !didFire else { return }
        didFire = true
        isPressing = false
        progressTask?.cancel()
        progressTask = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onComplete()
    }
}
