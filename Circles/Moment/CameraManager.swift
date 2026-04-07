@preconcurrency import AVFoundation
import UIKit
import Observation

@Observable
@MainActor
final class CameraManager: NSObject {

    enum CaptureSource: String, CaseIterable, Identifiable {
        case rear
        case front

        var id: String { rawValue }

        var position: AVCaptureDevice.Position {
            switch self {
            case .rear: return .back
            case .front: return .front
            }
        }

        var opposite: CaptureSource {
            switch self {
            case .rear: return .front
            case .front: return .rear
            }
        }
    }

    // MARK: - Observable State

    var permissionGranted = false
    var isSessionReady = false
    var capturedImage: UIImage?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var activeSource: CaptureSource = .rear
    var firstCapturedPreview: UIImage?
    var isCapturingSequence = false

    // MARK: - Private Session Properties

    private var session: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var isSessionSetUp = false

    private var primaryImage: UIImage?
    private var secondaryImage: UIImage?
    private var captureGeneration = 0
    private var activeSequence: CaptureSequence?
    private var captureRequests: [Int64: CaptureRequest] = [:]

    // Dedicated serial queue — all AVFoundation work runs here, never main thread
    nonisolated private let sessionQueue = DispatchQueue(label: "com.circles.camera.session", qos: .userInitiated)

    private struct CaptureRequest {
        let generation: Int
        let source: CaptureSource
    }

    private struct CaptureSequence {
        let generation: Int
        let primary: CaptureSource
        let secondary: CaptureSource
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
        configureSession(defaultSource: .rear)
    }

    private func configureSession(defaultSource: CaptureSource) {
        let session = AVCaptureSession()
        let targetPosition = defaultSource.position
        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard
                let device = Self.device(for: targetPosition),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                Task { @MainActor in
                    self.isSessionReady = false
                }
                return
            }

            session.addInput(input)

            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                Task { @MainActor in
                    self.isSessionReady = false
                }
                return
            }

            session.addOutput(output)

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill

            session.commitConfiguration()
            session.startRunning()

            Task { @MainActor in
                self.session = session
                self.currentInput = input
                self.photoOutput = output
                self.previewLayer = layer
                self.activeSource = defaultSource
                self.isSessionReady = true
            }
        }
    }

    // MARK: - Capture

    func resetCapture() {
        capturedImage = nil
        firstCapturedPreview = nil
        primaryImage = nil
        secondaryImage = nil
        captureRequests = [:]
        activeSequence = nil
        isCapturingSequence = false
    }

    func startDoubleTake(firstSource: CaptureSource) {
        guard permissionGranted, isSessionReady, !isCapturingSequence else { return }

        capturedImage = nil
        firstCapturedPreview = nil
        primaryImage = nil
        secondaryImage = nil
        captureRequests = [:]
        captureGeneration += 1

        let sequence = CaptureSequence(
            generation: captureGeneration,
            primary: firstSource,
            secondary: firstSource.opposite
        )
        activeSequence = sequence
        isCapturingSequence = true

        prepareAndCapture(source: firstSource, generation: sequence.generation, delay: 0)
    }

    func flipActiveCamera() {
        guard permissionGranted, isSessionReady, !isCapturingSequence else { return }
        isSessionReady = false
        switchInput(to: activeSource.opposite) { [weak self] success in
            guard let self else { return }
            if !success {
                Task { @MainActor in
                    self.isSessionReady = true
                }
            }
        }
    }

    private func prepareAndCapture(source: CaptureSource, generation: Int, delay: TimeInterval) {
        if activeSource == source {
            scheduleCapture(source: source, generation: generation, delay: delay)
            return
        }

        isSessionReady = false
        switchInput(to: source) { [weak self] success in
            guard let self else { return }
            Task { @MainActor in
                if success {
                    self.scheduleCapture(source: source, generation: generation, delay: delay)
                } else {
                    self.failSequence(message: "Couldn't switch cameras. Try again.")
                }
            }
        }
    }

    private func scheduleCapture(source: CaptureSource, generation: Int, delay: TimeInterval) {
        guard let photoOutput else {
            failSequence(message: "Camera isn’t ready yet. Try again.")
            return
        }

        let settings = AVCapturePhotoSettings()
        captureRequests[Int64(settings.uniqueID)] = CaptureRequest(generation: generation, source: source)

        sessionQueue.asyncAfter(deadline: .now() + delay) {
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func switchInput(to source: CaptureSource, completion: @Sendable @escaping (Bool) -> Void) {
        guard let session else {
            completion(false)
            return
        }

        let targetPosition = source.position
        let previousInput = currentInput

        sessionQueue.async { [weak self] in
            guard let self else {
                completion(false)
                return
            }

            guard
                let device = Self.device(for: targetPosition),
                let newInput = try? AVCaptureDeviceInput(device: device)
            else {
                completion(false)
                return
            }

            session.beginConfiguration()
            if let previousInput {
                session.removeInput(previousInput)
            }

            guard session.canAddInput(newInput) else {
                if let previousInput, session.canAddInput(previousInput) {
                    session.addInput(previousInput)
                }
                session.commitConfiguration()
                completion(false)
                return
            }

            session.addInput(newInput)
            session.commitConfiguration()

            Task { @MainActor in
                self.currentInput = newInput
                self.activeSource = source
                self.isSessionReady = true
            }
            completion(true)
        }
    }

    private func failSequence(message: String) {
        activeSequence = nil
        captureRequests = [:]
        primaryImage = nil
        secondaryImage = nil
        firstCapturedPreview = nil
        isCapturingSequence = false
        isSessionReady = true
        print("[CameraManager] \(message)")
    }

    // MARK: - Composition

    private func composedImage(primary: UIImage, secondary: UIImage) -> UIImage {
        let mainImage = normalizedImage(primary)
        let insetImage = normalizedImage(secondary)

        let canvasSize = CGSize(width: 1080, height: 1440)
        let insetWidth = canvasSize.width * 0.28
        let insetHeight = insetWidth * (4.0 / 3.0)
        let insetRect = CGRect(
            x: 36,
            y: canvasSize.height - insetHeight - 36,
            width: insetWidth,
            height: insetHeight
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            drawAspectFill(mainImage, in: CGRect(origin: .zero, size: canvasSize), context: ctx.cgContext)

            let insetPath = UIBezierPath(roundedRect: insetRect, cornerRadius: 28)
            ctx.cgContext.saveGState()
            insetPath.addClip()
            drawAspectFill(insetImage, in: insetRect, context: ctx.cgContext)
            ctx.cgContext.restoreGState()

            UIColor.white.withAlphaComponent(0.96).setStroke()
            insetPath.lineWidth = 6
            insetPath.stroke()
        }
    }

    private func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawOrigin = CGPoint(
            x: rect.midX - (drawSize.width / 2),
            y: rect.midY - (drawSize.height / 2)
        )

        context.saveGState()
        context.clip(to: rect)
        image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        context.restoreGState()
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { rendererContext in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private nonisolated static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        ).devices.first
    }

    // MARK: - Stop Session

    func stopSession() {
        let session = session
        sessionQueue.async {
            session?.stopRunning()
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
            Task { @MainActor in
                self.failSequence(message: "Couldn’t capture your Double Take. Try again.")
            }
            return
        }

        let requestId = Int64(photo.resolvedSettings.uniqueID)

        Task { @MainActor in
            await self.handleCapturedImage(image, requestId: requestId)
        }
    }

    @MainActor
    private func handleCapturedImage(_ image: UIImage, requestId: Int64) async {
        guard let request = captureRequests.removeValue(forKey: requestId),
              let activeSequence,
              request.generation == activeSequence.generation else {
            return
        }

        let normalized = normalizedImage(image)

        if request.source == activeSequence.primary {
            primaryImage = normalized
            firstCapturedPreview = normalized
            prepareAndCapture(source: activeSequence.secondary, generation: activeSequence.generation, delay: 0.5)
            return
        }

        secondaryImage = normalized

        guard let primaryImage, let secondaryImage else {
            failSequence(message: "Couldn’t finish your Double Take. Try again.")
            return
        }

        capturedImage = composedImage(primary: primaryImage, secondary: secondaryImage)
        self.primaryImage = nil
        self.secondaryImage = nil
        firstCapturedPreview = nil
        captureRequests = [:]
        self.activeSequence = nil
        isCapturingSequence = false
        isSessionReady = true
    }
}
