
import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Chargement...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    SplashScreenView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}

