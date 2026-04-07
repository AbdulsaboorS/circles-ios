import SwiftUI
import AVFoundation
import Combine

struct MomentCameraView: View {
    let circleId: UUID
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cameraManager = CameraManager()
    @State private var flashOpacity: Double = 0
    @State private var isShutterPressed: Bool = false
    @State private var windowSecondsRemaining: Int = 0
    
    private var isCaptureReady: Bool {
        cameraManager.permissionGranted && cameraManager.isSessionReady && !cameraManager.isCapturingSequence
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

            if cameraManager.permissionGranted && cameraManager.previewLayer == nil {
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
            Color.black.ignoresSafeArea()

            if let previewLayer = cameraManager.previewLayer {
                CameraPreviewRepresentable(previewLayer: previewLayer)
                    .ignoresSafeArea()
            }

            if let firstCapture = cameraManager.firstCapturedPreview {
                firstCaptureOverlay(image: firstCapture)
            }

            VStack {
                topControls
                Spacer()
                bottomControls
            }
        }
    }

    private var topControls: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.22), in: SwiftUI.Circle())
            }
            .accessibilityLabel("Cancel camera")

            Spacer()

            countdownPill
            
            Spacer()
                .frame(width: 44)
        }
        .padding(.top, 42)
        .padding(.horizontal, 16)
    }

    private var bottomControls: some View {
        HStack {
            Spacer()
            shutterButton
            Spacer().frame(width: 28)
            flipCameraButton
            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 48)
    }

    private var countdownPill: some View {
        Group {
            let mins = max(0, windowSecondsRemaining) / 60
            let secs = max(0, windowSecondsRemaining) % 60
            VStack(spacing: 2) {
                Text("Moment Window")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.msTextPrimary.opacity(0.75))
                Text(String(format: "%02d:%02d", mins, secs))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(windowSecondsRemaining > 300 ? Color.msGold : Color.red.opacity(0.92))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func firstCaptureOverlay(image: UIImage) -> some View {
        VStack {
            Spacer()

            HStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 112, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.92), lineWidth: 3)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        ProgressView()
                            .tint(Color.msGold)
                            .padding(12)
                            .background(Color.black.opacity(0.42), in: SwiftUI.Circle())
                            .padding(8)
                    }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 158)
        }
        .transition(.opacity)
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
                    .fill(cameraManager.isCapturingSequence ? Color.msGold.opacity(0.4) : Color.msBackground)
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

    private var flipCameraButton: some View {
        Button {
            cameraManager.flipActiveCamera()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.black.opacity(0.26), in: SwiftUI.Circle())
        }
        .disabled(cameraManager.isCapturingSequence || !cameraManager.isSessionReady)
        .opacity((cameraManager.isCapturingSequence || !cameraManager.isSessionReady) ? 0.45 : 1)
        .accessibilityLabel("Flip camera")
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
        cameraManager.startDoubleTake(firstSource: cameraManager.activeSource)
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
                Image(systemName: "camera.fill")
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
