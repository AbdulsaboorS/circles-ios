@preconcurrency import AVFoundation
import UIKit
import Observation

@Observable
@MainActor
final class CameraManager: NSObject {

    // MARK: - Observable State

    var isMultiCamSupported: Bool = false
    var permissionGranted: Bool = false
    var isSessionReady: Bool = false
    var capturedImage: UIImage?
    var rearPreviewLayer: AVCaptureVideoPreviewLayer?
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Private Session Properties

    private var multiCamSession: AVCaptureMultiCamSession?
    private var singleSession: AVCaptureSession?
    private var rearPhotoOutput: AVCapturePhotoOutput?
    private var frontPhotoOutput: AVCapturePhotoOutput?
    private var singlePhotoOutput: AVCapturePhotoOutput?
    private var isSessionSetUp: Bool = false

    private var rearImage: UIImage?
    private var frontImage: UIImage?
    private var pendingCaptureCount: Int = 0

    // Dedicated serial queue — all AVFoundation work runs here, never main thread
    nonisolated private let sessionQueue = DispatchQueue(label: "com.circles.camera.session", qos: .userInitiated)

    // MARK: - Session Accessors

    var activeSession: AVCaptureSession? {
        multiCamSession ?? singleSession
    }

    // MARK: - Permission

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run { self.permissionGranted = granted }
                if granted { setupSession() }
            }
        default:
            permissionGranted = false
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        guard !isSessionSetUp else { return }
        isSessionSetUp = true
        let multiCamOK = AVCaptureMultiCamSession.isMultiCamSupported
        isMultiCamSupported = multiCamOK
        if multiCamOK {
            configureMultiCamSession()
        } else {
            configureSingleCamSession()
        }
    }

    private func configureMultiCamSession() {
        let session = AVCaptureMultiCamSession()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()

            var rearOut: AVCapturePhotoOutput?
            var frontOut: AVCapturePhotoOutput?
            var rearLayer: AVCaptureVideoPreviewLayer?
            var frontLayer: AVCaptureVideoPreviewLayer?

            if let rearDevice = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
            ).devices.first,
               let rearInput = try? AVCaptureDeviceInput(device: rearDevice),
               session.canAddInput(rearInput) {
                session.addInput(rearInput)
                let out = AVCapturePhotoOutput()
                if session.canAddOutput(out) { session.addOutput(out); rearOut = out }
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                rearLayer = layer
            }

            if let frontDevice = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front
            ).devices.first,
               let frontInput = try? AVCaptureDeviceInput(device: frontDevice),
               session.canAddInput(frontInput) {
                session.addInput(frontInput)
                let out = AVCapturePhotoOutput()
                if session.canAddOutput(out) { session.addOutput(out); frontOut = out }
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                frontLayer = layer
            }

            session.commitConfiguration()
            session.startRunning()

            Task { @MainActor in
                self.multiCamSession = session
                self.rearPhotoOutput = rearOut
                self.frontPhotoOutput = frontOut
                self.rearPreviewLayer = rearLayer
                self.frontPreviewLayer = frontLayer
                self.isSessionReady = true
            }
        }
    }

    private func configureSingleCamSession() {
        let session = AVCaptureSession()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo

            var photoOut: AVCapturePhotoOutput?
            var rearLayer: AVCaptureVideoPreviewLayer?

            if let rearDevice = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
            ).devices.first,
               let rearInput = try? AVCaptureDeviceInput(device: rearDevice),
               session.canAddInput(rearInput) {
                session.addInput(rearInput)
                let out = AVCapturePhotoOutput()
                if session.canAddOutput(out) { session.addOutput(out); photoOut = out }
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                rearLayer = layer
            }

            session.commitConfiguration()
            session.startRunning()

            Task { @MainActor in
                self.singleSession = session
                self.singlePhotoOutput = photoOut
                self.rearPreviewLayer = rearLayer
                self.isSessionReady = true
            }
        }
    }

    // MARK: - Capture

    func resetCapture() {
        capturedImage = nil
        rearImage = nil
        frontImage = nil
        pendingCaptureCount = 0
    }

    func capturePhoto() {
        capturedImage = nil
        if isMultiCamSupported, let rearOut = rearPhotoOutput, let frontOut = frontPhotoOutput {
            rearImage = nil
            frontImage = nil
            pendingCaptureCount = 2
            sessionQueue.async {
                rearOut.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
                frontOut.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        } else if let singleOut = singlePhotoOutput {
            sessionQueue.async {
                singleOut.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    // MARK: - Compositing

    func compositeImages(rear: UIImage, front: UIImage) -> UIImage {
        let rearSize = rear.size
        let frontWidth = rearSize.width * 0.25
        let frontHeight = frontWidth * (4.0 / 3.0)
        let inset: CGFloat = 16
        let cornerRadius: CGFloat = 12
        let borderWidth: CGFloat = 2

        let frontRect = CGRect(
            x: inset,
            y: rearSize.height - frontHeight - inset,
            width: frontWidth,
            height: frontHeight
        )

        let renderer = UIGraphicsImageRenderer(size: rearSize)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            rear.draw(in: CGRect(origin: .zero, size: rearSize))
            let frontPath = UIBezierPath(roundedRect: frontRect, cornerRadius: cornerRadius)
            cgCtx.saveGState()
            frontPath.addClip()
            front.draw(in: frontRect)
            cgCtx.restoreGState()
            let borderRect = frontRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius)
            UIColor.white.setStroke()
            borderPath.lineWidth = borderWidth
            borderPath.stroke()
        }
    }

    // MARK: - Stop Session

    func stopSession() {
        let multi = multiCamSession
        let single = singleSession
        sessionQueue.async {
            multi?.stopRunning()
            single?.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        // Determine which camera fired without crossing actor boundary with non-Sendable output.
        // ObjectIdentifier is Sendable and safe to capture.
        let outputId = ObjectIdentifier(output)

        Task { @MainActor in
            await self.handleCapturedImage(image, outputId: outputId)
        }
    }

    @MainActor
    private func handleCapturedImage(_ image: UIImage, outputId: ObjectIdentifier) async {
        if isMultiCamSupported {
            if let rearOut = rearPhotoOutput, outputId == ObjectIdentifier(rearOut) {
                rearImage = image
            } else if let frontOut = frontPhotoOutput, outputId == ObjectIdentifier(frontOut) {
                frontImage = image
            }

            pendingCaptureCount -= 1

            if pendingCaptureCount == 0, let rear = rearImage, let front = frontImage {
                capturedImage = compositeImages(rear: rear, front: front)
            }
        } else {
            // Single-cam: use rear image directly
            capturedImage = image
        }
    }
}
