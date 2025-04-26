import SwiftUI

struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(viewModel: viewModel)
                .ignoresSafeArea()
                .overlay(
                    viewModel.coverViewVisible ? Color.black : Color.clear
                )
            
            
//            CameraPreview(viewModel: viewModel)
//                .ignoresSafeArea()
//            
            if viewModel.sessionRunning {
                CameraControlsView(viewModel: viewModel)
            } else {
                HStack {
                    Image(systemName: "play.slash")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text("SESSION NOT RUNNING")
                        .foregroundStyle(.tint)
                        .scaledToFit()
                }
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .background {
                    Color.clear.opacity(0.0)
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Error"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
        
        VStack {
            Link(destination: URL(string: "https://github.com/theoknock/AVDemonCamManualSwiftPort/tree/main")!) {
                Text("AVMotionDetector2025 (35f1719) | James Alan Bush")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .fixedSize() // Prevents text from wrapping or expanding vertically
                    .frame(height: 10) // Enforce container height
                    .padding(.bottom, 4)
            }
        }
    }
}
