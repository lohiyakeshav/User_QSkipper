//
//  StartView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct StartView: View {
    @State private var navigateToLogin = false
    @State private var showContent = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Use the shared AppBackground component
                    AppBackground()
                   
                    // Content overlay with animation
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer()
                        
                        Text("Welcome to QSkipper")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        
                        Text("Skip the Wait, Grab the Bite! Because life's too short to stand in line for fries!")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 20)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 15)
                        
                        Spacer().frame(height: 20)
                        
                        Button {
                            withAnimation {
                                navigateToLogin = true
                            }
                        } label: {
                            HStack {
                                Text("GET STARTED")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 50)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                            )
                            .padding(.trailing, 50)
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 50)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: LoginView().navigationBarHidden(true),
                    isActive: $navigateToLogin,
                    label: { EmptyView() }
                )
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    showContent = true
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    StartView()
} 