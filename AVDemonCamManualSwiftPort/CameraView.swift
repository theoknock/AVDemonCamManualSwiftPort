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
                    Color.clear.opacity(1.0)
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Error"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}
