//
//  DeviceRotationCoordinator.swift
//  AVDemonCamManualSwiftPort
//
//  Created by Xcode Developer on 12/10/24.
//

import AVFoundation
import UIKit

/// A simplified approximation of what the original code might have done.
/// This attempts to track device orientation and apply a corresponding rotation angle to the preview layer’s connection.
class DeviceRotationCoordinator: ObservableObject {
    @Published var videoRotationAngle: Double = 0.0
    
    private var orientationObserver: NSObjectProtocol?
    
    init() {
        orientationObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateRotationAngle()
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        updateRotationAngle()
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    func updateRotationAngle() {
        let deviceOrientation = UIDevice.current.orientation
        var angle: Double = 0.0
        switch deviceOrientation {
        case .landscapeLeft:
            angle = 90.0
        case .landscapeRight:
            angle = 270.0
        case .portraitUpsideDown:
            angle = 180.0
        default:
            angle = 0.0
        }
        
        DispatchQueue.main.async {
            self.videoRotationAngle = angle
        }
    }
}
