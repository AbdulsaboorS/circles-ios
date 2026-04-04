import SwiftUI
import AVFoundation
import Combine

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
}

struct MomentCameraView: View {
    let circleId: UUID
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cameraManager = CameraManager()
    @State private var flashOpacity: Double = 0
    @State private var isShutterPressed: Bool = false
    @State private var windowSecondsRemaining: Int = 0
    
    private var isCaptureReady: Bool {
        cameraManager.permissionGranted && cameraManager.isSessionReady
    }

    var body: some View {
        ZStack {
            if !cameraManager.permissionGranted {
                permissionDeniedView
            } else {
                cameraViewfinderView
            }

            // Flash overlay
            Color.white.opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.3), value: flashOpacity)

            if cameraManager.permissionGranted && !cameraManager.isSessionReady {
                loadingOverlay
            }
        }
        .ignoresSafeArea()
        .task {
            cameraManager.resetCapture()
            cameraManager.checkPermission()
            updateWindowCountdown()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateWindowCountdown()
        }
        .onChange(of: cameraManager.capturedImage) { _, image in
            if let image {
                onCapture(image)
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    // MARK: - Camera Viewfinder

    private var cameraViewfinderView: some View {
        ZStack(alignment: .top) {
            // Rear camera fills entire screen
            Color.black.ignoresSafeArea()

            if let rearLayer = cameraManager.rearPreviewLayer {
                CameraPreviewRepresentable(previewLayer: rearLayer)
                    .ignoresSafeArea()
            }

            // Front camera inset (bottom-left, only in multi-cam mode)
            if cameraManager.isMultiCamSupported,
               let frontLayer = cameraManager.frontPreviewLayer {
                GeometryReader { geo in
                    let insetWidth = geo.size.width * 0.25
                    let insetHeight = insetWidth * (4.0 / 3.0)
                    CameraPreviewRepresentable(previewLayer: frontLayer)
                        .frame(width: insetWidth, height: insetHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.msGold, lineWidth: 2)
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .bottomLeading
                        )
                        .padding(.leading, 16)
                        .padding(.bottom, 16 + geo.safeAreaInsets.bottom + 120)
                }
                .ignoresSafeArea()
            }

            // Top bar: countdown (left) + cancel (right)
            HStack {
                if windowSecondsRemaining > 0 {
                    let mins = windowSecondsRemaining / 60
                    let secs = windowSecondsRemaining % 60
                    Label(String(format: "%02d:%02d", mins, secs), systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cancel camera")
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            // Bottom controls
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    Spacer()

                    // Shutter button
                    shutterButton

                    // Flip camera (single-cam fallback only)
                    if !cameraManager.isMultiCamSupported {
                        Spacer().frame(width: 32)
                        Button {
                            // Flip camera not yet wired (Plan 03 scope)
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        Button {
            triggerCapture()
        } label: {
            ZStack {
                SwiftUI.Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                SwiftUI.Circle()
                    .fill(Color.msBackground)
                    .frame(width: 68, height: 68)
            }
        }
        .scaleEffect(isShutterPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.2), value: isShutterPressed)
        .disabled(!isCaptureReady)
        .opacity(isCaptureReady ? 1.0 : 0.55)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isShutterPressed = true }
                .onEnded { _ in isShutterPressed = false }
        )
        .accessibilityLabel("Take Moment photo")
    }

    private func updateWindowCountdown() {
        guard let start = DailyMomentService.shared.windowStart else {
            windowSecondsRemaining = 0; return
        }
        let windowEnd = start.addingTimeInterval(30 * 60)
        windowSecondsRemaining = max(0, Int(windowEnd.timeIntervalSince(Date())))
    }

    private func triggerCapture() {
        guard isCaptureReady else { return }
        cameraManager.resetCapture()
        cameraManager.capturePhoto()
        // Flash animation
        flashOpacity = 1
        withAnimation(.easeOut(duration: 0.3)) {
            flashOpacity = 0
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.msGold)
            Text("Warming up camera…")
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        ZStack(alignment: .topTrailing) {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "camera.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.msTextMuted)

                Text("Camera Access Required")
                    .font(.headline)
                    .foregroundStyle(Color.msTextPrimary)

                Text("Go to Settings to allow camera access.")
                    .font(.subheadline)
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Color.msGold)
            }

            // Cancel button — top-right
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.msTextPrimary)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityLabel("Cancel camera")
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewRepresentable: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.setPreviewLayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.setNeedsLayout()
    }
}

final class CameraPreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        self.previewLayer?.removeFromSuperlayer()
        self.previewLayer = layer
        self.layer.addSublayer(layer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
