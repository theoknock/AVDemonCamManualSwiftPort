import SwiftUI
import AVFoundation
import Photos
import Combine


class CameraViewModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    // Published properties for camera parameters
    @Published var setupResult: AVCamManualSetupResult = .success
    @Published var sessionRunning = false
    @Published var isRecording = false
    @Published var showHUD = false
    @Published var selectedManualHUDSegment = 0

    @Published var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    @Published var lensPositionSliderValue: Float = 0.0
    @Published var canSetLensPosition = false

    @Published var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    @Published var exposureDurationSliderValue: Double = 0.5
    @Published var ISOSliderValue: Double = 0.5

    @Published var videoZoomFactorSliderValue: Double = 0.0
    @Published var torchLevelSliderValue: Float = 0.0

    @Published var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .continuousAutoWhiteBalance
    @Published var temperatureSliderValue: Double = 0.5
    @Published var tintSliderValue: Double = 0.5

    @Published var coverViewVisible: Bool = false
    @Published var cameraUnavailable: Bool = false
    @Published var resumeButtonVisible: Bool = false

    @Published var showAlert = false
    @Published var alertMessage = ""

    @Published var thermalStateMessage = ""

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session.queue")
    var videoDevice: AVCaptureDevice?
    var videoDeviceInput: AVCaptureDeviceInput?
    var movieFileOutput: AVCaptureMovieFileOutput?
    var backgroundRecordingID: UIBackgroundTaskIdentifier = .invalid

    private var lensPositionTimer: Timer?

    override init() {
        super.init()
        checkPermissions()
        observeThermalState()
    }

    deinit {
        lensPositionTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Permissions
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.configureSession()
                } else {
                    DispatchQueue.main.async {
                        self.setupResult = .cameraNotAuthorized
                        self.alertMessage = "AVCamManual doesn't have permission to use the camera. Please update privacy settings."
                        self.showAlert = true
                    }
                }
            }
        default:
            setupResult = .cameraNotAuthorized
            alertMessage = "Camera not authorized. Please update your privacy settings."
            showAlert = true
        }
    }

    // MARK: - Session Configuration
    func configureSession() {
        sessionQueue.async {
            if self.setupResult != .success {
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.setupResult = .sessionConfigurationFailed
                self.session.commitConfiguration()
                return
            }
            self.videoDevice = videoDevice

            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    self.setupResult = .sessionConfigurationFailed
                    self.session.commitConfiguration()
                    return
                }
            } catch {
                print("Error creating video device input: \(error)")
                self.setupResult = .sessionConfigurationFailed
                self.session.commitConfiguration()
                return
            }

            // Add audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioDeviceInput) {
                        self.session.addInput(audioDeviceInput)
                    }
                } catch {
                    print("Error adding audio input: \(error)")
                }
            }

            // Add movie file output
            let movieOutput = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(movieOutput) {
                self.session.addOutput(movieOutput)
                self.movieFileOutput = movieOutput
            } else {
                self.setupResult = .sessionConfigurationFailed
                self.session.commitConfiguration()
                return
            }

            self.session.commitConfiguration()

            self.startSession()
            self.configureInitialCameraSettings()
            self.startLensPositionPolling()
        }
    }

    func startSession() {
        sessionQueue.async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.sessionRunning = self.session.isRunning
            }
        }
    }

    // MARK: - Initial Camera Settings
    func configureInitialCameraSettings() {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
//                device.automaticallyEnablesLowLightBoostWhenAvailable = true

                // Apply propertyControlValue to lens position
                let lensPosValue = propertyControlValue(
                    Double(device.lensPosition),
                    propertyMin: 0.0,
                    propertyMax: 1.0,
                    inverseGamma: 1.0,
                    offset: 0.0
                )

                let iso = device.iso
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let isoValue = propertyControlValue(
                    Double(iso),
                    propertyMin: Double(minISO),
                    propertyMax: Double(maxISO),
                    inverseGamma: 1.0,
                    offset: 0.0
                )

                let exposureDurationSeconds = CMTimeGetSeconds(device.exposureDuration)
                let minExposure = 1.0 / 1000.0
                let maxExposure = 1.0 / 3.0
                let exposureValue = propertyControlValue(
                    exposureDurationSeconds,
                    propertyMin: minExposure,
                    propertyMax: maxExposure,
                    inverseGamma: 5.0,
                    offset: 0.0
                )

                let gains = device.deviceWhiteBalanceGains
                let tempAndTint = device.temperatureAndTintValues(for: gains)
                let tempValue = propertyControlValue(
                    Double(tempAndTint.temperature),
                    propertyMin: 3000,
                    propertyMax: 8000,
                    inverseGamma: 1.0,
                    offset: 0.0
                )
                let tintValue = propertyControlValue(
                    Double(tempAndTint.tint),
                    propertyMin: -150,
                    propertyMax: 150,
                    inverseGamma: 1.0,
                    offset: 0.0
                )

                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.lensPositionSliderValue = Float(lensPosValue)
                    self.ISOSliderValue = isoValue
                    self.exposureDurationSliderValue = exposureValue
                    self.temperatureSliderValue = tempValue
                    self.tintSliderValue = tintValue
                }
            } catch {
                print("Could not lock device: \(error)")
            }
        }
    }

    // MARK: - Lens Position Polling
    func startLensPositionPolling() {
        DispatchQueue.main.async {
            self.lensPositionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self, let device = self.videoDevice else { return }
                DispatchQueue.main.async {
                    let lensPosValue = propertyControlValue(
                        Double(device.lensPosition),
                        propertyMin: 0.0,
                        propertyMax: 1.0,
                        inverseGamma: 1.0,
                        offset: 0.0
                    )
                    self.lensPositionSliderValue = Float(lensPosValue)
                }
            }
        }
    }

    // MARK: - Thermal State Observation
    func observeThermalState() {
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            let thermalState = ProcessInfo.processInfo.thermalState
//            if thermalState >= .serious {
//                self?.thermalStateMessage = "High thermal state detected. Consider reducing load."
//            } else {
//                self?.thermalStateMessage = ""
//            }
        }
    }

    // MARK: - Focus Controls
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(mode) {
                    device.focusMode = mode
                    if mode == .locked {
                        // Optionally set a default focus point
                        device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                        device.setFocusModeLocked(lensPosition: device.lensPosition, completionHandler: nil)
                        DispatchQueue.main.async {
                            self.canSetLensPosition = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.canSetLensPosition = false
                        }
                    }
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting focus mode: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    func setLensPosition(_ value: Float) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            if device.focusMode == .locked {
                do {
                    try device.lockForConfiguration()
                    device.setFocusModeLocked(lensPosition: value, completionHandler: nil)
                    device.unlockForConfiguration()
                } catch {
                    DispatchQueue.main.async {
                        self.alertMessage = "Error setting lens position: \(error.localizedDescription)"
                        self.showAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Exposure Controls
    func setExposureMode(_ mode: AVCaptureDevice.ExposureMode) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(mode) {
                    device.exposureMode = mode
                    if mode == .custom {
                        DispatchQueue.main.async {
                            // Allow exposure adjustments
                        }
                    } else {
                        DispatchQueue.main.async {
                            // Disable exposure adjustments if not custom
                        }
                    }
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting exposure mode: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    func applyExposureDuration() {
        guard let device = self.videoDevice, exposureMode == .custom else { return }
        let minExposure = 1.0 / 1000.0
        let maxExposure = 1.0 / 3.0
        let exposureSeconds = controlPropertyValue(exposureDurationSliderValue, propertyMin: minExposure, propertyMax: maxExposure, gamma: 5.0, offset: 0.0)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: CMTimeMakeWithSeconds(exposureSeconds, preferredTimescale: 1_000_000_000),
                                             iso: AVCaptureDevice.currentISO, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting exposure duration: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    func applyISO() {
        guard let device = self.videoDevice, exposureMode == .custom else { return }
        let isoValue = controlPropertyValue(ISOSliderValue, propertyMin: Double(device.activeFormat.minISO), propertyMax: Double(device.activeFormat.maxISO), gamma: 1.0, offset: 0.0)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: Float(isoValue), completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting ISO: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    // MARK: - Torch Controls
    func applyTorchLevel() {
        guard let device = self.videoDevice else { return }
        let value = torchLevelSliderValue
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if value > 0 {
                    try device.setTorchModeOn(level: value)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting torch level: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    // MARK: - Zoom Controls
    func applyZoomFactor() {
        guard let device = self.videoDevice else { return }
        let zoomFactor = controlPropertyValue(videoZoomFactorSliderValue,
                                              propertyMin: device.minAvailableVideoZoomFactor,
                                              propertyMax: device.activeFormat.videoMaxZoomFactor,
                                              gamma: 3.333, offset: 0.0)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(zoomFactor)
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting zoom factor: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    // MARK: - White Balance Controls
    func setWhiteBalanceMode(_ mode: AVCaptureDevice.WhiteBalanceMode) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isWhiteBalanceModeSupported(mode) {
                    device.whiteBalanceMode = mode
                    if mode == .locked {
                        // Optionally set a default white balance point
//                        device.whiteBalancePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                        device.setWhiteBalanceModeLocked(with: device.deviceWhiteBalanceGains, completionHandler: nil)
                    }
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting white balance mode: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    func applyWhiteBalanceGains() {
        guard let device = self.videoDevice, whiteBalanceMode == .locked else { return }
        let temperature = controlPropertyValue(temperatureSliderValue, propertyMin: 3000, propertyMax: 8000, gamma: 1.0, offset: 0.0)
        let tint = controlPropertyValue(tintSliderValue, propertyMin: -150, propertyMax: 150, gamma: 1.0, offset: 0.0)
        let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(temperature), tint: Float(tint))
        let gains = device.deviceWhiteBalanceGains(for: tempAndTint)
        let normalizedGains = self.normalizedGains(gains)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting white balance gains: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    func lockWithGrayWorld() {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                let gains = device.grayWorldDeviceWhiteBalanceGains
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)

                let tempAndTint = device.temperatureAndTintValues(for: gains)
                let tempValue = propertyControlValue(
                    Double(tempAndTint.temperature),
                    propertyMin: 3000,
                    propertyMax: 8000,
                    inverseGamma: 1.0,
                    offset: 0.0
                )
                let tintValue = propertyControlValue(
                    Double(tempAndTint.tint),
                    propertyMin: -150,
                    propertyMax: 150,
                    inverseGamma: 1.0,
                    offset: 0.0
                )

                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.temperatureSliderValue = tempValue
                    self.tintSliderValue = tintValue
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Error setting gray world: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    func normalizedGains(_ gains: AVCaptureDevice.WhiteBalanceGains) -> AVCaptureDevice.WhiteBalanceGains {
        guard let device = videoDevice else { return gains }
        var g = gains
        func clamp(_ value: Float) -> Float {
            return max(1.0, min(value, device.maxWhiteBalanceGain))
        }
        g.redGain = clamp(g.redGain)
        g.greenGain = clamp(g.greenGain)
        g.blueGain = clamp(g.blueGain)
        return g
    }

    // MARK: - Movie Recording
    func toggleMovieRecording() {
        guard let movieFileOutput = movieFileOutput else { return }
        if !movieFileOutput.isRecording {
            if UIDevice.current.isMultitaskingSupported {
                backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            }
            let outputFileName = UUID().uuidString
            let outputFilePath = NSTemporaryDirectory().appending("\(outputFileName).mov")
            movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
                UIApplication.shared.isIdleTimerDisabled = true
            }
        } else {
            movieFileOutput.stopRecording()
        }
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        // Optionally handle when recording starts
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            UIApplication.shared.isIdleTimerDisabled = false
        }

        let currentBackgroundRecordingID = self.backgroundRecordingID
        self.backgroundRecordingID = .invalid

        let cleanup = {
            if FileManager.default.fileExists(atPath: outputFileURL.path) {
                try? FileManager.default.removeItem(at: outputFileURL)
            }
            if currentBackgroundRecordingID != .invalid {
                UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
            }
        }

        var success = true
        if let error = error as NSError? {
            print("Error finishing recording: \(error)")
            success = (error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
        }

        if success {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges {
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        let changeRequest = PHAssetCreationRequest.forAsset()
                        changeRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                    } completionHandler: { saved, err in
                        if !saved {
                            print("Could not save movie to photo library: \(String(describing: err))")
                        }
                        cleanup()
                    }
                } else {
                    cleanup()
                }
            }
        } else {
            cleanup()
        }
    }

    // MARK: - Subject Area Change
    func subjectAreaDidChange() {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focusWithMode(videoDevice?.focusMode ?? .continuousAutoFocus,
                      exposeWithMode: videoDevice?.exposureMode ?? .continuousAutoExposure,
                      atDevicePoint: devicePoint,
                      monitorSubjectAreaChange: false)
    }

    func focusWithMode(_ focusMode: AVCaptureDevice.FocusMode,
                       exposeWithMode exposureMode: AVCaptureDevice.ExposureMode,
                       atDevicePoint point: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if focusMode != .locked && device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = point
                    device.focusMode = focusMode
                }
                if exposureMode != .custom && device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = exposureMode
                }
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Could not lock device for configuration: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}
