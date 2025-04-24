import SwiftUI
import AVFoundation
import Foundation


struct CameraControlsView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        VStack {
            // Top Control Buttons
            HStack {
                Button(action: viewModel.toggleMovieRecording) {
                    Image(systemName: viewModel.isRecording ? "stop.circle" : "record.circle")
                        .font(.largeTitle)
                        .foregroundColor(viewModel.isRecording ? .red : .green)
                }
                
                Button(action: { viewModel.showHUD.toggle() }) {
                    Text(viewModel.showHUD ? "Hide HUD" : "Show HUD")
                        .padding()
                        .background(Color.blue.opacity(0.5))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    viewModel.coverViewVisible.toggle()
                }) {
                    Text("Toggle Cover")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    
                }
            }
            .padding(.bottom, 10)
            
            // Conditional Buttons and Messages
            if viewModel.resumeButtonVisible {
                Button("Resume") {
                    viewModel.startSession()
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            if viewModel.cameraUnavailable {
                Text("Camera Unavailable")
                    .padding()
                    .background(Color.red.opacity(0.5))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            if !viewModel.thermalStateMessage.isEmpty {
                Text(viewModel.thermalStateMessage)
                    .padding()
                    .background(Color.yellow.opacity(0.5))
                    .cornerRadius(8)
                    .foregroundColor(.black)
            }
            
            // HUD Controls
            if viewModel.showHUD {
                Picker("HUD Segment", selection: $viewModel.selectedManualHUDSegment) {
                    Text("Focus").tag(0)
                    Text("Exposure").tag(1)
                    Text("Zoom").tag(2)
                    Text("Torch").tag(3)
                    Text("WB").tag(4)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 10)
                
                Group {
                    switch viewModel.selectedManualHUDSegment {
                    case 0: focusControls
                    case 1: exposureControls
                    case 2: zoomControls
                    case 3: torchControls
                    case 4: whiteBalanceControls
                    default: EmptyView()
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(10)
        .padding()
        .overlay(
            // Cover Overlay
            Group {
                if viewModel.coverViewVisible {
                    ZStack {
                        Color.black.opacity(1.0)
                            .ignoresSafeArea()
                            .edgesIgnoringSafeArea(.all)
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        
                        VStack {
                            Button(action: {
                                viewModel.coverViewVisible = false
                            }) {
                                
                                HStack {
                                    
                                    
                                    Image(systemName: "rectangle.and.arrow.up.right.and.arrow.down.left.slash")
                                        .imageScale(.large)
                                        .foregroundStyle(.tint)
                                }
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                                .background {
                                    Color.black.opacity(1.0)
                                }
                                .edgesIgnoringSafeArea(.all)
                                
                                //                                rectangle.and.arrow.up.right.and.arrow.down.left.slash
                                //                                Text("Remove Cover")
                                //                                    .padding()
                                //                                    .background(Color.white)
                                //                                    .foregroundColor(.black)
                                //                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .padding()
                    }
                } else {
                    //                    HStack {
                    //                        Image(systemName: "play.slash")
                    //                            .imageScale(.large)
                    //                            .foregroundStyle(.tint)
                    //                        Text("SESSION NOT RUNNING")
                    //                            .foregroundStyle(.tint)
                    //                            .scaledToFit()
                    //                    }
                    //                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    //                    .background {
                    //                        Color.black.opacity(1.0)
                    //                    }
                    //                    .edgesIgnoringSafeArea(.all)
                }
            }
        )
    }
    
    // MARK: - Focus Controls
    private var focusControls: some View {
        VStack(alignment: .leading) {
            Text("Focus Mode")
                .foregroundColor(.white)
            Picker("Focus Mode", selection: $viewModel.focusMode) {
                Text("Continuous").tag(AVCaptureDevice.FocusMode.continuousAutoFocus)
                Text("Locked").tag(AVCaptureDevice.FocusMode.locked)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.focusMode) { oldMode, newMode in
                viewModel.setFocusMode(newMode)
            }
            
            Text("Lens Position")
                .foregroundColor(.white)
            Slider(value: Binding(get: { Double(viewModel.lensPositionSliderValue) },
                                  set: { val in viewModel.lensPositionSliderValue = Float(val) }),
                   in: 0...1)
            .disabled(!viewModel.canSetLensPosition)
            .onChange(of: viewModel.lensPositionSliderValue) { oldSliderValue, newSliderValue in
                viewModel.setLensPosition(viewModel.lensPositionSliderValue)
            }
            
            Text("Long Press to Rescale Lens Slider Range")
                .font(.footnote)
                .foregroundColor(.white)
            
            Rectangle()
                .fill(Color.clear)
                .frame(height: 40)
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            //                            viewModel.setLensPositionScale(viewModel.lensPositionSliderValue)
                        }
                )
        }
    }
    
    // MARK: - Exposure Controls
    private var exposureControls: some View {
        VStack(alignment: .leading) {
            Text("Exposure Mode")
                .foregroundColor(.white)
            Picker("Exposure Mode", selection: $viewModel.exposureMode) {
                Text("Auto").tag(AVCaptureDevice.ExposureMode.continuousAutoExposure)
                Text("Custom").tag(AVCaptureDevice.ExposureMode.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.exposureMode) { oldMode, mode in
                viewModel.setExposureMode(mode)
            }
            
            Text("Exposure Duration")
                .foregroundColor(.white)
            Slider(value: $viewModel.exposureDurationSliderValue, in: 0...1)
                .disabled(viewModel.exposureMode != .custom)
                .onChange(of: viewModel.exposureDurationSliderValue) { _, _ in
                    viewModel.applyExposureDuration()
                }
            
            Text("ISO")
                .foregroundColor(.white)
            Slider(value: $viewModel.ISOSliderValue, in: 0...1)
                .disabled(viewModel.exposureMode != .custom)
                .onChange(of: viewModel.ISOSliderValue) { _, _ in
                    viewModel.applyISO()
                }
        }
    }
    
    // MARK: - Zoom Controls
    private var zoomControls: some View {
        VStack(alignment: .leading) {
            Text("Video Zoom Factor")
                .foregroundColor(.white)
            Slider(value: $viewModel.videoZoomFactorSliderValue, in: 0...1)
                .onChange(of: viewModel.videoZoomFactorSliderValue) { oldVideoZoomFactorSliderValue, newVideoZoomFactorSliderValue in
                    viewModel.applyZoomFactor()
                }
        }
    }
    
    // MARK: - Torch Controls
    private var torchControls: some View {
        VStack(alignment: .leading) {
            Text("Torch Level")
                .foregroundColor(.white)
            Slider(value: Binding(get: { Double(viewModel.torchLevelSliderValue) },
                                  set: { val in viewModel.torchLevelSliderValue = Float(val) }),
                   in: 0...1)
            .onChange(of: viewModel.torchLevelSliderValue) { _, _ in
                viewModel.applyTorchLevel()
            }
        }
    }
    
    // MARK: - White Balance Controls
    private var whiteBalanceControls: some View {
        VStack(alignment: .leading) {
            Text("White Balance Mode")
                .foregroundColor(.white)
            Picker("WB Mode", selection: $viewModel.whiteBalanceMode) {
                Text("Auto").tag(AVCaptureDevice.WhiteBalanceMode.continuousAutoWhiteBalance)
                Text("Locked").tag(AVCaptureDevice.WhiteBalanceMode.locked)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.whiteBalanceMode) { oldMode, newMode in
                viewModel.setWhiteBalanceMode(newMode)
            }
            
            Text("Temperature")
                .foregroundColor(.white)
            Slider(value: $viewModel.temperatureSliderValue, in: 0...1)
                .disabled(viewModel.whiteBalanceMode != .locked)
                .onChange(of: viewModel.temperatureSliderValue) { oldTemperatureSliderValue, newTemperatureSliderValue in
                    viewModel.applyWhiteBalanceGains()
                }
            
            Text("Tint")
                .foregroundColor(.white)
            Slider(value: $viewModel.tintSliderValue, in: 0...1)
                .disabled(viewModel.whiteBalanceMode != .locked)
                .onChange(of: viewModel.tintSliderValue) { oldTintSliderValue, TintSliderValue in
                    viewModel.applyWhiteBalanceGains()
                }
            
            Button("Gray World") {
                viewModel.lockWithGrayWorld()
            }
            .disabled(viewModel.whiteBalanceMode != .locked)
            .padding(.top, 10)
            .background(viewModel.whiteBalanceMode == .locked ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
