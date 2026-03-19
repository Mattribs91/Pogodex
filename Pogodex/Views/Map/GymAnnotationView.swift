import SwiftUI

struct GymAnnotationView: View {
    let gym: PogoMapGym

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(gym.teamColor.gradient)
                    .frame(width: 32, height: 32)
                    .shadow(color: gym.teamColor.opacity(0.4), radius: 4, y: 2)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    }

                Image(systemName: "shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(gym.teamColor)
                .offset(y: 1)
        }
    }
}
