import SwiftUI

struct NotificationSettingsView: View {
    let userId: UUID

    @State private var notificationService = NotificationService.shared
    @State private var showPermissionPrompt = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    permissionCard
                    preferenceCard
                    footerCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await notificationService.refreshPermissionStatus()
            await notificationService.loadPreferences(userId: userId)
        }
        .sheet(isPresented: $showPermissionPrompt, onDismiss: {
            Task { await notificationService.refreshPermissionStatus() }
        }) {
            NotificationPermissionModal(
                isPresented: $showPermissionPrompt,
                prayerTimeName: DailyMomentService.shared.prayerDisplayName
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                iconBubble("bell.badge.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Text("iPhone Permission")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)

                    Text(notificationService.permissionStatusSummary)
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }

                Spacer()

                permissionBadge
            }

            Text(permissionBodyCopy)
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)

            if notificationService.permissionStatus == .notDetermined {
                actionButton("Turn On Notifications") {
                    showPermissionPrompt = true
                }
            } else if notificationService.permissionStatus == .denied {
                actionButton("Open iPhone Settings") {
                    notificationService.openAppSettings()
                }
            }
        }
        .padding(18)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.msBorder, lineWidth: 1)
        )
    }

    private var preferenceCard: some View {
        VStack(spacing: 0) {
            preferenceToggle(
                title: "All Notifications",
                detail: "Master switch for every alert in Circles.",
                isOn: preferenceBinding(\.notificationsEnabled)
            )

            divider

            preferenceToggle(
                title: "Moment Window",
                detail: "Alert me when my Circle Moment window opens.",
                isOn: preferenceBinding(\.momentWindowEnabled)
            )

            divider

            preferenceToggle(
                title: "Nudges",
                detail: "Save the toggle now. Delivery lands in a later subphase.",
                isOn: preferenceBinding(\.nudgesEnabled)
            )

            divider

            preferenceToggle(
                title: "Circle Activity",
                detail: "Reserve your preference for future circle check-in alerts.",
                isOn: preferenceBinding(\.circleActivityEnabled)
            )

            divider

            preferenceToggle(
                title: "Habit Reminders",
                detail: "Let Circles schedule local reminders for habits that still need today's check-in.",
                isOn: preferenceBinding(\.habitRemindersEnabled)
            )
        }
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.msBorder, lineWidth: 1)
        )
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase 15.4 Live Today")
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextPrimary)

            Text("Moment Window, Nudges, Circle Activity, and Habit Reminders all honor the app-level preferences saved here.")
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.msBackgroundDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.msBorder, lineWidth: 1)
        )
    }

    private var permissionBodyCopy: String {
        switch notificationService.permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return "System permission is on. App-level toggles below decide which Circles notifications should still reach you."
        case .denied:
            return "Your iPhone is blocking notification delivery. You can still save in-app preferences here, but alerts will stay off until you re-enable permission in Settings."
        case .notDetermined:
            return "Turn this on first so Circles can alert you when your Moment window opens."
        @unknown default:
            return "Notification permission status is unavailable right now."
        }
    }

    private var permissionBadge: some View {
        Text(notificationService.isSystemPermissionGranted ? "On" : "Off")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(notificationService.isSystemPermissionGranted ? Color.msBackground : Color.msTextMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                notificationService.isSystemPermissionGranted ? Color.msGold : Color.msBackgroundDeep,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(Color.msBorder, lineWidth: notificationService.isSystemPermissionGranted ? 0 : 1)
            )
    }

    private var divider: some View {
        Divider()
            .foregroundStyle(Color.msBorder)
            .padding(.leading, 58)
    }

    private func preferenceToggle(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            iconBubble("bell.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextPrimary)

                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.msGold)
                .disabled(notificationService.isLoadingPreferences)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func iconBubble(_ systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.msGold.opacity(0.12))
                .frame(width: 34, height: 34)

            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(Color.msGold)
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(Color.msBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.msGold, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                MainActor.assumeIsolated {
                    notificationService.preferences?[keyPath: keyPath] ?? true
                }
            },
            set: { newValue in
                Task { @MainActor in
                    _ = await notificationService.updatePreferences(userId: userId) {
                        $0[keyPath: keyPath] = newValue
                    }
                }
            }
        )
    }
}
