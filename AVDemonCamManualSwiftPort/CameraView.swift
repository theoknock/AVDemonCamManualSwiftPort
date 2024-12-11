import SwiftUI

struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(viewModel: viewModel)
                .ignoresSafeArea()

            if viewModel.sessionRunning {
                CameraControlsView(viewModel: viewModel)
            } else {
                Text("Session not running")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Error"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}
