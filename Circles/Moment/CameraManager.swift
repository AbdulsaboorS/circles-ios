import AVFoundation
import UIKit
import Observation

@Observable
@MainActor
final class CameraManager: NSObject {

    // MARK: - Published State

    var isMultiCamSupported: Bool = false
    var permissionGranted: Bool = false
    var capturedImage: UIImage?
    var rearPreviewLayer: AVCaptureVideoPreviewLayer?
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Private Session Properties

    private var multiCamSession: AVCaptureMultiCamSession?
    private var singleSession: AVCaptureSession?
    private var rearPhotoOutput: AVCapturePhotoOutput?
    private var frontPhotoOutput: AVCapturePhotoOutput?
    private var singlePhotoOutput: AVCapturePhotoOutput?

    private var rearImage: UIImage?
    private var frontImage: UIImage?

    // Track capture count for multi-cam (both outputs fire independently)
    private var pendingCaptureCount: Int = 0

    // MARK: - Session Accessors

    var activeSession: AVCaptureSession? {
        multiCamSession ?? singleSession
    }

    // MARK: - Permission

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                permissionGranted = granted
            }
        default:
            permissionGranted = false
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported

        if isMultiCamSupported {
            setupMultiCamSession()
        } else {
            setupSingleCamSession()
        }
    }

    private func setupMultiCamSession() {
        let session = AVCaptureMultiCamSession()
        session.beginConfiguration()

        // Rear camera input + output
        if let rearDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first,
           let rearInput = try? AVCaptureDeviceInput(device: rearDevice),
           session.canAddInput(rearInput) {
            session.addInput(rearInput)

            let rearOutput = AVCapturePhotoOutput()
            if session.canAddOutput(rearOutput) {
                session.addOutput(rearOutput)
                self.rearPhotoOutput = rearOutput
            }

            let rearLayer = AVCaptureVideoPreviewLayer(session: session)
            rearLayer.videoGravity = .resizeAspectFill
            self.rearPreviewLayer = rearLayer
        }

        // Front camera input + output
        if let frontDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices.first,
           let frontInput = try? AVCaptureDeviceInput(device: frontDevice),
           session.canAddInput(frontInput) {
            session.addInput(frontInput)

            let frontOutput = AVCapturePhotoOutput()
            if session.canAddOutput(frontOutput) {
                session.addOutput(frontOutput)
                self.frontPhotoOutput = frontOutput
            }

            let frontLayer = AVCaptureVideoPreviewLayer(session: session)
            frontLayer.videoGravity = .resizeAspectFill
            self.frontPreviewLayer = frontLayer
        }

        session.commitConfiguration()
        self.multiCamSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func setupSingleCamSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let rearDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first,
           let rearInput = try? AVCaptureDeviceInput(device: rearDevice),
           session.canAddInput(rearInput) {
            session.addInput(rearInput)

            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.singlePhotoOutput = photoOutput
            }

            let rearLayer = AVCaptureVideoPreviewLayer(session: session)
            rearLayer.videoGravity = .resizeAspectFill
            self.rearPreviewLayer = rearLayer
        }

        session.commitConfiguration()
        self.singleSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        if isMultiCamSupported, let rearOut = rearPhotoOutput, let frontOut = frontPhotoOutput {
            // Reset images for a fresh capture
            rearImage = nil
            frontImage = nil
            pendingCaptureCount = 2

            let rearSettings = AVCapturePhotoSettings()
            rearOut.capturePhoto(with: rearSettings, delegate: self)

            let frontSettings = AVCapturePhotoSettings()
            frontOut.capturePhoto(with: frontSettings, delegate: self)
        } else if let singleOut = singlePhotoOutput {
            let settings = AVCapturePhotoSettings()
            singleOut.capturePhoto(with: settings, delegate: self)
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

            // Draw rear image filling entire canvas
            rear.draw(in: CGRect(origin: .zero, size: rearSize))

            // Clip to rounded rect for front inset
            let frontPath = UIBezierPath(roundedRect: frontRect, cornerRadius: cornerRadius)
            cgCtx.saveGState()
            frontPath.addClip()
            front.draw(in: frontRect)
            cgCtx.restoreGState()

            // Draw white border stroke around front inset
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
        DispatchQueue.global(qos: .userInitiated).async {
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
