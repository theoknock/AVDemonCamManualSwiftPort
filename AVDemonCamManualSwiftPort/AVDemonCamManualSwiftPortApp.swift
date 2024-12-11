//
//  AVDemonCamManualSwiftPortApp.swift
//  AVDemonCamManualSwiftPort
//
//  Created by Xcode Developer on 12/10/24.
//

import SwiftUI
import AVFoundation
import Photos
import Combine

// MARK: - MovieAppEventDelegate Protocol
protocol MovieAppEventDelegate: AnyObject {
    var movieFileOutput: AVCaptureMovieFileOutput? { get }
    func toggleMovieRecording(_ sender: Any?)
}

enum AVCamManualSetupResult {
    case success
    case cameraNotAuthorized
    case sessionConfigurationFailed
}

private var FocusModeContext = 0
private var LensPositionContext = 0
private var ExposureModeContext = 0
private var ExposureDurationContext = 0
private var ISOContext = 0
private var VideoZoomFactorContext = 0
private var WhiteBalanceModeContext = 0
private var DeviceWhiteBalanceGainsContext = 0
private var SessionRunningContext = 0

// Utility functions
func controlPropertyValue(_ controlValue: Double, propertyMin: Double, propertyMax: Double, gamma: Double, offset: Double) -> Double {
    return ((pow(controlValue, gamma) * (propertyMax - propertyMin)) + propertyMin)
}

func propertyControlValue(_ propertyValue: Double, propertyMin: Double, propertyMax: Double, inverseGamma: Double, offset: Double) -> Double {
    return pow((propertyValue - propertyMin) / (propertyMax - propertyMin), 1.0 / inverseGamma)
}

func setLensPositionScale(_ valueMin: Double, _ valueMax: Double, _ newValueMin: Double, _ newValueMax: Double) -> (Double) -> Double {
    return { value in
        return (newValueMax - newValueMin) * (value - valueMin) / (valueMax - valueMin) + newValueMin
    }
}

@main
struct AVDemonCamManualSwiftPortApp: App {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            CameraView(viewModel: viewModel)
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        print("App is active")
                    case .inactive:
                        print("App is inactive")
                        if viewModel.isRecording {
                            viewModel.toggleMovieRecording()
                        }
                    case .background:
                        print("App is in background")
                        if viewModel.isRecording {
                            viewModel.toggleMovieRecording()
                        }
                    @unknown default:
                        print("Unknown scene phase")
                    }
                }
        }
    }
} 

// MARK: - AppDelegate (Port of AVCamManualAppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    weak var movieAppEventDelegate: MovieAppEventDelegate?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // If needed, you can configure sessionQueue or other initial setups here.
        return true
    }
    
    static func sharedAppDelegate() -> AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // If the movie is recording when the app resigns active, stop recording.
        if movieAppEventDelegate?.movieFileOutput?.isRecording == true {
            movieAppEventDelegate?.toggleMovieRecording(nil)
        }
    }
}
