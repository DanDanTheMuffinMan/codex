#!/usr/bin/env swift

import AVFoundation
import Foundation

struct Arguments {
    var deviceName: String?
    var listDevices = false
    var outputPath: String?
    var timeoutSeconds: TimeInterval = 15
}

enum CameraProbeError: LocalizedError {
    case missingOutputPath
    case noDevices
    case deviceNotFound(String)
    case permissionDenied
    case permissionRestricted
    case permissionTimedOut
    case cannotCreateInput(String)
    case cannotAttachInput
    case cannotAttachOutput
    case captureTimedOut
    case noPhotoData

    var errorDescription: String? {
        switch self {
        case .missingOutputPath:
            return "Provide --output /absolute/path/to/frame.jpg or use --list."
        case .noDevices:
            return "No camera devices were detected."
        case let .deviceNotFound(name):
            return "No camera device matched '\(name)'."
        case .permissionDenied:
            return "Camera access was denied for this process."
        case .permissionRestricted:
            return "Camera access is restricted on this Mac."
        case .permissionTimedOut:
            return "Timed out waiting for the macOS camera permission decision."
        case let .cannotCreateInput(message):
            return "Could not create a camera input: \(message)"
        case .cannotAttachInput:
            return "Could not attach the selected camera input to the capture session."
        case .cannotAttachOutput:
            return "Could not attach the photo output to the capture session."
        case .captureTimedOut:
            return "Timed out waiting for the webcam to deliver a frame."
        case .noPhotoData:
            return "The webcam capture finished without photo data."
        }
    }
}

final class PhotoCaptureRunner: NSObject, AVCapturePhotoCaptureDelegate {
    private let device: AVCaptureDevice
    private let outputURL: URL
    private let timeoutSeconds: TimeInterval
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let completion = DispatchSemaphore(value: 0)
    private var captureError: Error?

    init(device: AVCaptureDevice, outputURL: URL, timeoutSeconds: TimeInterval) {
        self.device = device
        self.outputURL = outputURL
        self.timeoutSeconds = timeoutSeconds
    }

    func run() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraProbeError.cannotCreateInput(error.localizedDescription)
        }

        guard session.canAddInput(input) else {
            throw CameraProbeError.cannotAttachInput
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw CameraProbeError.cannotAttachOutput
        }
        session.addOutput(photoOutput)
        session.commitConfiguration()

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        session.startRunning()
        defer { session.stopRunning() }

        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)

        let result = completion.wait(timeout: .now() + timeoutSeconds)
        if result == .timedOut {
            throw CameraProbeError.captureTimedOut
        }

        if let captureError {
            throw captureError
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { completion.signal() }

        if let error {
            captureError = error
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            captureError = CameraProbeError.noPhotoData
            return
        }

        do {
            try data.write(to: outputURL, options: .atomic)
        } catch {
            captureError = error
        }
    }
}

func parseArguments() throws -> Arguments {
    var parsed = Arguments()
    var index = 1
    let values = CommandLine.arguments

    while index < values.count {
        switch values[index] {
        case "--list":
            parsed.listDevices = true
            index += 1
        case "--device":
            guard index + 1 < values.count else {
                throw CameraProbeError.deviceNotFound("")
            }
            parsed.deviceName = values[index + 1]
            index += 2
        case "--output":
            guard index + 1 < values.count else {
                throw CameraProbeError.missingOutputPath
            }
            parsed.outputPath = values[index + 1]
            index += 2
        case "--timeout":
            guard index + 1 < values.count else {
                throw CameraProbeError.permissionTimedOut
            }
            parsed.timeoutSeconds = TimeInterval(values[index + 1]) ?? parsed.timeoutSeconds
            index += 2
        default:
            throw NSError(
                domain: "capture_webcam_frame",
                code: 64,
                userInfo: [NSLocalizedDescriptionKey: "Unknown argument: \(values[index])"]
            )
        }
    }

    return parsed
}

func availableDevices() -> [AVCaptureDevice] {
    AVCaptureDevice.devices(for: .video).sorted { lhs, rhs in
        lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
    }
}

func ensureCameraAccess(timeoutSeconds: TimeInterval) throws {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        return
    case .notDetermined:
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        AVCaptureDevice.requestAccess(for: .video) { value in
            granted = value
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + timeoutSeconds)
        if result == .timedOut {
            throw CameraProbeError.permissionTimedOut
        }
        guard granted else {
            throw CameraProbeError.permissionDenied
        }
    case .denied:
        throw CameraProbeError.permissionDenied
    case .restricted:
        throw CameraProbeError.permissionRestricted
    @unknown default:
        throw CameraProbeError.permissionDenied
    }
}

do {
    let arguments = try parseArguments()
    let devices = availableDevices()

    if arguments.listDevices {
        if devices.isEmpty {
            throw CameraProbeError.noDevices
        }
        for device in devices {
            print(device.localizedName)
        }
        exit(0)
    }

    guard let outputPath = arguments.outputPath else {
        throw CameraProbeError.missingOutputPath
    }

    guard !devices.isEmpty else {
        throw CameraProbeError.noDevices
    }

    try ensureCameraAccess(timeoutSeconds: arguments.timeoutSeconds)

    let selectedDevice: AVCaptureDevice
    if let deviceName = arguments.deviceName {
        guard let device = devices.first(where: {
            $0.localizedName.localizedCaseInsensitiveContains(deviceName)
        }) else {
            throw CameraProbeError.deviceNotFound(deviceName)
        }
        selectedDevice = device
    } else {
        selectedDevice = devices[0]
    }

    let outputURL = URL(fileURLWithPath: outputPath)
    let runner = PhotoCaptureRunner(
        device: selectedDevice,
        outputURL: outputURL,
        timeoutSeconds: arguments.timeoutSeconds
    )
    try runner.run()

    print("captured=\(outputURL.path)")
    print("device=\(selectedDevice.localizedName)")
} catch {
    fputs("capture_webcam_frame.swift: \(error.localizedDescription)\n", stderr)
    exit(1)
}
