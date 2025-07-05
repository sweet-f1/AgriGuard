import SwiftUI

struct DogBotLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
                Text("机器狗正在抵达目标区域")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
} 