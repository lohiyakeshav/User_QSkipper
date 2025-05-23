import SwiftUI

// MARK: - Shimmer Effect
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// Shimmer modifier that creates a subtle loading animation
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: Color.white.opacity(0.5), location: 0.3),
                            .init(color: Color.white.opacity(0.5), location: 0.7),
                            .init(color: Color.clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2) * phase)
                    .blendMode(.screen)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                    .onAppear {
                        phase = 1
                    }
                }
            )
            .mask(content)
    }
}

// MARK: - Card Style
extension View {
    func cardStyle() -> some View {
        self
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Button Styles
extension View {
    func primaryButtonStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(AppColors.primaryGreen)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: AppColors.primaryGreen.opacity(0.3), radius: 5, x: 0, y: 2)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.white)
            .foregroundColor(AppColors.primaryGreen)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.primaryGreen, lineWidth: 1)
            )
    }
} 