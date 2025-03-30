//
//  OTPVerificationView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 30/03/25.
//

import SwiftUI
import UIKit

struct OTPVerificationView: View {
    let email: String
    @Binding var otp: String
    let verifyAction: () -> Void
    let isRegistration: Bool
    
    @Environment(\.presentationMode) var presentationMode
    @State private var otpDigits: [String] = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?
    @State private var countdown: Int = 60
    @State private var timer: Timer? = nil
    @State private var isResending: Bool = false
    @State private var showResendMessage: Bool = false
    @State private var resendMessage: String = ""
    @State private var directOTPInput: String = ""
    
    private let authManager = AuthManager.shared
    
    init(email: String, otp: Binding<String>, verifyAction: @escaping () -> Void, isRegistration: Bool = false) {
        self.email = email
        self._otp = otp
        self.verifyAction = verifyAction
        self.isRegistration = isRegistration
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Navigation bar with back button - only show one back button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("OTP Verification")
                    .font(AppFonts.title)
                    .foregroundColor(.black)
                
                Spacer()
                
                // For balance
                Color.clear.frame(width: 24, height: 24)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer().frame(height: 20)
            
            // Title
            Text("Email verification")
                .font(AppFonts.title)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Subtitle
            Text("Enter the verification code we sent to\n\(email)")
                .font(AppFonts.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)
            
            // OTP Input Label
            Text("Enter 6-digit code")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .padding(.bottom, 10)
            
            // Hidden direct input field for keyboard
            ZStack {
                // OTP Digit Display - this is the visual part
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPTextField(text: $otpDigits[index], isFocused: focusedField == index)
                            .onTapGesture {
                                focusedField = 0
                            }
                    }
                }
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = 0
                }
                
                // Hidden TextField for keyboard access - placed above the digit fields
                TextField("", text: $directOTPInput)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: 0)
                    .opacity(0.01)
                    .frame(maxWidth: .infinity)
                    .onChange(of: directOTPInput) { newValue in
                        // Only allow up to 6 digits
                        if newValue.count > 6 {
                            directOTPInput = String(newValue.prefix(6))
                        }
                        
                        // Only allow numbers
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            directOTPInput = filtered
                        }
                        
                        // Update the visual display of digits
                        updateOTPDigits(from: directOTPInput)
                        
                        // Update main OTP
                        otp = directOTPInput
                    }
            }
            
            // Show clear button if any digit is entered
            if !directOTPInput.isEmpty {
                Button(action: {
                    // Clear all digits
                    directOTPInput = ""
                    for i in 0..<otpDigits.count {
                        otpDigits[i] = ""
                    }
                    otp = ""
                    focusedField = 0
                }) {
                    Text("Clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primaryGreen)
                }
                .padding(.top, 5)
            }
            
            // Resend Code section
            HStack {
                Text("Didn't receive code?")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                
                Button(action: {
                    resendOTP()
                }) {
                    if isResending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                    } else {
                        Text("Resend")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(countdown > 0 ? Color.gray : AppColors.primaryGreen)
                    }
                }
                .disabled(countdown > 0 || isResending)
            }
            .padding(.top, 20)
            
            // Timer
            if countdown > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    
                    Text(formattedTime)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .padding(.top, 5)
            }
            
            // Resend message
            if showResendMessage {
                Text(resendMessage)
                    .font(.system(size: 14))
                    .foregroundColor(resendMessage.contains("error") ? .red : AppColors.primaryGreen)
                    .padding(.top, 5)
                    .transition(.opacity)
            }
            
            Spacer()
            
            Button(action: {
                verifyAction()
            }) {
                Text("Verify")
                    .font(AppFonts.buttonText)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .disabled(directOTPInput.count < 6)
            .opacity(directOTPInput.count < 6 ? 0.5 : 1.0)
        }
        .onAppear {
            // Start timer
            startTimer()
            
            // Pre-populate if we already have an OTP
            if otp.count > 0 {
                directOTPInput = otp
                updateOTPDigits(from: otp)
            }
            
            // Ensure keyboard appears immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = 0
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .navigationBarHidden(true) // Hide default navigation bar
    }
    
    private func updateOTPDigits(from input: String) {
        // Clear all first
        for i in 0..<otpDigits.count {
            otpDigits[i] = ""
        }
        
        // Fill in from the input string
        let characters = Array(input)
        for i in 0..<min(characters.count, 6) {
            otpDigits[i] = String(characters[i])
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
    
    private func resendOTP() {
        isResending = true
        showResendMessage = false
        
        Task {
            do {
                let newOTP = try await authManager.resendOTP(email: email, isRegistration: isRegistration)
                
                // Need to update on the main thread
                await MainActor.run {
                    // Clear existing OTP fields
                    directOTPInput = ""
                    for i in 0..<otpDigits.count {
                        otpDigits[i] = ""
                    }
                    
                    // Update the stored OTP
                    otp = newOTP
                    
                    // Pre-populate if in development mode
                    if newOTP.count == 6 {
                        directOTPInput = newOTP
                        updateOTPDigits(from: newOTP)
                    }
                    
                    // Show success message
                    resendMessage = "OTP resent successfully!"
                    showResendMessage = true
                    
                    // Restart the timer
                    startTimer()
                    isResending = false
                    
                    // Refocus on the input field
                    focusedField = 0
                    
                    // Auto-hide message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showResendMessage = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    resendMessage = "Error: Could not resend OTP. Please try again."
                    showResendMessage = true
                    isResending = false
                    
                    // Auto-hide message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showResendMessage = false
                        }
                    }
                }
            }
        }
    }
}

struct OTPTextField: View {
    @Binding var text: String
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isFocused ? AppColors.primaryGreen : Color.gray.opacity(0.3), lineWidth: 1)
                .background(Color.gray.opacity(0.05).cornerRadius(8))
                .frame(width: 50, height: 60)
            
            Text(text)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

#Preview {
    OTPVerificationView(
        email: "example@email.com",
        otp: .constant(""),
        verifyAction: {},
        isRegistration: false
    )
} 
