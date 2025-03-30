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
            
            // Update UI on the main actor
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
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        // Title
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Login to your")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("account.")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.top, 60)
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
                            
                            TextField("Keshav.lohiyas@gmail.com", text: $viewModel.email)
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
                        
                        // Or sign in with
                        HStack {
                            VStack {
                                Divider().background(Color.gray.opacity(0.5))
                            }
                            
                            Text("Or sign in with")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)
                            
                            VStack {
                                Divider().background(Color.gray.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 20)
                        .opacity(animateContent ? 1 : 0)
                        
                        // Social Login Buttons
                        HStack(spacing: 20) {
                            Button(action: {}) {
                                Image(systemName: "g.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .padding()
                                    .foregroundColor(.black)
                                    .background(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "apple.logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .padding()
                                    .foregroundColor(.black)
                                    .background(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(animateContent ? 1 : 0)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: UIScreen.main.bounds.height - 100)
                }
                
                // Register link at bottom
                VStack {
                    Spacer()
                    HStack {
                        Text("Don't have an account?")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.7))
                        
                        NavigationLink(destination: RegisterView()) {
                            Text("Register")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                    }
                    .padding(.bottom, 30)
                    .opacity(animateContent ? 1 : 0)
                }
            }
            .navigationBarHidden(true)
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
                    }),
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
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    animateContent = true
                }
            }
        }
        .navigationViewStyle(.stack)
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

struct OTPVerificationView: View {
    let email: String
    @Binding var otp: String
    let verifyAction: () -> Void
    
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var countdown: Int = 60
    @State private var timer: Timer? = nil
    @State private var animateContent = false
    @State private var activeFieldIndex: Int? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Navigation header with back button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text("OTP")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Empty view for balance
                    Color.clear.frame(width: 25)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .opacity(animateContent ? 1 : 0)
                
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {
                        // Title and description
                        Text("Email verification")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 40)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 10)
                        
                        Text("Enter the verification code we send you.")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 40)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 10)
                        
                        // OTP Input Fields
                        HStack(spacing: 12) {
                            ForEach(0..<6) { index in
                                OTPDigitButton(
                                    digit: $digits[index],
                                    isActive: activeFieldIndex == index,
                                    onTap: {
                                        activeFieldIndex = index
                                    }
                                )
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 15)
                                .animation(.easeOut.delay(0.1 + Double(index) * 0.05), value: animateContent)
                            }
                        }
                        .padding(.bottom, 30)
                        
                        // Resend Code section
                        HStack {
                            Text("Didn't receive code?")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                startTimer()
                            }) {
                                Text("Resend")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppColors.primaryGreen)
                            }
                        }
                        .opacity(animateContent ? 1 : 0)
                        
                        // Timer
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                            
                            Text(formattedTime)
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 5)
                        .opacity(animateContent ? 1 : 0)
                        
                        Spacer(minLength: 200)
                        
                        // Continue Button
                        Button(action: {
                            otp = digits.joined()
                            verifyAction()
                        }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.primaryGreen)
                                        .shadow(color: AppColors.primaryGreen.opacity(0.3), radius: 5, x: 0, y: 3)
                                )
                        }
                        .padding(.bottom, 15)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: UIScreen.main.bounds.height - 100)
                }
            }
            
            // Custom number pad - only show when a field is active
            if activeFieldIndex != nil {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            activeFieldIndex = nil
                        }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 5)
                    }
                    
                    // Digit keypad
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            ForEach(1...3, id: \.self) { number in
                                DigitButton(digit: "\(number)") { digit in
                                    addDigit(digit)
                                }
                            }
                        }
                        
                        HStack(spacing: 30) {
                            ForEach(4...6, id: \.self) { number in
                                DigitButton(digit: "\(number)") { digit in
                                    addDigit(digit)
                                }
                            }
                        }
                        
                        HStack(spacing: 30) {
                            ForEach(7...9, id: \.self) { number in
                                DigitButton(digit: "\(number)") { digit in
                                    addDigit(digit)
                                }
                            }
                        }
                        
                        HStack(spacing: 30) {
                            // Empty space for balance
                            Spacer()
                                .frame(width: 50, height: 50)
                            
                            DigitButton(digit: "0") { digit in
                                addDigit(digit)
                            }
                            
                            Button(action: {
                                removeLastDigit()
                            }) {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .frame(width: 50, height: 50)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGray6))
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: activeFieldIndex != nil)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startTimer()
            
            // Pre-populate if we already have an OTP
            if otp.count == 6 {
                for (index, char) in otp.enumerated() {
                    if index < digits.count {
                        digits[index] = String(char)
                    }
                }
            }
            
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private var formattedTime: String {
        let minutes = countdown / 60
        let seconds = countdown % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startTimer() {
        countdown = 60
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    private func addDigit(_ digit: String) {
        guard let activeIndex = activeFieldIndex, activeIndex < digits.count else {
            return
        }
        
        // Update the active field
        digits[activeIndex] = digit
        
        // If not the last field, move to the next field
        if activeIndex < digits.count - 1 {
            activeFieldIndex = activeIndex + 1
        } else {
            // Last field filled, hide keyboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                activeFieldIndex = nil
                otp = digits.joined()
            }
        }
    }
    
    private func removeLastDigit() {
        guard let activeIndex = activeFieldIndex else {
            return
        }
        
        // If current field is empty and not the first field, move to previous field
        if digits[activeIndex].isEmpty && activeIndex > 0 {
            activeFieldIndex = activeIndex - 1
        } else {
            // Clear the current field
            digits[activeIndex] = ""
        }
        
        otp = digits.joined()
    }
}

struct OTPDigitButton: View {
    @Binding var digit: String
    var isActive: Bool
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? AppColors.primaryGreen : Color.gray.opacity(0.3), lineWidth: isActive ? 2 : 1)
                    .frame(width: 45, height: 55)
                    .background(Color.white)
                
                Text(digit.isEmpty ? "" : digit)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
        }
    }
}

struct DigitButton: View {
    let digit: String
    let action: (String) -> Void
    
    var body: some View {
        Button(action: {
            action(digit)
        }) {
            Text(digit)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
        }
    }
}

#Preview {
    LoginView()
} 