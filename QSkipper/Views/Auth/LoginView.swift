//
//  LoginView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var otp = ""
    @Published var otpSent = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showError = false
    @Published var navigateToLocation = false
    
    private let authManager = AuthManager.shared
    
    @MainActor
    func sendOTP() async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            let receivedOTP = try await authManager.requestLoginOTP(email: email)
            
            // The server may return an empty OTP in production environments
            // when it sends the OTP via email instead of returning it directly
            self.otp = receivedOTP
            self.otpSent = true
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            self.isLoading = false
        }
    }
    
    @MainActor
    func verifyOTP() async {
        guard !otp.isEmpty else {
            errorMessage = "Please enter the OTP sent to your email"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            let success = try await authManager.verifyLoginOTP(email: email, otp: otp)
            
            self.isLoading = false
            
            if success {
                // User is now logged in, navigate to location
                self.navigateToLocation = true
            } else {
                self.errorMessage = "Invalid OTP. Please try again."
                self.showError = true
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            self.isLoading = false
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Add splash background image
            Image("splash_background")
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaledToFill()
                .ignoresSafeArea()
                
            // White overlay with opacity for better readability
            Color.white.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Add a spacer at the top to push content to center
                    Spacer().frame(height: 50)
                    
                    // Title
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Login to your")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("account.")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    
                    Text("Please sign in to your account")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.bottom, 10)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)
                    
                    // Email Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email Address")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                        
                        TextField("Enter your email address", text: $viewModel.email)
                            .font(.system(size: 16))
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    
                    // Get Started Button
                    Button(action: {
                        Task {
                            await viewModel.sendOTP()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.primaryGreen)
                                .frame(height: 50)
                                .shadow(color: AppColors.primaryGreen.opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Get Started")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    .padding(.top, 10)
                    
                    // Don't have an account section
                    HStack {
                        Spacer()
                        
                        Text("Don't have an account?")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                        
                        NavigationLink(destination: RegisterView()) {
                            Text("Register")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    .opacity(animateContent ? 1 : 0)
                    
                    // Add a spacer at the bottom to push content to center
                    Spacer().frame(height: 50)
                }
                .padding(.horizontal, 25)
                .frame(minHeight: UIScreen.main.bounds.height)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .errorAlert(
            error: viewModel.errorMessage,
            isPresented: $viewModel.showError
        )
        .background(
            // If OTP is sent, navigate to OTP verification screen
            NavigationLink(
                destination: OTPVerificationView(email: viewModel.email, otp: $viewModel.otp, verifyAction: {
                    Task {
                        await viewModel.verifyOTP()
                    }
                }, isRegistration: false),
                isActive: $viewModel.otpSent,
                label: { EmptyView() }
            )
        )
        .background(
            // If OTP verification is successful, navigate to LocationView
            NavigationLink(
                destination: LocationView().navigationBarBackButtonHidden(true),
                isActive: $viewModel.navigateToLocation,
                label: { EmptyView() }
            )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateContent = true
            }
        }
    }
}

struct SocialLoginButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .padding()
                .foregroundColor(.black)
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
        }
    }
}

#Preview {
    LoginView()
} 