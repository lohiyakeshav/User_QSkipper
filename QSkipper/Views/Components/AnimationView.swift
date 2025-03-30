import SwiftUI

struct AnimationView: View {
    // Default animation URL for loading animations
    private let animationURL = "https://lottie.host/20b64309-9089-4464-a4c5-f9a1ab3dbba1/l5b3WsrLuK.lottie"
    
    var body: some View {
        LottieWebAnimationView(webURL: animationURL)
            .frame(width: 200, height: 200)
    }
}

struct AnimationView_Previews: PreviewProvider {
    static var previews: some View {
        AnimationView()
    }
} 