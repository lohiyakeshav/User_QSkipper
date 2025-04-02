//
//  AboutView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 02/04/25.
//

import SwiftUI

struct AboutView: View {
    // App version information
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    // Theme & animation
    private let primaryColor = AppColors.primaryGreen
    private let backgroundColor = Color(.systemBackground)
    @State private var isVisible = false // For animation
    
    // Team/Developer details
    let teamMembers = [
        ("Baniya Bros", "Full Stack Devs Org", "person.3.sequence.fill"),
        ("Keshav Lohiya", "Mobile Developer", "person.circle.fill"),
        ("Vinayak Bansal", "Full Stack Developer", "hammer.fill"),
        ("Priyanshu Gupta", "Full Stack Developer", "server.rack")
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
                            VStack(spacing: 10) {
                                // App logo with animation - with fallback
                                if let logoImage = UIImage(named: "Logo") {
                                    Image(uiImage: logoImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(20)
                                        .padding(.top, 20)
                                        .opacity(isVisible ? 1 : 0)
                                        .offset(y: isVisible ? 0 : 20)
                                        .animation(.easeOut(duration: 0.6), value: isVisible)
                                } else {
                                    // Fallback if logo image is not found
                                    Image(systemName: "fork.knife.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(primaryColor)
                                        .frame(width: 100, height: 100)
                                        .padding(.top, 20)
                                        .opacity(isVisible ? 1 : 0)
                                        .offset(y: isVisible ? 0 : 20)
                                        .animation(.easeOut(duration: 0.6), value: isVisible)
                                }
                                
                                // App name and version
                                Text("QSkipper")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                    .opacity(isVisible ? 1 : 0)
                                    .offset(y: isVisible ? 0 : 20)
                                    .animation(.easeOut(duration: 0.6).delay(0.1), value: isVisible)
                                
                                Text("v 1.1.0")
                                    .font(.system(size: 14))
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
                            
                            // MARK: - About Description
                            VStack(alignment: .leading, spacing: 10) {
                                Text("About QSkipper")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("QSkipper is a food ordering application that helps you skip the queue at your favorite restaurants. Order ahead, pick up when ready, and enjoy a seamless dining experience.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                
                                Text("Our mission is to save your valuable time by eliminating waiting periods at restaurants through our convenient pre-ordering system.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // MARK: - Key Features
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Key Features")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                FeatureItem(icon: "clock", title: "Pre-order Food", description: "Schedule your orders ahead of time")
                                FeatureItem(icon: "mappin.and.ellipse", title: "Restaurant Discovery", description: "Find restaurants near your location")
                                FeatureItem(icon: "bell", title: "Order Notifications", description: "Get notified when your order is ready")
                                FeatureItem(icon: "creditcard", title: "Secure Payments", description: "Pay securely using IAP")
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // MARK: - Team/Developer Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Our Team")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                // Displaying team members in a grid layout with proper constraints
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(teamMembers, id: \.0) { member in
                                        TeamMemberView(name: member.0, role: member.1, color: primaryColor, icon: member.2)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            
                            // MARK: - Legal Information
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Legal Information")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(primaryColor)
                                    Text("Terms of Service")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                Divider()
                                
                                HStack {
                                    Image(systemName: "hand.raised")
                                        .foregroundColor(primaryColor)
                                    Text("Privacy Policy")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                Text("© 2025 QSkipper. All rights reserved.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .padding(.top, 10)
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
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Supporting Views

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.primaryGreen)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

struct TeamMemberView: View {
    let name: String
    let role: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(color)
                .padding(8)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            Text(name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(role)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.05)))
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
} 
