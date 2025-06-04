//
//  RegisterView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

class RegisterViewModel: ObservableObject {
    @Published var email = ""
    @Published var name = ""
    @Published var otp = ""
    
    @Published var otpSent = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showError = false
    @Published var navigateToLocation = false
    
    private let authManager = AuthManager.shared
    
    @MainActor
    func register() async {
        // Validate inputs
        guard validateInputs() else {
            return
        }
        
        isLoading = true
        
        do {
            // Save user name to UserDefaults before API call
            // This ensures the name is available during OTP verification
            UserDefaultsManager.shared.saveUserName(name)
            print("📝 Saved username during registration: \(name)")
            
            // Pass empty string for phone since we removed that field
            let receivedOTP = try await authManager.registerUser(email: email, name: name, phone: "")
            
            // The server may return an empty OTP in production environments
            // when it sends the OTP via email instead of returning it directly
            self.otp = receivedOTP
            self.otpSent = true
            self.isLoading = false
        } catch {
            // Use the AuthManager's error property if available, as it's already formatted correctly
            self.errorMessage = authManager.error ?? error.localizedDescription
            print("⚠️ Registration error displayed: \(self.errorMessage ?? "nil")")
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
            let success = try await authManager.verifyRegisterOTP(email: email, otp: otp)
            
            self.isLoading = false
            
            if success {
                // User is now registered and logged in, navigate to location screen
                self.navigateToLocation = true
            } else {
                // Use the AuthManager's error property if available
                self.errorMessage = authManager.error ?? "Invalid OTP. Please try again."
                self.showError = true
            }
        } catch {
            // Use the AuthManager's error property if available
            self.errorMessage = authManager.error ?? error.localizedDescription
            print("⚠️ OTP verification error displayed: \(self.errorMessage ?? "nil")")
            self.showError = true
            self.isLoading = false
        }
    }
    
    private func validateInputs() -> Bool {
        // Check if email is valid
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            showError = true
            return false
        }
        
        // Check if name is not empty
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your name"
            showError = true
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var animateContent = false
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case email, name
    }
    
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
                Spacer(minLength: 30)
                VStack(alignment: .leading, spacing: 20) {
                    // Navigation header with back button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .padding(12)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 25)
                    
                    // Title
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Create your new")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.top, 25)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    
                    Text("Create an account to start looking for the food you like")
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
                            .focused($focusedField, equals: .email)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    
                    // User Name Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("User Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                        
                        TextField("Enter your full name", text: $viewModel.name)
                            .font(.system(size: 16))
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                        
                        // Username suggestion hint
                        if !viewModel.name.isEmpty {
                            Text("Username Suggestion: \(viewModel.name.replacingOccurrences(of: " ", with: ""))")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                        }
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    
                    // Terms & Privacy Agreement
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundColor(AppColors.primaryGreen)
                            .frame(width: 20, height: 20)
                        
                        Group {
                            Text("I Agree with ")
                                .foregroundColor(.gray) +
                            Text("Terms of Service")
                                .foregroundColor(AppColors.primaryGreen) +
                            Text(" and ")
                                .foregroundColor(.gray) +
                            Text("Privacy Policy")
                                .foregroundColor(AppColors.primaryGreen)
                        }
                        .font(.system(size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    
                    // Register Button
                    Button(action: {
                        Task {
                            await viewModel.register()
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
                                Text("Register")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                    }
                    .padding(.top, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .frame(minHeight: UIScreen.main.bounds.height - 100)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping outside of the text fields
                focusedField = nil
            }
            
            // Login Link
            VStack {
                Spacer()
                HStack {
                    Text("Already have an account?")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.7))
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.primaryGreen)
                    }
                }
                .padding(.bottom, 70)
                .opacity(animateContent ? 1 : 0)
            }
        }
        .navigationBarHidden(true)
        .errorAlert(
            error: viewModel.errorMessage,
            isPresented: $viewModel.showError
        )
        .background(
            NavigationLink(
                destination: OTPVerificationView(email: viewModel.email, otp: $viewModel.otp, verifyAction: {
                    Task {
                        await viewModel.verifyOTP()
                    }
                }, isRegistration: true),
                isActive: $viewModel.otpSent,
                label: { EmptyView() }
            )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateContent = true
            }
        }
    }
}

#Preview {
    NavigationView {
        RegisterView()
    }
} 
