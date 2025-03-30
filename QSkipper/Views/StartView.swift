//
//  StartView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct StartView: View {
    @State private var navigateToLogin = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("intro_burger")
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaledToFill()
                    .opacity(0.7)
                    .offset(x: -70)
                    .ignoresSafeArea()
                
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(maxWidth:.infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 0.09, green: 0.15, blue: 0.16), location: 0.00),
                                Gradient.Stop(color: Color(red: 0.09, green: 0.15, blue: 0.16).opacity(0), location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 0.5, y: 1),
                            endPoint: UnitPoint(x: 0.5, y: 0.36)
                        )
                    )
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 15) {
                    Spacer()
                    
                    Text("Welcome to QSkipper")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Skip the Wait, Grab the Bite! Because life's too short to stand in line for fries!" )
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .frame(maxWidth: 300, alignment: .leading)
                    
                    Spacer().frame(height: 5)
                    
                    Button {
                        navigateToLogin = true
                    } label: {
                        Text("NEXT")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.white)
                            .cornerRadius(50)
                            .padding(.trailing, 80)
                    }
                    
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .navigationBarBackButtonHidden()
            .background(
                NavigationLink(
                    destination: LoginView(),
                    isActive: $navigateToLogin,
                    label: { EmptyView() }
                )
            )
        }
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
    }
} 