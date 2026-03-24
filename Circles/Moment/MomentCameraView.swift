import SwiftUI
import AVFoundation

struct MomentCameraView: View {
    let circleId: UUID
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cameraManager = CameraManager()
    @State private var flashOpacity: Double = 0
    @State private var isShutterPressed: Bool = false

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
        }
        .ignoresSafeArea()
        .task {
            cameraManager.checkPermission()
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
        ZStack(alignment: .topTrailing) {
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
                                .stroke(.white, lineWidth: 2)
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

            // Cancel button — top-right
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityLabel("Cancel camera")

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
                    .fill(Color(hex: "0D1021"))
                    .frame(width: 68, height: 68)
            }
        }
        .scaleEffect(isShutterPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.2), value: isShutterPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isShutterPressed = true }
                .onEnded { _ in isShutterPressed = false }
        )
        .accessibilityLabel("Take Moment photo")
    }

    private func triggerCapture() {
        cameraManager.capturePhoto()
        // Flash animation
        flashOpacity = 1
        withAnimation(.easeOut(duration: 0.3)) {
            flashOpacity = 0
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "0D1021").ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "camera.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))

                Text("Camera Access Required")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Go to Settings to allow camera access.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Color(hex: "E8834B"))
            }

            // Cancel button — top-right
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
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
        // Remove old layer if any
        self.previewLayer?.removeFromSuperlayer()
        self.previewLayer = layer
        self.layer.addSublayer(layer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
