import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var showSignInScreen = false
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        ZStack {
            if isLoading {
                // Loading screen while checking authentication state
                loadingView
            } else if authManager.isLoggedIn {
                // Main app content when authenticated
                HomeView()
            } else {
                // Login screen when not authenticated
                StartView()
            }
        }
        .onAppear {
            // Display splash screen for 2 seconds before showing main content
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
    
    // Loading/splash screen view
    private var loadingView: some View {
        ZStack {
            // Background color
            Color(hex: "#f8f8f8")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo - using UIImage to avoid ambiguous init
                if let logoImage = UIImage(named: "Logo") {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                } else {
                    // Fallback if logo image is not found
                    Image(systemName: "fork.knife")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(AppColors.primaryGreen)
                        .frame(width: 120, height: 120)
                }
                
                // Use LottieWebAnimationView directly instead of AnimationView to avoid ambiguity
                LottieWebAnimationView(
                    webURL: "https://lottie.host/20b64309-9089-4464-a4c5-f9a1ab3dbba1/l5b3WsrLuK.lottie",
                    loopMode: .loop,
                    autoplay: true,
                    contentMode: .scaleAspectFit
                )
                .frame(width: 100, height: 100)
                
                Text("QSkipper")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.darkGray)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 