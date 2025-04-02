//
//  HelpView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 02/04/25.
//

import SwiftUI

struct HelpView: View {
    // Theme & animation
    private let primaryColor = AppColors.primaryGreen
    private let backgroundColor = Color(.systemBackground)
    @State private var isVisible = false // For animation
    
    // FAQ items
    let faqItems = [
        (question: "How do I place an order?", 
         answer: "Browse restaurants, select items to add to cart, proceed to checkout, and choose your payment method. You can order for immediate pickup or schedule for later."),
        (question: "Can I schedule orders in advance?", 
         answer: "Yes! QSkipper allows you to schedule orders ahead of time. Select your items, go to checkout, and choose the 'Schedule Order' option to pick a convenient time."),
        (question: "How do I know when my order is ready?", 
         answer: "You'll receive push notifications when your order is accepted, being prepared, and ready for pickup. You can also check the status in the Orders tab."),
        (question: "What payment methods are accepted?", 
         answer: "We currently support in-app payments through Apple's secure payment system. More payment options will be added in future updates.")
    ]
    
    var body: some View {
        ScrollView {
            ZStack {
                // Background with food illustrations
                Image("splash_background")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Top spacing
                            Color.clear.frame(height: 20)
                            
                            // MARK: - Header Section
                            VStack(spacing: 15) {
                                // Help icon with animation
                                Image(systemName: "lifepreserver")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(primaryColor)
                                    .padding(.top, 20)
                                    .opacity(isVisible ? 1 : 0)
                                    .offset(y: isVisible ? 0 : 20)
                                    .animation(.easeOut(duration: 0.6), value: isVisible)
                                
                                // Title
                                Text("Help & Support")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                    .opacity(isVisible ? 1 : 0)
                                    .offset(y: isVisible ? 0 : 20)
                                    .animation(.easeOut(duration: 0.6).delay(0.1), value: isVisible)
                                
                                Text("We're here to help you")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .opacity(isVisible ? 1 : 0)
                                    .offset(y: isVisible ? 0 : 20)
                                    .animation(.easeOut(duration: 0.6).delay(0.2), value: isVisible)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // MARK: - Contact Information
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Contact Us")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Have any queries or issues with the app? Our support team is ready to assist you.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                
                                // Email Button
                                Link(destination: URL(string: "mailto:team.qskipper@gmail.com")!) {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 18))
                                        Text("team.qskipper@gmail.com")
                                            .font(.system(size: 16))
                                    }
                                    .foregroundColor(primaryColor)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(primaryColor, lineWidth: 1)
                                            .background(primaryColor.opacity(0.05))
                                    )
                                }
                                
//                                // Phone Button
//                                Link(destination: URL(string: "tel:+919876543210")!) {
//                                    HStack {
//                                        Image(systemName: "phone.fill")
//                                            .font(.system(size: 18))
//                                        Text("+91 98765 43210")
//                                            .font(.system(size: 16))
//                                    }
//                                    .foregroundColor(primaryColor)
//                                    .padding()
//                                    .frame(maxWidth: .infinity)
//                                    .background(
//                                        RoundedRectangle(cornerRadius: 10)
//                                            .stroke(primaryColor, lineWidth: 1)
//                                            .background(primaryColor.opacity(0.05))
//                                    )
//                                }
//                                
//                                // Website Button
//                                Link(destination: URL(string: "https://qskipper.com")!) {
//                                    HStack {
//                                        Image(systemName: "globe")
//                                            .font(.system(size: 18))
//                                        Text("Visit Our Website")
//                                            .font(.system(size: 16))
//                                    }
//                                    .foregroundColor(primaryColor)
//                                    .padding()
//                                    .frame(maxWidth: .infinity)
//                                    .background(
//                                        RoundedRectangle(cornerRadius: 10)
//                                            .stroke(primaryColor, lineWidth: 1)
//                                            .background(primaryColor.opacity(0.05))
//                                    )
//                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // MARK: - FAQ Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Frequently Asked Questions")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 15) {
                                    ForEach(faqItems, id: \.question) { item in
                                        FAQItem(question: item.question, answer: item.answer)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // MARK: - Feedback Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Share Your Feedback")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Your feedback helps us improve. Let us know how we can make QSkipper better for you.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                
                                Button(action: {
                                    // Action to open feedback form
                                    if let url = URL(string: "mailto:feedback.qskipper@gmail.com?subject=QSkipper%20App%20Feedback") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "star.bubble.fill")
                                        Text("Send Feedback")
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(primaryColor)
                                    )
                                }
                                
                                // App Store Rating
                                Button(action: {
                                    // Action to open App Store rating
                                    if let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                        Text("Rate on App Store")
                                    }
                                    .foregroundColor(primaryColor)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(primaryColor, lineWidth: 1)
                                            .background(primaryColor.opacity(0.05))
                                    )
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // Extra spacing at the bottom
                            Color.clear.frame(height: 50)
                        }
                        .frame(width: min(geometry.size.width - 32, 500), alignment: .center)
                        .padding(.horizontal, 16)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .background(backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Supporting Views

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.primaryGreen)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

#Preview {
    NavigationView {
        HelpView()
    }
} 
